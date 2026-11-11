extends Node3D
## Earth North Belt 128x128 ground sector. Independent entry and progress; original modes stay intact.

const ENVIRONMENT := preload("res://scripts/surface_environment.gd")
const TERRAIN := preload("res://scripts/surface_terrain.gd")
const NAV := preload("res://scripts/rts_navigation.gd")
const STORE := preload("res://scripts/surface_progress.gd")
const MAP := preload("res://scripts/surface_map.gd")
const FIT := preload("res://scripts/rts_character_fit.gd")
const DIAGNOSTICS := preload("res://scripts/rts_diagnostics_ui.gd")
const AMINA := "res://assets/characters/amina/preview.glb"
const LYRA := preload("res://scripts/lyra_voss_animations.gd")
const CHARACTER_IDS := [["amina", "reina", "mira_kade", "lyra_voss"], ["saira_nel", "oralin"]]
const SPEED := 4.2
const RUN_SPEED := 5.8
const DESCRIPTIONS := ["Форпост NEKO на Северном поясе. Вега просит обследовать четыре ориентира за воротами.",
    "Разбитый транспорт. Сохранились фюзеляж, двигатель и обломки крыла.",
    "Площадка утилизации. Контейнеры и кран стоят у восточного маршрута.",
    "Древний радиоузел на возвышенности. Кольцо стел окружает терминал.",
    "Низина каньона и вход в пещеру. Переход в данж появится отдельным этапом."]

var world = ENVIRONMENT.new()
var navigation = NAV.new()
var progress = STORE.new()
var hero: Node3D
var hero_motion: AnimationPlayer
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
var speed_button: Button
var goal_button: Button
var return_button: Button
var pve_button: Button
var logs_button: Button
var site_buttons: Array[Button] = []
var minus_button: Button
var plus_button: Button
var help_button: Button
var journal: AcceptDialog
var notice: AcceptDialog
var return_dialog: ConfirmationDialog
var diagnostics_panel
var minimap
var run_mode := false

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
    elif GameState.faction_index == 0 and GameState.officer_index == 3:
        var installed: Dictionary = LYRA.mount(hero, 1.9)
        loaded = bool(installed.get("ok", false))
        if loaded:
            hero_motion = installed["player"]
        else:
            push_warning("SURFACE_LYRA_LOAD_FAILED " + str(installed.get("reason", "")))
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
    value.custom_minimum_size = Vector2(44, 44)
    value.add_theme_font_size_override("font_size", 14)
    value.pressed.connect(action)
    return value

func _create_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.065, 0.09, 0.88)
    style.border_color = Color("#486d7d")
    style.set_border_width_all(1)
    style.set_content_margin_all(6)
    top_panel = PanelContainer.new()
    top_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
    top_panel.offset_left = 8
    top_panel.offset_top = 8
    top_panel.offset_right = -8
    top_panel.add_theme_stylebox_override("panel", style)
    layer.add_child(top_panel)
    var body := HBoxContainer.new()
    body.add_theme_constant_override("separation", 10)
    top_panel.add_child(body)
    var header := VBoxContainer.new()
    header.custom_minimum_size.x = 232
    body.add_child(header)
    var title := _label(header, "СЕКТОР 01 · 128×128", 17)
    title.autowrap_mode = TextServer.AUTOWRAP_OFF
    status = _label(header, "", 13)
    status.autowrap_mode = TextServer.AUTOWRAP_OFF
    var bar := HFlowContainer.new()
    bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.add_theme_constant_override("h_separation", 6)
    bar.add_theme_constant_override("v_separation", 6)
    body.add_child(bar)
    sites_button = _button("ТОЧКИ ИНТЕРЕСА", _open_sites)
    follow_button = _button("К ГЕРОЮ", _follow)
    stop_button = _button("СТОП", _stop)
    speed_button = _button("ХОДЬБА", _toggle_move_mode)
    minus_button = _button("−", _change_zoom.bind(1.2))
    plus_button = _button("+", _change_zoom.bind(1 / 1.2))
    help_button = _button("?", _show_help)
    return_button = _button("НА БАЗУ", _request_return)
    pve_button = _button("МОБЫ И БОСС", _enter_pve)
    pve_button.tooltip_text = "Ржавый тракт · отдельная PvE-зона"
    pve_button.visible = GameState.faction_index == 0 and GameState.officer_index in [0, 3]
    for button in [sites_button, follow_button, stop_button, speed_button, minus_button, plus_button]:
        bar.add_child(button)
    diagnostics_panel = DIAGNOSTICS.new()
    add_child(diagnostics_panel)
    diagnostics_panel.install(self, bar)
    logs_button = diagnostics_panel.open_button
    if logs_button != null:
        logs_button.custom_minimum_size = Vector2(64, 44)
        logs_button.add_theme_font_size_override("font_size", 14)
    bar.add_child(help_button)
    bar.add_child(pve_button)
    bar.add_child(return_button)
    bottom_panel = PanelContainer.new()
    bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
    bottom_panel.offset_left = 8
    bottom_panel.offset_right = -8
    bottom_panel.offset_bottom = -8
    bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
    bottom_panel.add_theme_stylebox_override("panel", style)
    layer.add_child(bottom_panel)
    var row := HBoxContainer.new()
    bottom_panel.add_child(row)
    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(info)
    var action_row := HBoxContainer.new()
    info.add_child(action_row)
    target_label = _label(action_row, "", 16)
    target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    target_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    goal_button = _button("К ЦЕЛИ", _go_to_goal)
    goal_button.custom_minimum_size.x = 116
    action_row.add_child(goal_button)
    save_label = _label(info, "Прогресс сохраняется.", 13)
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
    return_dialog.title = "Вернуться в командный центр?"
    return_dialog.dialog_text = "Положение, масштаб и обследованные места сохранятся."
    return_dialog.ok_button_text = "НА БАЗУ"
    return_dialog.cancel_button_text = "ОСТАТЬСЯ"
    return_dialog.confirmed.connect(_return_to_ship)
    add_child(return_dialog)

func _event(name: String, details: Dictionary = {}) -> void:
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("surface", name, details)

func _refresh() -> void:
    status.text = "%s · %d/5 · Высота %.1f" % [GameState.officer_name.split(" — ")[0], visited.size(), hero.position.y]
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

func _show_help() -> void:
    _show_notice("Коснись земли — герой пойдёт к указанной точке.\nСвайп — временный осмотр; камера затем вернётся к герою.\nДва пальца или −/+ — масштаб. «СТОП» отменяет движение.\n\n«ТОЧКИ ИНТЕРЕСА» показывает места; выбери одно и нажми «К ЦЕЛИ». Для обследования подойди героем.\nКоснись Веги, чтобы поговорить. Прогресс сохраняется автоматически.")

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
    # A subpixel retry covers a ray landing exactly on a shared triangle edge.
    # Every result still comes from the terrain collider, never a flat plane.
    for offset in [Vector2.ZERO, Vector2(0.25, 0), Vector2(-0.25, 0), Vector2(0, 0.25), Vector2(0, -0.25)]:
        var pixel: Vector2 = at + offset
        var start := camera.project_ray_origin(pixel)
        var query := PhysicsRayQueryParameters3D.create(start, start + camera.project_ray_normal(pixel) * 350, 1)
        query.hit_back_faces = true
        var hit := get_world_3d().direct_space_state.intersect_ray(query)
        if hit.is_empty():
            continue
        var point: Vector3 = hit["position"]
        return point if absf(point.x) <= TERRAIN.PLAY_LIMIT and absf(point.z) <= TERRAIN.PLAY_LIMIT else null
    return null

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

func current_move_speed() -> float:
    return RUN_SPEED if run_mode else SPEED


func _toggle_move_mode() -> void:
    run_mode = not run_mode
    speed_button.text = "БЕГ" if run_mode else "ХОДЬБА"
    _event("move_mode", {"mode": "run" if run_mode else "walk", "speed": current_move_speed()})


func _stop() -> void:
    route.clear()
    route_index = 0
    talk_pending = false
    target_marker.hide()
    if hero_motion != null:
        LYRA.play_movement(hero_motion, false, current_move_speed())

func _physics_process(delta: float) -> void:
    if _modal_open():
        return
    var move_speed := current_move_speed()
    var travel := maxf(delta, 0) * move_speed
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
    if hero_motion != null:
        LYRA.play_movement(hero_motion, not route.is_empty(), move_speed)
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
    save_label.text = "Прогресс сохранён." if ok else progress.error_text
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
            var tap: bool = not gesture_blocked and not event.canceled and not gesture_multi and not gesture_dragged and contacts.size() == 1 and not _over_ui(event.position)
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

func _enter_pve() -> void:
    if GameState.faction_index != 0 or GameState.officer_index not in [0, 3]:
        return
    if progress.writable and not _checkpoint():
        _show_notice(progress.error_text)
        return
    _event("surface_to_pve", {"officer": GameState.officer_index})
    get_tree().change_scene_to_file("res://scenes/world_sector.tscn")


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
