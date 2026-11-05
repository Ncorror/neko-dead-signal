extends Node3D
## One-person exploration slice; class combat and shared servers are separate stages.

const NAV := preload("res://scripts/rts_navigation.gd")
const PROGRESS := preload("res://scripts/world_progress.gd")
const FIT := preload("res://scripts/rts_character_fit.gd")
const DIAGNOSTICS := preload("res://scripts/rts_diagnostics_ui.gd")
const AMINA := "res://assets/characters/amina/preview.glb"
const LIMIT := 30.0
const SPEED := 5.8
const NPC_AT := Vector3(-18, 0, 11)
const RELAY_AT := [Vector3(-19, 0, -16), Vector3(17, 0, -18), Vector3(19, 0, 16)]
const COVER := [
    [Vector3(-8, 0, -7), Vector3(5, 2.2, 8)],
    [Vector3(7, 0, 6), Vector3(6, 2.5, 6)],
    [Vector3(-5, 0, 19), Vector3(4, 1.5, 3)]]

var navigation = NAV.new()
var progress = PROGRESS.new()
var hero: Node3D
var npc: Node3D
var relays: Array[Node3D] = []
var lamps: Array[MeshInstance3D] = []
var relay_labels: Array[Label3D] = []
var route: Array[Vector3] = []
var route_index := 0
var interaction := -2 # -2 none; -1 NPC; 0..2 relay.
var heading := 0.0
var target_marker: MeshInstance3D
var camera: Camera3D
var focus := Vector3.ZERO
var rendered_focus := Vector3.ZERO
var zoom := 20.0
var rendered_zoom := 20.0
var following := true
var status: Label
var quest_label: Label
var save_label: Label
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var journal_button: Button
var goal_button: Button
var follow_button: Button
var stop_button: Button
var minus_button: Button
var plus_button: Button
var return_button: Button
var conversation: ConfirmationDialog
var journal: AcceptDialog
var notice: AcceptDialog
var return_dialog: ConfirmationDialog
var diagnostics_panel
var contacts: Dictionary = {}
var gesture_started := false
var gesture_dragged := false
var gesture_multi := false
var gesture_start := Vector2.ZERO
var pinch_distance := 0.0
var mouse_dragging := false
var checkpoint_age := 0.0
var perf_age := 0.0
var perf_max_ms := 0.0

func _ready() -> void:
    navigation.configure(LIMIT)
    progress.open_profile(GameState.world_progress_path, GameState.faction_index, GameState.officer_index)
    _create_world()
    var saved: Dictionary = progress.state()
    var restored := Vector3(float(saved["position"][0]), 0, float(saved["position"][1]))
    hero.position = restored if navigation.is_walkable(navigation.world_to_cell(restored)) else PROGRESS.SPAWN
    zoom = float(saved["zoom"])
    rendered_zoom = zoom
    focus = hero.position
    rendered_focus = focus
    _create_ui()
    _refresh()
    _update_camera(0)
    if not progress.writable:
        call_deferred("_show_notice", progress.error_text)
    elif progress.recovered:
        save_label.text = "Прогресс восстановлен из резервной копии."
    _event("zone_entered", {"character": progress.character_id, "recovered": progress.recovered})

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    return mat

func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var visual := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = size
    visual.mesh = box
    visual.position = at + Vector3.UP * size.y * 0.5
    visual.material_override = _material(color)
    parent.add_child(visual)
    return visual

func _caption(parent: Node3D, text: String, height: float) -> Label3D:
    var label := Label3D.new()
    label.text = text
    label.position.y = height
    label.pixel_size = 0.012
    label.outline_size = 4
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    parent.add_child(label)
    return label

func _person(parent: Node3D, at: Vector3, color: Color, actor_name: String) -> Node3D:
    var actor := Node3D.new()
    actor.name = actor_name
    actor.position = at
    parent.add_child(actor)
    var visual := MeshInstance3D.new()
    visual.name = "Placeholder"
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.4
    capsule.height = 1.8
    visual.mesh = capsule
    visual.position.y = 0.9
    visual.material_override = _material(color)
    actor.add_child(visual)
    _box(actor, Vector3(0, 0.7, 0.4), Vector3(0.12, 0.12, 0.4), Color("#adf4f2"))
    return actor

func _create_world() -> void:
    var environment := WorldEnvironment.new()
    var sky := Environment.new()
    sky.background_mode = Environment.BG_COLOR
    sky.background_color = Color("#0a1822")
    sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    sky.ambient_light_color = Color("#adcfdb")
    sky.ambient_light_energy = 0.75
    environment.environment = sky
    add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.1
    add_child(sun)
    _box(self, Vector3(0, -0.4, 0), Vector3(66, 0.4, 66), Color("#203c40"))
    # Concrete pads, luminous conduits and low perimeter rocks are visual only.
    for at in [NPC_AT, RELAY_AT[0], RELAY_AT[1], RELAY_AT[2]]:
        _box(self, at + Vector3(0, 0.01, 0), Vector3(6, 0.06, 6), Color("#3d5257"))
        _box(self, at + Vector3(-2.5, 0.08, 0), Vector3(0.1, 0.04, 5.0), Color("#60d8d8"))
    for item in COVER:
        _box(self, item[0], item[1], Color("#42535a"))
        navigation.set_blocked_box(item[0], item[1], 0.7)
    for i in range(17):
        var x := -32.0 + i * 4.0
        for z in [-32.0, 32.0]:
            _box(self, Vector3(x, 0, z), Vector3(2.7, 1.0 + (i % 3) * 0.5, 2.0), Color("#293d46"))
    npc = _person(self, NPC_AT, Color("#d4c17e"), "SignalOperator")
    _caption(npc, "СВЯЗИСТ ВЕГА\nКоснись, чтобы поговорить", 3.0)
    navigation.set_blocked_box(NPC_AT, Vector3(0.8, 1.8, 0.8), 0.6)
    _box(self, NPC_AT + Vector3(-3, 0, 0), Vector3(1.5, 2.3, 1.4), Color("#617a80"))
    navigation.set_blocked_box(NPC_AT + Vector3(-3, 0, 0), Vector3(1.5, 2.3, 1.4), 0.6)
    for i in range(RELAY_AT.size()):
        var relay := Node3D.new()
        relay.name = "WorldRelay_%d" % (i + 1)
        relay.position = RELAY_AT[i]
        add_child(relay)
        _box(relay, Vector3.ZERO, Vector3(1.4, 0.6, 1.4), Color("#62707d"))
        lamps.append(_box(relay, Vector3(0, 0.6, 0), Vector3(0.22, 2.2, 0.22), Color("#e4b26d")))
        _box(relay, Vector3(0, 2.6, 0), Vector3(1.4, 0.12, 0.35), Color("#9dc3c9"))
        relay_labels.append(_caption(relay, "", 3.6))
        relays.append(relay)
        navigation.set_blocked_box(relay.position, Vector3(1.4, 2.8, 1.4), 0.5)
    hero = _person(self, PROGRESS.SPAWN, Color("#91c6bc"), "WorldHero")
    if GameState.faction_index == 0 and GameState.officer_index == 0 and ResourceLoader.exists(AMINA):
        var packed := load(AMINA) as PackedScene
        var model := packed.instantiate() as Node3D
        var mount := Node3D.new()
        mount.name = "StaticCommanderPreview"
        hero.add_child(mount)
        mount.add_child(model)
        if FIT.fit_to_height(model, 1.9).get("ok", false):
            hero.get_node("Placeholder").hide()
    target_marker = MeshInstance3D.new()
    var ring := TorusMesh.new()
    ring.inner_radius = 0.45
    ring.outer_radius = 0.57
    target_marker.mesh = ring
    target_marker.material_override = _material(Color("#69e6e5"))
    target_marker.hide()
    add_child(target_marker)
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 55
    add_child(camera)

func _button(text: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.custom_minimum_size = Vector2(82, 46)
    button.add_theme_font_size_override("font_size", 15)
    button.pressed.connect(action)
    return button

func _label(parent: Node, text: String, size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", size)
    parent.add_child(label)
    return label

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)
    top_panel = PanelContainer.new()
    top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top_panel.offset_left = 16
    top_panel.offset_top = 12
    top_panel.offset_right = -16
    ui.add_child(top_panel)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.075, 0.10, 0.94)
    style.set_border_width_all(1)
    style.border_color = Color("#37616b")
    style.set_content_margin_all(12)
    top_panel.add_theme_stylebox_override("panel", style)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 6)
    top_panel.add_child(body)
    _label(body, "СЕКТОР 01 · ПРИБРЕЖНЫЙ УЗЕЛ", 23)
    status = _label(body, "", 15)
    quest_label = _label(body, "", 17)
    var bar := HFlowContainer.new()
    body.add_child(bar)
    journal_button = _button("ЖУРНАЛ", _open_journal)
    goal_button = _button("ПОКАЗАТЬ ЦЕЛЬ", _show_goal)
    follow_button = _button("К ГЕРОЮ", _follow)
    stop_button = _button("СТОП", _stop)
    minus_button = _button("−", _change_zoom.bind(1.2))
    plus_button = _button("+", _change_zoom.bind(1.0 / 1.2))
    return_button = _button("НА КОРАБЛЬ", _request_return)
    for button in [journal_button, goal_button, follow_button, stop_button, minus_button, plus_button]:
        bar.add_child(button)
    diagnostics_panel = DIAGNOSTICS.new()
    add_child(diagnostics_panel)
    if RTSDiagnostics.enabled:
        bar.add_child(_button("ЛОГИ", diagnostics_panel._open))
    bar.add_child(return_button)
    bottom_panel = PanelContainer.new()
    bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    bottom_panel.offset_left = 16
    bottom_panel.offset_right = -16
    bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
    ui.add_child(bottom_panel)
    bottom_panel.add_theme_stylebox_override("panel", style)
    var bottom := VBoxContainer.new()
    bottom_panel.add_child(bottom)
    save_label = _label(bottom, "Прогресс сохраняется на устройстве.", 14)
    _label(bottom, "Касание — идти / подойти к объекту. Свайп — камера. Два пальца — масштаб.", 14)
    conversation = ConfirmationDialog.new()
    conversation.title = "Связист Вега · Сигнал с берега"
    conversation.cancel_button_text = "ПОЗЖЕ"
    conversation.confirmed.connect(_accept_conversation)
    add_child(conversation)
    journal = AcceptDialog.new()
    journal.title = "Журнал · Сигнал с берега"
    add_child(journal)
    notice = AcceptDialog.new()
    notice.title = "Сектор 01"
    add_child(notice)
    return_dialog = ConfirmationDialog.new()
    return_dialog.title = "Вернуться на корабль?"
    return_dialog.dialog_text = "Положение и задание сохранятся. Продолжишь с этого места."
    return_dialog.ok_button_text = "НА КОРАБЛЬ"
    return_dialog.cancel_button_text = "ОСТАТЬСЯ"
    return_dialog.confirmed.connect(_return_to_ship)
    add_child(return_dialog)

func _popup(dialog: AcceptDialog) -> void:
    _reset_gesture()
    dialog.popup_centered(Vector2i(620, 260))

func _refresh() -> void:
    var saved: Dictionary = progress.state()
    status.text = "%s · Опыт %d · Кредиты %d · Локальная зона" % [GameState.officer_name.split(" — ")[0], progress.experience(), progress.credits()]
    if saved["claimed"]:
        quest_label.text = "СИГНАЛ ВОССТАНОВЛЕН · Награда получена. Можно исследовать сектор."
    elif not saved["accepted"]:
        quest_label.text = "Поговори со связистом Вегой возле посадочной площадки."
    elif saved["relays"].size() == 3:
        quest_label.text = "МАЯКИ 3/3 · Вернись к Веге за наградой."
    else:
        quest_label.text = "СИГНАЛ С БЕРЕГА · Восстанови маяки: %d/3" % saved["relays"].size()
    for i in range(relays.size()):
        var active: bool = saved["relays"].has(i)
        relay_labels[i].text = "МАЯК %d\n%s" % [i + 1, "В СЕТИ" if active else "ВОССТАНОВИТЬ"]
        lamps[i].material_override.albedo_color = Color("#69e6e5") if active else Color("#e4b26d")

func _event(name: String, details: Dictionary = {}) -> void:
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("world", name, details)

func _show_notice(message: String) -> void:
    notice.dialog_text = message
    _popup(notice)

func _open_journal() -> void:
    journal.dialog_text = "Вега просит вернуть связь с тремя береговыми маяками.\nКоснись связиста, чтобы принять задание, затем каждого маяка.\n\nМаяк 1: северо-запад. Маяк 2: северо-восток. Маяк 3: юго-восток.\n«ПОКАЗАТЬ ЦЕЛЬ» переносит камеру к следующей цели.\nПосле восстановления всех трёх вернись к Веге.\nНаграда: 100 опыта и 75 кредитов один раз.\n\n" + quest_label.text
    _popup(journal)

func _show_goal() -> void:
    var saved: Dictionary = progress.state()
    focus = NPC_AT
    if saved["accepted"] and not saved["claimed"]:
        for i in range(relays.size()):
            if not saved["relays"].has(i):
                focus = RELAY_AT[i]
                break
    following = false

func _follow() -> void:
    following = true

func _stop() -> void:
    route.clear()
    route_index = 0
    interaction = -2
    target_marker.hide()

func _change_zoom(factor: float) -> void:
    zoom = clampf(zoom * factor, 8, 30)

func _modal_open() -> bool:
    var debug_open: bool = diagnostics_panel != null and diagnostics_panel.popup != null and diagnostics_panel.popup.visible
    return conversation.visible or journal.visible or notice.visible or return_dialog.visible or debug_open

func _over_ui(at: Vector2) -> bool:
    return _modal_open() or top_panel.get_global_rect().has_point(at) or bottom_panel.get_global_rect().has_point(at)

func _input(event: InputEvent) -> void:
    if event.device == InputEvent.DEVICE_ID_EMULATION:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if contacts.is_empty():
                if _over_ui(event.position):
                    return
                gesture_started = true
                gesture_start = event.position
                gesture_dragged = false
                gesture_multi = false
            if not gesture_started:
                return
            contacts[event.index] = event.position
            if contacts.size() > 1:
                gesture_multi = true
                var points := contacts.values()
                pinch_distance = points[0].distance_to(points[1])
        elif contacts.has(event.index):
            var tap: bool = not event.canceled and contacts.size() == 1 and not gesture_dragged and not gesture_multi and not _over_ui(event.position)
            contacts.erase(event.index)
            if tap:
                _tap(event.position)
            if contacts.is_empty():
                _reset_gesture()
        else:
            return
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and contacts.has(event.index):
        contacts[event.index] = event.position
        if contacts.size() > 1:
            var points := contacts.values()
            var distance: float = points[0].distance_to(points[1])
            if distance > 8 and pinch_distance > 8:
                _change_zoom(pinch_distance / distance)
            pinch_distance = distance
        elif not gesture_multi and not _over_ui(event.position):
            if gesture_dragged:
                _pan(event.relative)
            elif event.position.distance_to(gesture_start) >= 16:
                gesture_dragged = true
                following = false
        get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed and not _over_ui(event.position):
                mouse_dragging = true
                gesture_start = event.position
                gesture_dragged = false
            elif mouse_dragging:
                mouse_dragging = false
                if not gesture_dragged and not _over_ui(event.position):
                    _tap(event.position)
        elif event.pressed and not _over_ui(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            _change_zoom(0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.15)
    elif event is InputEventMouseMotion and mouse_dragging:
        if event.position.distance_to(gesture_start) >= 16:
            gesture_dragged = true
        if gesture_dragged and not _over_ui(event.position):
            _pan(event.relative)
    elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _handle_back()
        get_viewport().set_input_as_handled()

func _reset_gesture() -> void:
    contacts.clear()
    gesture_started = false
    gesture_dragged = false
    gesture_multi = false
    mouse_dragging = false
    pinch_distance = 0

func _pan(pixels: Vector2) -> void:
    following = false
    focus -= Vector3(pixels.x, 0, pixels.y).limit_length(45) * zoom * 0.0014
    focus.x = clampf(focus.x, -LIMIT, LIMIT)
    focus.z = clampf(focus.z, -LIMIT, LIMIT)

func _ground(at: Vector2) -> Variant:
    var hit: Variant = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(at), camera.project_ray_normal(at))
    if hit == null or absf(hit.x) > LIMIT or absf(hit.z) > LIMIT:
        return null
    return hit

func _tap(at: Vector2) -> void:
    if _over_ui(at):
        return
    var best := 30.0
    var picked := -2
    var actors: Array[Node3D] = [npc]
    actors.append_array(relays)
    for i in range(actors.size()):
        var actor := actors[i]
        if camera.is_position_behind(actor.position + Vector3.UP):
            continue
        var a := camera.unproject_position(actor.position)
        var b := camera.unproject_position(actor.position + Vector3.UP * 3.2)
        var distance := at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))
        if distance < best:
            best = distance
            picked = i - 1
    if picked != -2:
        _approach(picked)
    else:
        var point: Variant = _ground(at)
        if point != null:
            _move_to(point)

func _move_to(point: Vector3) -> bool:
    var planned: Array[Vector3] = navigation.get_path(hero.position, point)
    if planned.is_empty():
        return false
    route = planned
    route_index = 0
    interaction = -2
    target_marker.position = route.back() + Vector3(0, 0.08, 0)
    target_marker.show()
    _event("move_order", {"at": str(point)})
    return true

func _approach(target: int) -> void:
    var at: Vector3 = NPC_AT if target == -1 else RELAY_AT[target]
    if hero.position.distance_to(at) <= 3.0:
        _stop()
        _interact(target)
    elif _move_to(at + Vector3(0, 0, 2.5)):
        interaction = target

func _interact(target: int) -> void:
    var at: Vector3 = NPC_AT if target == -1 else RELAY_AT[target]
    if hero.position.distance_to(at) > 3.0:
        return
    if target == -1:
        var saved: Dictionary = progress.state()
        if saved["claimed"]:
            _show_notice("Связист Вега: связь устойчива. Спасибо! Награда уже получена.")
            return
        if not saved["accepted"]:
            conversation.dialog_text = "Связь с береговыми маяками пропала. Восстанови три ретранслятора и вернись ко мне.\n\nКоснись маяка: герой подойдёт и включит его.\nНаграда: 100 опыта и 75 кредитов."
            conversation.ok_button_text = "ПРИНЯТЬ ЗАДАНИЕ"
        elif saved["relays"].size() < 3:
            _show_notice("Связист Вега: в сети %d из 3 маяков. Продолжай разведку. Кнопка «ПОКАЗАТЬ ЦЕЛЬ» поможет найти следующий." % saved["relays"].size())
            return
        else:
            conversation.dialog_text = "Все три маяка в сети. Забирай награду: 100 опыта и 75 кредитов."
            conversation.ok_button_text = "ПОЛУЧИТЬ НАГРАДУ"
        _popup(conversation)
    elif not progress.state()["accepted"]:
        _show_notice("У маяка нет задания на настройку. Сначала поговори со связистом Вегой.")
    elif progress.activate(target):
        var saved: bool = _checkpoint()
        _refresh()
        _event("relay_activated", {"relay": target + 1})
        if saved:
            save_label.text = "Маяк %d в сети. Прогресс сохранён." % (target + 1)
        else:
            _show_notice(progress.error_text)
    else:
        _show_notice(progress.error_text)

func _accept_conversation() -> void:
    if hero.position.distance_to(NPC_AT) > 3.0:
        return
    var saved: Dictionary = progress.state()
    if saved["claimed"] or (saved["accepted"] and saved["relays"].size() < 3):
        return
    var ok: bool = progress.begin_quest() if not saved["accepted"] else progress.claim_reward()
    if not ok:
        _show_notice(progress.error_text)
        return
    if not _checkpoint():
        _show_notice(progress.error_text)
    _refresh()
    _event("quest_rewarded" if progress.state()["claimed"] else "quest_accepted", {"xp": progress.experience(), "credits": progress.credits()})

func _physics_process(delta: float) -> void:
    if _modal_open():
        return
    var travel := maxf(delta, 0) * SPEED
    while route_index < route.size() and travel > 0:
        var next: Vector3 = route[route_index]
        var distance := hero.position.distance_to(next)
        var direction := next - hero.position
        if direction.length_squared() > 0.0001:
            heading = atan2(direction.x, direction.z)
        var step := minf(travel, distance)
        hero.position = hero.position.move_toward(next, step)
        travel -= step
        if distance <= step + 0.0001:
            route_index += 1
    hero.rotation.y = lerp_angle(hero.rotation.y, heading, 1.0 - exp(-maxf(delta, 0) * 12))
    if not route.is_empty() and route_index >= route.size():
        var target := interaction
        _stop()
        _checkpoint()
        if target != -2:
            _interact(target)

func _process(delta: float) -> void:
    _update_camera(delta)
    checkpoint_age += delta
    if checkpoint_age >= 2:
        checkpoint_age = 0
        _checkpoint()
    perf_age += delta
    perf_max_ms = maxf(perf_max_ms, delta * 1000)
    if perf_age >= 5:
        _event("WORLD_PERF", {"fps": Engine.get_frames_per_second(), "max_frame_ms": snappedf(perf_max_ms, 0.1), "characters": 1, "route_points": route.size()})
        perf_age = 0
        perf_max_ms = 0

func _update_camera(delta: float) -> void:
    if following:
        focus = hero.position
    var weight := 1.0 - exp(-clampf(delta, 0, 0.1) * 8)
    rendered_focus = rendered_focus.lerp(focus, weight)
    rendered_zoom = lerpf(rendered_zoom, zoom, weight)
    camera.position = rendered_focus + Vector3(0, rendered_zoom, rendered_zoom * 0.95)
    camera.look_at(rendered_focus + Vector3.UP)

func _checkpoint() -> bool:
    if not progress.writable:
        save_label.text = progress.error_text
        return false
    var ok: bool = progress.checkpoint(hero.position, zoom)
    save_label.text = "Прогресс сохранён." if ok else progress.error_text
    return ok

func _request_return() -> void:
    _popup(return_dialog)

func _return_to_ship() -> void:
    if progress.writable and not _checkpoint():
        _show_notice(progress.error_text)
        return
    _event("zone_left", {"character": progress.character_id})
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _handle_back() -> void:
    _reset_gesture()
    for dialog in [notice, conversation, journal, return_dialog, diagnostics_panel.popup]:
        if is_instance_valid(dialog) and dialog.visible:
            dialog.hide()
            return
    _request_return()

func _notification(what: int) -> void:
    if hero == null or save_label == null:
        return
    if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
        _reset_gesture()
        _checkpoint()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _handle_back()
