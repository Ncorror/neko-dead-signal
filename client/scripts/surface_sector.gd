extends Node3D
## First authored 128x128 environment. Independent entry and progress; original modes stay intact.

const ENVIRONMENT := preload("res://scripts/surface_environment.gd")
const TERRAIN := preload("res://scripts/surface_terrain.gd")
const NAV := preload("res://scripts/rts_navigation.gd")
const STORE := preload("res://scripts/surface_progress.gd")
const MAP := preload("res://scripts/surface_map.gd")
const FIT := preload("res://scripts/rts_character_fit.gd")
const DIAGNOSTICS := preload("res://scripts/rts_diagnostics_ui.gd")
const AMINA := "res://assets/characters/amina/preview.glb"
const CHARACTER_IDS := [["amina", "reina", "mira_kade", "lyra_voss"], ["saira_nel", "oralin"]]
const SPEED := 4.2
const DESCRIPTIONS := ["Форпост экспедиции. Вега просит обследовать четыре ориентира за воротами.",
    "Разбитый транспорт. Сохранились фюзеляж, двигатель и обломки крыла.",
    "Площадка утилизации. Контейнеры и кран стоят у восточного маршрута.",
    "Древний радиоузел на возвышенности. Кольцо стел окружает терминал.",
    "Низина каньона и вход в пещеру. Переход в данж появится отдельным этапом."]

var world = ENVIRONMENT.new()
var navigation = NAV.new()
var progress = STORE.new()
var hero: Node3D
var camera: Camera3D
var target_marker: MeshInstance3D
var route: Array[Vector3] = []
var route_index := 0
var heading := 0.0
var visited: Array = []
var goal := 1
var following := true
var focus := Vector3.ZERO
var rendered_focus := Vector3.ZERO
var zoom := 16.0
var rendered_zoom := 16.0
var peek := 0.0
var contacts: Dictionary = {}
var gesture_origin := Vector2.ZERO
var gesture_blocked := false
var gesture_dragged := false
var gesture_multi := false
var pinch_distance := 0.0
var mouse_dragging := false
var talk_pending := false
var checkpoint_age := 0.0
var perf_age := 0.0
var max_frame_ms := 0.0
var top_panel: PanelContainer
var bottom_panel: PanelContainer
var status: Label
var target_label: Label
var save_label: Label
var sites_button: Button
var follow_button: Button
var stop_button: Button
var goal_button: Button
var return_button: Button
var logs_button: Button
var site_buttons: Array[Button] = []
var minus_button: Button
var plus_button: Button
var journal: AcceptDialog
var notice: AcceptDialog
var return_dialog: ConfirmationDialog
var diagnostics_panel
var minimap

func _ready() -> void:
    var started := Time.get_ticks_msec()
    var id: String = CHARACTER_IDS[GameState.faction_index][GameState.officer_index]
    progress.open_profile(GameState.surface_progress_path, id)
    add_child(world)
    world.build(navigation)
    _create_hero()
    var saved: Dictionary = progress.state()
    var at := Vector3(float(saved["position"][0]), 0, float(saved["position"][1]))
    hero.position = world.terrain.on_ground(at if navigation.is_walkable(navigation.world_to_cell(at)) else TERRAIN.SPAWN)
    visited = saved["visited"].duplicate()
    zoom = float(saved["zoom"])
    rendered_zoom = zoom
    focus = hero.position
    rendered_focus = focus
    camera = Camera3D.new()
    camera.current = true
    camera.fov = 55
    camera.far = 240
    add_child(camera)
    target_marker = MeshInstance3D.new()
    var ring := TorusMesh.new()
    ring.inner_radius = 0.5
    ring.outer_radius = 0.62
    target_marker.mesh = ring
    target_marker.material_override = world.material(Color("#dfc485"), 0.3)
    target_marker.hide()
    add_child(target_marker)
    _create_ui()
    _discover()
    _refresh()
    _update_camera(0)
    _event("surface_entered", {"size": 128, "character": id, "build_ms": Time.get_ticks_msec() - started,
        "terrain_triangles": 32768, "height_min": world.terrain.minimum, "height_max": world.terrain.maximum})
    if not progress.writable:
        call_deferred("_show_notice", progress.error_text)

func _create_hero() -> void:
    hero = Node3D.new()
    hero.name = "SurfaceHero"
    add_child(hero)
    var loaded := false
    if GameState.faction_index == 0 and GameState.officer_index == 0 and ResourceLoader.exists(AMINA):
        var packed := load(AMINA) as PackedScene
        var model := packed.instantiate() as Node3D
        hero.add_child(model)
        loaded = FIT.fit_to_height(model, 1.9).get("ok", false)
    if not loaded:
        var actor := MeshInstance3D.new()
        var capsule := CapsuleMesh.new()
        capsule.radius = 0.38
        capsule.height = 1.8
        actor.mesh = capsule
        actor.position.y = 0.9
        actor.material_override = world.material(Color("#88c2c6"))
        hero.add_child(actor)
    world.caption(hero, GameState.officer_name.split(" — ")[0], 2.5)

func _label(parent: Node, text: String, size: int) -> Label:
    var value := Label.new()
    value.text = text
    value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    value.mouse_filter = Control.MOUSE_FILTER_IGNORE
    value.add_theme_font_size_override("font_size", size)
    parent.add_child(value)
    return value

func _button(text: String, action: Callable) -> Button:
    var value := Button.new()
    value.text = text
    value.custom_minimum_size = Vector2(84, 46)
    value.add_theme_font_size_override("font_size", 14)
    value.pressed.connect(action)
    return value

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.065, 0.09, 0.94)
    style.border_color = Color("#486d7d")
    style.set_border_width_all(1)
    style.set_content_margin_all(10)
    top_panel = PanelContainer.new()
    top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top_panel.offset_left = 16
    top_panel.offset_top = 10
    top_panel.offset_right = -16
    top_panel.add_theme_stylebox_override("panel", style)
    layer.add_child(top_panel)
    var body := VBoxContainer.new()
    top_panel.add_child(body)
    _label(body, "ПЛАНЕТА · ПЕРВЫЙ СЕКТОР · 128 × 128", 21)
    status = _label(body, "", 14)
    var bar := HFlowContainer.new()
    body.add_child(bar)
    sites_button = _button("ТОЧКИ ИНТЕРЕСА", _open_sites)
    follow_button = _button("К ГЕРОЮ", _follow)
    stop_button = _button("СТОП", _stop)
    minus_button = _button("−", _change_zoom.bind(1.2))
    plus_button = _button("+", _change_zoom.bind(1 / 1.2))
    return_button = _button("НА КОРАБЛЬ", _request_return)
    for button in [sites_button, follow_button, stop_button, minus_button, plus_button]:
        bar.add_child(button)
    diagnostics_panel = DIAGNOSTICS.new()
    add_child(diagnostics_panel)
    diagnostics_panel.install(self, bar)
    logs_button = diagnostics_panel.open_button
    bar.add_child(return_button)
    bottom_panel = PanelContainer.new()
    bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    bottom_panel.offset_left = 16
    bottom_panel.offset_right = -16
    bottom_panel.offset_bottom = -10
    bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
    bottom_panel.add_theme_stylebox_override("panel", style)
    layer.add_child(bottom_panel)
    var row := HBoxContainer.new()
    bottom_panel.add_child(row)
    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(info)
    target_label = _label(info, "", 16)
    goal_button = _button("К ЦЕЛИ", _go_to_goal)
    info.add_child(goal_button)
    save_label = _label(info, "Новая локация сохраняется отдельно.", 13)
    _label(info, "Касание — идти. Свайп — временный осмотр. Два пальца — масштаб. Вега — разговор.", 13)
    minimap = MAP.new()
    row.add_child(minimap)
    minimap.install(self)
    journal = AcceptDialog.new()
    journal.title = "Первый сектор · Маршруты"
    journal.min_size = Vector2i(620, 350)
    add_child(journal)
    var list := VBoxContainer.new()
    journal.add_child(list)
    for i in range(TERRAIN.SITES.size()):
        var button := _button("%02d · %s" % [i + 1, TERRAIN.SITE_NAMES[i]], _select_site.bind(i))
        list.add_child(button)
        site_buttons.append(button)
    notice = AcceptDialog.new()
    notice.title = "Первый сектор"
    add_child(notice)
    return_dialog = ConfirmationDialog.new()
    return_dialog.title = "Вернуться на корабль?"
    return_dialog.dialog_text = "Положение, масштаб и обследованные места сохранятся."
    return_dialog.ok_button_text = "НА КОРАБЛЬ"
    return_dialog.cancel_button_text = "ОСТАТЬСЯ"
    return_dialog.confirmed.connect(_return_to_ship)
    add_child(return_dialog)

func _event(name: String, details: Dictionary = {}) -> void:
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("surface", name, details)

func _refresh() -> void:
    status.text = "%s · Обследовано %d/5 · Высота %.1f" % [GameState.officer_name.split(" — ")[0], visited.size(), hero.position.y]
    var distance: float = Vector2(hero.position.x - TERRAIN.SITES[goal].x, hero.position.z - TERRAIN.SITES[goal].z).length()
    target_label.text = "%02d · %s · %.0f м" % [goal + 1, TERRAIN.SITE_NAMES[goal], distance]
    minimap.queue_redraw()

func _modal_open() -> bool:
    return journal.visible or notice.visible or return_dialog.visible or (diagnostics_panel.popup != null and diagnostics_panel.popup.visible)

func _popup(dialog: AcceptDialog) -> void:
    _reset_gesture()
    dialog.popup_centered(Vector2i(620, 350))

func _show_notice(text: String) -> void:
    notice.dialog_text = text
    _popup(notice)

func _open_sites() -> void:
    for i in range(site_buttons.size()):
        site_buttons[i].text = ("✓ " if visited.has(i) else "○ ") + "%02d · %s" % [i + 1, TERRAIN.SITE_NAMES[i]]
    _popup(journal)

func _select_site(id: int) -> void:
    goal = id
    journal.hide()
    following = false
    focus = world.terrain.on_ground(TERRAIN.SITES[id])
    peek = 4
    _refresh()

func _go_to_goal() -> void:
    _move_to(TERRAIN.SITES[goal])

func _discover() -> void:
    for i in range(TERRAIN.SITES.size()):
        if visited.has(i) or Vector2(hero.position.x - TERRAIN.SITES[i].x, hero.position.z - TERRAIN.SITES[i].z).length() > 4:
            continue
        visited.append(i)
        if save_label != null:
            _checkpoint()
            save_label.text = DESCRIPTIONS[i]
            _refresh()
        _event("site_discovered", {"site": i, "at": str(hero.position)})

func _ground(at: Vector2) -> Variant:
    var start := camera.project_ray_origin(at)
    var query := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(at) * 350, 1)
    query.hit_back_faces = true
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return null
    var point: Vector3 = hit["position"]
    return point if absf(point.x) <= TERRAIN.PLAY_LIMIT and absf(point.z) <= TERRAIN.PLAY_LIMIT else null

func _tap(at: Vector2) -> void:
    var point: Variant = _ground(at)
    if point == null:
        return
    var npc_at: Vector3 = world.npc.position
    var head := camera.unproject_position(npc_at + Vector3.UP)
    if at.distance_to(head) < 27:
        if hero.position.distance_to(npc_at) < 3:
            _show_notice("Вега: обследуй остов транспорта, поле утилизации, древний радиоузел и вход в пещеру.\n\nВыбирай место в «ТОЧКИ ИНТЕРЕСА», затем «К ЦЕЛИ» — герой пройдёт по доступному маршруту.\n\nЭто разведка новой местности. Твои прежние поручения и ресурсы сохраняются в форпосте.")
        else:
            talk_pending = _move_to(npc_at + Vector3(0, 0, 2))
    else:
        _move_to(point)

func _move_to(point: Vector3) -> bool:
    if not point.is_finite() or absf(point.x) > TERRAIN.PLAY_LIMIT or absf(point.z) > TERRAIN.PLAY_LIMIT:
        return false
    var flat_start := Vector3(hero.position.x, 0, hero.position.z)
    var path: Array[Vector3] = navigation.get_path(flat_start, point)
    if path.is_empty():
        save_label.text = "Здесь нет прохода. Выбери другую точку."
        return false
    route = path
    route_index = 0
    talk_pending = false
    _follow()
    target_marker.position = world.terrain.on_ground(route.back(), 0.1)
    target_marker.show()
    _event("move_order", {"to": str(point), "route_points": route.size()})
    return true

func _stop() -> void:
    route.clear()
    route_index = 0
    talk_pending = false
    target_marker.hide()

func _physics_process(delta: float) -> void:
    if _modal_open():
        return
    var travel := maxf(delta, 0) * SPEED
    while route_index < route.size() and travel > 0:
        var next: Vector3 = route[route_index]
        var direction := Vector3(next.x - hero.position.x, 0, next.z - hero.position.z)
        var distance := direction.length()
        if distance > 0.0001:
            heading = atan2(direction.x, direction.z)
        var step := minf(travel, distance)
        var flat := Vector3(hero.position.x, 0, hero.position.z).move_toward(next, step)
        hero.position = world.terrain.on_ground(flat)
        travel -= step
        if distance <= step + 0.0001:
            route_index += 1
    hero.rotation.y = lerp_angle(hero.rotation.y, heading, 1 - exp(-maxf(delta, 0) * 12))
    _discover()
    if not route.is_empty() and route_index >= route.size():
        var talk := talk_pending
        _stop()
        _checkpoint()
        if talk and hero.position.distance_to(world.npc.position) < 3:
            _show_notice("Вега: за воротами четыре ориентира. Обследуй их через меню «ТОЧКИ ИНТЕРЕСА» и возвращайся.")

func _process(delta: float) -> void:
    _update_camera(delta)
    _refresh()
    checkpoint_age += delta
    if checkpoint_age >= 2:
        checkpoint_age = 0
        _checkpoint()
    perf_age += delta
    max_frame_ms = maxf(max_frame_ms, delta * 1000)
    if perf_age >= 5:
        _event("SURFACE_PERF", {"fps": Engine.get_frames_per_second(), "max_frame_ms": snappedf(max_frame_ms, 0.1),
            "at": str(hero.position), "size": 128, "visited": visited.size(), "follow": following, "zoom": zoom})
        perf_age = 0
        max_frame_ms = 0

func _checkpoint() -> bool:
    var ok: bool = progress.checkpoint(hero.position, zoom, visited)
    save_label.text = "Прогресс новой локации сохранён." if ok else progress.error_text
    return ok

func _follow() -> void:
    following = true
    focus = hero.position
    peek = 0

func _pan(delta: Vector2) -> void:
    following = false
    peek = 1.5
    focus -= Vector3(delta.x, 0, delta.y).limit_length(45) * zoom * 0.0014
    focus.x = clampf(focus.x, -TERRAIN.PLAY_LIMIT, TERRAIN.PLAY_LIMIT)
    focus.z = clampf(focus.z, -TERRAIN.PLAY_LIMIT, TERRAIN.PLAY_LIMIT)
    focus.y = world.terrain.height(focus.x, focus.z)

func _change_zoom(factor: float) -> void:
    zoom = clampf(zoom * factor, 8, 30)

func _update_camera(delta: float) -> void:
    if not following and contacts.is_empty() and not mouse_dragging and not _modal_open():
        peek = maxf(0, peek - maxf(delta, 0))
        if peek == 0:
            _follow()
    if following:
        focus = hero.position
    var weight := 1 - exp(-clampf(delta, 0, 0.1) * 8)
    rendered_focus = rendered_focus.lerp(focus, weight)
    rendered_zoom = lerpf(rendered_zoom, zoom, weight)
    camera.position = rendered_focus + Vector3(0, rendered_zoom, rendered_zoom * 0.95)
    var target := rendered_focus + Vector3.UP
    camera.look_at(target)
    var rect := get_viewport().get_visible_rect()
    var top: float = top_panel.get_global_rect().end.y
    var bottom: float = bottom_panel.get_global_rect().position.y
    if bottom - top > 180:
        var centre := Vector2(rect.get_center().x, (top + bottom) * 0.5)
        camera.position += target - camera.project_position(centre, -camera.to_local(target).z)

func _over_ui(at: Vector2) -> bool:
    return _modal_open() or top_panel.get_global_rect().has_point(at) or bottom_panel.get_global_rect().has_point(at)

func _reset_gesture() -> void:
    contacts.clear()
    gesture_multi = false
    gesture_dragged = false
    gesture_blocked = false
    mouse_dragging = false
    pinch_distance = 0

func _input(event: InputEvent) -> void:
    if event.device == InputEvent.DEVICE_ID_EMULATION:
        return
    if event is InputEventScreenTouch:
        if event.pressed:
            if contacts.is_empty():
                gesture_origin = event.position
                gesture_blocked = _over_ui(event.position)
                gesture_dragged = false
                gesture_multi = false
            contacts[event.index] = event.position
            if contacts.size() > 1:
                gesture_multi = true
                var points := contacts.values()
                pinch_distance = points[0].distance_to(points[1])
        elif contacts.has(event.index):
            var tap := not gesture_blocked and not event.canceled and not gesture_multi and not gesture_dragged and contacts.size() == 1 and not _over_ui(event.position)
            contacts.erase(event.index)
            if tap:
                _tap(event.position)
            if contacts.is_empty():
                _reset_gesture()
    elif event is InputEventScreenDrag and contacts.has(event.index):
        contacts[event.index] = event.position
        if gesture_blocked or _over_ui(event.position):
            return
        if contacts.size() > 1:
            var points := contacts.values()
            var distance: float = points[0].distance_to(points[1])
            if distance > 8 and pinch_distance > 8:
                _change_zoom(pinch_distance / distance)
            pinch_distance = distance
        elif not gesture_multi:
            if event.position.distance_to(gesture_origin) > 16:
                gesture_dragged = true
            if gesture_dragged:
                _pan(event.relative)
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                mouse_dragging = not _over_ui(event.position)
                gesture_origin = event.position
                gesture_dragged = false
            elif mouse_dragging:
                mouse_dragging = false
                if not gesture_dragged and not _over_ui(event.position):
                    _tap(event.position)
        elif event.pressed and not _over_ui(event.position) and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
            _change_zoom(0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.15)
    elif event is InputEventMouseMotion and mouse_dragging and not _over_ui(event.position):
        if event.position.distance_to(gesture_origin) > 16:
            gesture_dragged = true
        if gesture_dragged:
            _pan(event.relative)
    elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _handle_back()

func _request_return() -> void:
    _popup(return_dialog)

func _return_to_ship() -> void:
    if progress.writable and not _checkpoint():
        _show_notice(progress.error_text)
        return
    _event("surface_left", {"visited": visited.size()})
    get_tree().change_scene_to_file("res://scenes/main.tscn")

func _handle_back() -> void:
    _reset_gesture()
    for dialog in [journal, notice, return_dialog, diagnostics_panel.popup]:
        if is_instance_valid(dialog) and dialog.visible:
            dialog.hide()
            return
    _request_return()

func _notification(what: int) -> void:
    if hero == null or save_label == null:
        return
    if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT]:
        _reset_gesture()
        _checkpoint()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
        _handle_back()
