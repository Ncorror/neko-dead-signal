extends Node3D
## Local landing encounter. The server does not simulate these orders.

const Combatant := preload("res://scripts/combatant.gd")
enum Outcome { ACTIVE, VICTORY, DEFEAT }

const PATH_GRID := preload("res://scripts/rts_navigation.gd")
const FORMATION := preload("res://scripts/rts_formation.gd")
const DIAGNOSTICS_UI := preload("res://scripts/rts_diagnostics_ui.gd")
const RIGGED_AMINA := "res://assets/characters/amina/amina_rigged.glb"
const STATIC_AMINA_PREVIEW := "res://assets/characters/amina/preview.glb"
const MODEL_FIT := preload("res://scripts/rts_character_fit.gd")
const STATIC_AMINA_WORLD_HEIGHT := 1.90
const STATIC_AMINA_FRONT_YAW_DEGREES := 0.0

const MAP_LIMIT := 24.0
const OFFICER_SPEED := 5.8
const ESCORT_SPEED := 4.7
const CAMERA_MIN_ZOOM := 4.0
const CAMERA_MAX_ZOOM := 37.0
const TOUCH_DRAG_THRESHOLD := 16.0
const TOUCH_PAN_MULTIPLIER := 0.0014
const MAX_GESTURE_DELTA := 45.0

var hero: Combatant
var escort: Combatant
var selected_unit: Combatant
var selected_units: Array[Combatant] = []
var units: Array[Combatant] = []
var sentry: Combatant
var sentry_label: Label3D
var attackers: Array[Combatant] = []
var outcome := Outcome.ACTIVE
var objective_label: Label
var officer_button: Button
var escort_button: Button
var unit_paths: Dictionary = {}
var unit_waypoint_index: Dictionary = {}
var unit_move_speeds: Dictionary = {}
var unit_blocked_seconds: Dictionary = {}
var selection_rings: Dictionary = {}
var navigation = PATH_GRID.new()
var animation_players: Dictionary = {}
var animation_state: Dictionary = {}
var perf_accumulated: float = 0.0
var crates: Array[Node3D] = []
var resources_collected: int = 0
var camera_focus: Vector3 = Vector3.ZERO
var camera_zoom: float = 22.0
var view_camera: Camera3D
var status_label: Label
var unit_label: Label

var touch_points: Dictionary = {}
var touch_index := -1
var pinch_distance := 0.0
var pinch_used := false
var touch_start: Vector2 = Vector2.ZERO
var touch_dragged: bool = false
var touch_tracking: bool = false

func _ready() -> void:
    navigation.configure(MAP_LIMIT, 1.0)
    _create_world()
    _create_ui()
    _select_unit(hero)
    camera_focus = hero.global_position
    _update_camera(1.0)
    _update_status()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("app", "RTS_OPERATION_START", {
            "faction": GameState.faction_index,
            "officer": GameState.officer_index, "input": "ORDERS_ONLY"
        })

func _create_world() -> void:
    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(50, 50)
    ground.mesh = plane
    ground.material_override = _material(Color("#283b45"))
    add_child(ground)

    var sunlight := DirectionalLight3D.new()
    sunlight.rotation_degrees = Vector3(-52, 25, 0)
    sunlight.light_energy = 1.6
    add_child(sunlight)

    hero = _make_unit("StartingOfficer", Vector3.ZERO,
        Color("#75c8f1") if GameState.faction_index == 0 else Color("#c69efa"),
        true)
    escort = _make_unit("EscortUnit", Vector3(-3.0, 0, 1.0), Color("#8ab9a0"), false)

    # Path grid excludes each obstacle footprint with clearance for the capsule.
    for p in [Vector3(-12, 0, -8), Vector3(9, 0, 7), Vector3(16, 0, -12)]:
        var obstacle_size := Vector3(3, 1.5, 3)
        _make_box(p, obstacle_size, Color("#4f6269"))
        navigation.set_blocked_box(p, obstacle_size, 0.75)

    for p in [Vector3(5, 0, 2), Vector3(-8, 0, 11), Vector3(13, 0, -6)]:
        var crate := _make_box(p, Vector3(1.25, 1, 1.25), Color("#e7b65b"))
        crate.name = "PrototypeSupplyCrate"
        crates.append(crate)

    sentry = Combatant.new()
    sentry.name = "SignalGuardian"
    sentry.position = Vector3(8, 0, -4)
    sentry.weapon_range = 6.5
    sentry.damage = 12
    sentry.reload_time = 1.1
    add_child(sentry)
    var footprint := Vector3(1.8, 1.2, 1.8)
    navigation.set_blocked_box(sentry.position, footprint, 0.6, false)
    _make_box(Vector3.ZERO, footprint, Color("#a54a47"), sentry)
    _make_box(Vector3(0, 1.2, 0), Vector3(0.65, 0.95, 0.65), Color("#ff9257"), sentry).name = "Beacon"
    sentry_label = Label3D.new()
    sentry_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sentry_label.position.y = 2.8
    sentry_label.pixel_size = 0.009
    sentry.add_child(sentry_label)

    view_camera = Camera3D.new()
    view_camera.current = true
    view_camera.fov = 55.0
    add_child(view_camera)
    view_camera.global_position = Vector3(0, camera_zoom, camera_zoom)

func _make_unit(unit_name: String, at: Vector3, color: Color, is_commander: bool) -> Combatant:
    var unit := Combatant.new()
    if not is_commander:
        unit.hull = 80
        unit.damage = 16
    unit.name = unit_name
    unit.position = at
    add_child(unit)
    var visual := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.55 if is_commander else 0.43
    capsule.height = 1.9 if is_commander else 1.65
    visual.mesh = capsule
    visual.position.y = 0.95 if is_commander else 0.825
    visual.material_override = _material(color)
    unit.add_child(visual)
    if is_commander:
        _attach_optional_rigged_amina(unit, visual)
        # A static Meshy mesh can be inspected on the battlefield, but it
        # never impersonates a rigged, animated character.
        if visual.visible:
            _attach_optional_static_amina(unit, visual)
    units.append(unit)
    return unit

func _attach_optional_rigged_amina(unit: Node3D, placeholder: MeshInstance3D) -> void:
    # Only a genuinely rigged model replaces the test capsule. The current
    # Meshy Amina has no skin/animations, so it is never treated as ready.
    if GameState.faction_index != 0 or GameState.officer_index != 0:
        return
    if not ResourceLoader.exists(RIGGED_AMINA):
        print("RTS_AMINA_MODEL_PENDING: rigged GLB not installed")
        return
    var source: Resource = load(RIGGED_AMINA)
    if not (source is PackedScene):
        push_warning("Rigged Amina resource is not a PackedScene")
        return
    var packed: PackedScene = source as PackedScene
    var visual_scene: Node = packed.instantiate()
    if not (visual_scene is Node3D):
        visual_scene.queue_free()
        push_warning("Rigged Amina root is not Node3D")
        return
    unit.add_child(visual_scene)
    var rig: Node3D = visual_scene as Node3D
    rig.position = Vector3.ZERO
    var players: Array[Node] = rig.find_children("*", "AnimationPlayer", true, false)
    if players.is_empty():
        print("RTS_AMINA_RIG_PENDING: no AnimationPlayer; keeping placeholder")
        rig.queue_free()
        return
    var player: AnimationPlayer = players[0] as AnimationPlayer
    if not _has_motion_clip(player, "idle") or not _has_motion_clip(player, "walk"):
        print("RTS_AMINA_ANIMATIONS_PENDING: Idle/Walk clips missing")
        rig.queue_free()
        return
    placeholder.hide()
    animation_players[unit] = player
    _set_unit_animation(unit, false)
    print("RTS_AMINA_RIG_READY: ", player.get_animation_list())

func _attach_optional_static_amina(unit: Node3D, placeholder: MeshInstance3D) -> void:
    # Experimental visual-only landing test. Combat, AI, HP, navigation and
    # selection stay on the original Combatant node.
    if GameState.faction_index != 0 or GameState.officer_index != 0:
        return
    if not ResourceLoader.exists(STATIC_AMINA_PREVIEW):
        return
    var imported: Resource = load(STATIC_AMINA_PREVIEW)
    if not (imported is PackedScene):
        push_warning("RTS_STATIC_AMINA_NOT_PACKED_SCENE")
        return
    var packed: PackedScene = imported as PackedScene
    var instance: Node = packed.instantiate()
    if not (instance is Node3D):
        instance.queue_free()
        push_warning("RTS_STATIC_AMINA_WRONG_ROOT")
        return
    var mount := Node3D.new()
    mount.name = "StaticCommanderPreview"
    unit.add_child(mount)
    mount.add_child(instance)
    var static_model: Node3D = instance as Node3D
    var fit: Dictionary = MODEL_FIT.fit_to_height(static_model, STATIC_AMINA_WORLD_HEIGHT)
    if not bool(fit.get("ok", false)):
        mount.queue_free()
        push_warning("RTS_STATIC_AMINA_INVALID_BOUNDS")
        return
    # The source was generated from a side portrait, so set a test yaw.
    mount.rotation.y = deg_to_rad(STATIC_AMINA_FRONT_YAW_DEGREES)
    placeholder.hide()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("visual", "static_amina_landing", {
            "height": fit["target_height"], "scale": fit["scale"],
            "note": "STATIC_NO_RIG_NO_ANIMATIONS"
        })

func _has_motion_clip(player: AnimationPlayer, keyword: String) -> bool:
    for clip in player.get_animation_list():
        if clip.to_lower().contains(keyword):
            return true
    return false

func _set_unit_animation(unit: Node3D, moving: bool) -> void:
    if not animation_players.has(unit):
        return
    var player: AnimationPlayer = animation_players[unit]
    if not is_instance_valid(player):
        return
    var state := "walk" if moving else "idle"
    if animation_state.get(unit, "") == state:
        return
    for clip in player.get_animation_list():
        if clip.to_lower().contains(state):
            player.play(clip)
            animation_state[unit] = state
            return


func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    return mat

func _make_box(at: Vector3, box_size: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = box_size
    part.mesh = mesh
    part.position = at + Vector3(0, box_size.y * 0.5, 0)
    part.material_override = _material(color)
    if parent == null:
        add_child(part)
    else:
        parent.add_child(part)
    return part

func _create_ui() -> void:
    var overlay := CanvasLayer.new()
    add_child(overlay)
    var root := Control.new()
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var top := VBoxContainer.new()
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(top)
    top.anchor_right = 1.0
    top.offset_left = 15.0
    top.offset_right = -15.0
    top.offset_top = 9.0

    var title := Label.new()
    title.text = "REINA: DEAD SIGNAL  /  RTS OPERATION"
    title.add_theme_font_size_override("font_size", 22)
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.add_child(title)

    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 16)
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.add_child(status_label)

    objective_label = Label.new()
    objective_label.add_theme_font_size_override("font_size", 17)
    objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.add_child(objective_label)

    var controls := HBoxContainer.new()
    controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    controls.add_theme_constant_override("separation", 9)
    top.add_child(controls)

    officer_button = _add_button(controls, "ОФИЦЕР", _focus_hero)
    escort_button = _add_button(controls, "ЭСКОРТ", _focus_escort)
    _add_button(controls, "ВСЕ", _select_all_units)
    _add_button(controls, "СТОП", _stop_selected_units)
    _add_button(controls, "−", _zoom_out)
    _add_button(controls, "+", _zoom_in)
    if RTSDiagnostics.enabled and GameState.faction_index == 0 and GameState.officer_index == 0:
        _add_button(controls, "ОСМОТР 3D", _inspect_commander)
    if RTSDiagnostics.enabled:
        var debug_panel := DIAGNOSTICS_UI.new()
        add_child(debug_panel)
        debug_panel.install(self, controls)
    _add_button(controls, "НА КОРАБЛЬ", _back_to_ship)

    var bottom := VBoxContainer.new()
    bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(bottom)
    bottom.anchor_top = 1.0
    bottom.anchor_bottom = 1.0
    bottom.anchor_right = 1.0
    bottom.offset_left = 15.0
    bottom.offset_right = -15.0
    bottom.offset_top = -71.0
    bottom.offset_bottom = -8.0

    unit_label = Label.new()
    unit_label.add_theme_font_size_override("font_size", 17)
    unit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(unit_label)
    var hint := Label.new()
    hint.text = "Касание — выбор/приказ. Свайп — камера. Два пальца — масштаб. СТОП — отмена."
    hint.add_theme_font_size_override("font_size", 14)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(hint)

func _add_button(container: HBoxContainer, name: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = name
    button.custom_minimum_size = Vector2(94, 47)
    button.pressed.connect(action)
    container.add_child(button)
    return button

func _focus_hero() -> void:
    if hero.hull > 0:
        _select_unit(hero)
        camera_focus = hero.global_position

func _inspect_commander() -> void:
    # Strategic camera zoom only. No direct-control/joystick mode.
    if hero == null or hero.hull <= 0:
        return
    _select_unit(hero)
    camera_focus = hero.global_position
    camera_zoom = CAMERA_MIN_ZOOM
    _clamp_camera_focus()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("camera", "inspect_static_commander", {
            "zoom": camera_zoom,
            "is_static": hero.get_node_or_null("StaticCommanderPreview") != null
        })

func _focus_escort() -> void:
    if escort.hull > 0:
        _select_unit(escort)
        camera_focus = escort.global_position

func _select_unit(unit: Combatant) -> void:
    var just_one: Array[Combatant] = [unit]
    _select_units(just_one)

func _select_all_units() -> void:
    _select_units(units.duplicate())

func _select_units(new_selection: Array[Combatant]) -> void:
    for old_ring in selection_rings.values():
        old_ring.queue_free()
    selection_rings.clear()
    selected_units.clear()
    for unit in new_selection:
        if not is_instance_valid(unit) or selected_units.has(unit):
            continue
        selected_units.append(unit)
        var indicator := MeshInstance3D.new()
        var ring := TorusMesh.new()
        ring.inner_radius = 0.72
        ring.outer_radius = 0.84
        indicator.mesh = ring
        indicator.material_override = _material(Color("#62ecf0"))
        indicator.position = unit.position + Vector3(0, 0.07, 0)
        add_child(indicator)
        selection_rings[unit] = indicator
    selected_unit = selected_units[0] if not selected_units.is_empty() else null
    _update_status()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("units", "selection", {"count": selected_units.size()})

func _stop_selected_units() -> void:
    for unit in selected_units:
        _clear_path(unit)
        attackers.erase(unit)
    _update_status()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("units", "stop", {"count": selected_units.size()})

func _zoom_in() -> void:
    camera_zoom = clampf(camera_zoom - 3.0, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
    _clamp_camera_focus()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("camera", "zoom_in", {"zoom": camera_zoom})

func _zoom_out() -> void:
    camera_zoom = clampf(camera_zoom + 3.0, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
    _clamp_camera_focus()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("camera", "zoom_out", {"zoom": camera_zoom})

func _clamp_camera_focus() -> void:
    var limit: float = maxf(3.0, MAP_LIMIT - camera_zoom * 0.45)
    camera_focus.x = clampf(camera_focus.x, -limit, limit)
    camera_focus.z = clampf(camera_focus.z, -limit, limit)

func _unhandled_input(event: InputEvent) -> void:
    # UI widgets consume their input before _unhandled_input. Never react to an
    # Android emulated mouse event as if it were an independent finger gesture.
    if event.device == InputEvent.DEVICE_ID_EMULATION:
        return
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)
    elif event is InputEventMouseButton:
        var mouse := event as InputEventMouseButton
        if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
            _handle_tap(mouse.position)
            get_viewport().set_input_as_handled()
        elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom_in()
            get_viewport().set_input_as_handled()
        elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom_out()
            get_viewport().set_input_as_handled()
    elif event is InputEventMouseMotion:
        var motion := event as InputEventMouseMotion
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            _pan_camera(motion.relative)
            get_viewport().set_input_as_handled()

func _handle_touch(touch: InputEventScreenTouch) -> void:
    if touch.canceled and RTSDiagnostics.enabled:
        RTSDiagnostics.event("input", "touch_canceled")
    if touch.pressed and not touch.canceled:
        touch_points[touch.index] = touch.position
        if touch_points.size() == 1 and not pinch_used:
            touch_index = touch.index
            touch_tracking = true
            touch_dragged = false
            touch_start = touch.position
        else:
            pinch_used = true
            touch_tracking = false
            touch_dragged = false
            var points := touch_points.values()
            pinch_distance = points[0].distance_to(points[1])
    else:
        touch_points.erase(touch.index)
        if touch.canceled or pinch_used:
            touch_tracking = false
            touch_dragged = false
            pinch_distance = 0.0
        elif touch_tracking and touch.index == touch_index:
            touch_tracking = false
            if not touch_dragged:
                if RTSDiagnostics.enabled:
                    RTSDiagnostics.event("input", "tap", {"at": str(touch.position)})
                _handle_tap(touch.position)
            elif RTSDiagnostics.enabled:
                RTSDiagnostics.event("camera", "pan_end", {"focus": str(camera_focus), "zoom": camera_zoom})
            touch_dragged = false
        if touch_points.is_empty():
            if pinch_used and RTSDiagnostics.enabled:
                RTSDiagnostics.event("camera", "pinch_end", {"zoom": camera_zoom})
            pinch_used = false
            touch_index = -1
    get_viewport().set_input_as_handled()

func _handle_drag(drag: InputEventScreenDrag) -> void:
    if not touch_points.has(drag.index):
        return
    touch_points[drag.index] = drag.position
    if touch_points.size() >= 2:
        var points := touch_points.values()
        var distance: float = points[0].distance_to(points[1])
        if pinch_distance > 8.0 and distance > 8.0:
            camera_zoom = clampf(camera_zoom * pinch_distance / distance, CAMERA_MIN_ZOOM, CAMERA_MAX_ZOOM)
            _clamp_camera_focus()
        pinch_distance = distance
    elif touch_tracking and drag.index == touch_index:
        if not touch_dragged:
            if drag.position.distance_to(touch_start) < TOUCH_DRAG_THRESHOLD:
                return
            touch_dragged = true
            get_viewport().set_input_as_handled()
            return
        _pan_camera(drag.relative)
    get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        touch_points.clear()
        touch_index = -1
        pinch_used = false
        pinch_distance = 0.0
        touch_tracking = false
        touch_dragged = false

func _pan_camera(delta_pixels: Vector2) -> void:
    # Previous camera_zoom * 0.018 shifted ~80 world units per 200 px swipe:
    # more than the entire 50-metre prototype map. Keep movement proportional
    # to zoom but clamp input spikes and the visible map centre.
    var clamped_delta: Vector2 = delta_pixels.limit_length(MAX_GESTURE_DELTA)
    var speed: float = camera_zoom * TOUCH_PAN_MULTIPLIER
    var focus_limit: float = maxf(3.0, MAP_LIMIT - camera_zoom * 0.45)
    camera_focus.x = clampf(camera_focus.x - clamped_delta.x * speed, -focus_limit, focus_limit)
    camera_focus.z = clampf(camera_focus.z - clamped_delta.y * speed, -focus_limit, focus_limit)

func _handle_tap(screen_pos: Vector2) -> void:
    if outcome != Outcome.ACTIVE:
        return
    var nearest: Combatant = null
    var best := 28.0
    var candidates := units.duplicate()
    if sentry.hull > 0:
        candidates.append(sentry)
    for actor in candidates:
        var center: Vector3 = actor.position + Vector3.UP
        if view_camera.is_position_behind(center):
            continue
        var a := view_camera.unproject_position(actor.position)
        var b := view_camera.unproject_position(center + Vector3.UP)
        var distance := screen_pos.distance_to(Geometry2D.get_closest_point_to_segment(screen_pos, a, b))
        if distance < best:
            best = distance
            nearest = actor
    if nearest == sentry:
        _issue_attack()
    elif nearest != null:
        _select_unit(nearest)
    elif selected_unit != null:
        var point: Variant = _screen_to_ground(screen_pos)
        if point != null:
            _issue_move(point)

func _screen_to_ground(screen_pos: Vector2) -> Variant:
    var origin := view_camera.project_ray_origin(screen_pos)
    var direction := view_camera.project_ray_normal(screen_pos)
    var ground_plane := Plane(Vector3.UP, 0.0)
    return ground_plane.intersects_ray(origin, direction)

func _issue_move(destination: Vector3) -> void:
    if selected_units.is_empty() or outcome != Outcome.ACTIVE:
        return
    var n := selected_units.size()
    var ordered := selected_units.duplicate()
    ordered.sort_custom(func(a: Combatant, b: Combatant) -> bool:
        return a.get_instance_id() < b.get_instance_id())
    var starts: Array[Vector3] = []
    var occupied: Array[Vector3] = []
    var group_speed := OFFICER_SPEED
    for unit in ordered:
        starts.append(unit.position)
        group_speed = minf(group_speed, OFFICER_SPEED if unit == hero else ESCORT_SPEED)
    for unit in units:
        if not selected_units.has(unit):
            occupied.append(unit.position)
    var destinations: Array[Vector3] = FORMATION.destinations(navigation, starts, destination, occupied)
    var accepted := 0
    for i in range(destinations.size()):
        var unit: Combatant = ordered[i]
        var target := destinations[i]
        var avoid := occupied
        var planned: Array[Vector3] = navigation.get_path(unit.position, target, avoid)
        if planned.is_empty():
            if RTSDiagnostics.enabled:
                RTSDiagnostics.event("path", "RTS_PATH_BLOCKED", {"unit": unit.name, "target": str(target)})
            continue
        _clear_path(unit)
        attackers.erase(unit)
        unit_paths[unit] = planned
        unit_waypoint_index[unit] = 0
        unit_move_speeds[unit] = group_speed
        accepted += 1
        if RTSDiagnostics.enabled:
            RTSDiagnostics.event("units", "RTS_MOVE_ORDER", {
                "unit": unit.name, "target": str(planned.back()), "waypoints": planned.size(),
                "group_speed": group_speed
            })
    _update_status()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("units", "RTS_GROUP_ORDER", {"requested": n, "accepted": accepted, "target": str(destination)})

func _clear_path(unit: Combatant) -> void:
    unit_paths.erase(unit)
    unit_waypoint_index.erase(unit)
    unit_move_speeds.erase(unit)
    unit_blocked_seconds.erase(unit)

func _issue_attack() -> void:
    if outcome != Outcome.ACTIVE or sentry.hull <= 0:
        return
    for unit in selected_units:
        if not _in_firing_position(unit, sentry):
            var route: Array[Vector3] = navigation.get_path(unit.position, sentry.position, _other_unit_positions(unit))
            if route.is_empty():
                continue
            _clear_path(unit)
            unit_paths[unit] = route
            unit_waypoint_index[unit] = 0
        else:
            _clear_path(unit)
        if not attackers.has(unit):
            attackers.append(unit)
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("combat", "attack_order", {"count": attackers.size(), "target": "sentry"})
    _update_status()

func _in_firing_position(shooter: Combatant, target: Combatant) -> bool:
    return shooter.position.distance_to(target.position) <= shooter.weapon_range and navigation.has_clear_shot(shooter.position, target.position)

func _shoot(shooter: Combatant, target: Combatant) -> void:
    if not shooter.fire_at(target):
        return
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("combat", "hit", {"from": shooter.name, "to": target.name, "health": target.hull})
    var origin := shooter.position + Vector3.UP
    var end := target.position + Vector3.UP
    var tracer := _make_box(Vector3.ZERO, Vector3(0.07, 0.07, origin.distance_to(end)),
        Color("#ff6c4f") if shooter == sentry else Color("#85f0ff"))
    tracer.position = (origin + end) * 0.5
    tracer.look_at(end)
    var fade := create_tween()
    fade.tween_interval(0.12)
    fade.tween_callback(tracer.queue_free)
    if target.hull == 0:
        if target == sentry:
            sentry.get_node("Beacon").hide()
            for unit in attackers:
                _clear_path(unit)
            attackers.clear()
        else:
            target.hide()
            units.erase(target)
            attackers.erase(target)
            _clear_path(target)
            if selected_units.has(target):
                _select_units(units.duplicate())
    _update_status()

func _other_unit_positions(unit: Combatant) -> Array[Vector3]:
    var positions: Array[Vector3] = []
    for other in units:
        if other != unit:
            positions.append(other.position)
    return positions

func _can_step(unit: Combatant, destination: Vector3) -> bool:
    for other in units:
        if other == unit:
            continue
        var closest := Geometry3D.get_closest_point_to_segment(other.position, unit.position, destination)
        if closest.distance_to(other.position) < PATH_GRID.UNIT_SEPARATION:
            return false
    return true

func _face_direction(unit: Combatant, direction: Vector3, delta: float) -> void:
    if direction.length_squared() > 0.000001:
        var heading := atan2(direction.x, direction.z)
        unit.rotation.y = lerp_angle(unit.rotation.y, heading, 1.0 - exp(-delta * 10.0))

func _move_unit(unit: Combatant, delta: float) -> void:
    if not unit_paths.has(unit):
        _set_unit_animation(unit, false)
        return
    var planned: Array[Vector3] = unit_paths[unit]
    var index: int = int(unit_waypoint_index.get(unit, 0))
    var speed: float = unit_move_speeds.get(unit, OFFICER_SPEED if unit == hero else ESCORT_SPEED)
    var budget := speed * delta
    var moved := false
    while index < planned.size() and budget > 0.0:
        var next := unit.position.move_toward(planned[index], budget)
        if not _can_step(unit, next):
            unit_waypoint_index[unit] = index
            _set_unit_animation(unit, false)
            var blocked: float = unit_blocked_seconds.get(unit, 0.0) + delta
            unit_blocked_seconds[unit] = blocked
            if blocked >= 0.4:
                var replacement: Array[Vector3] = navigation.get_path(unit.position, planned.back(), _other_unit_positions(unit))
                unit_blocked_seconds[unit] = 0.0
                if not replacement.is_empty():
                    unit_paths[unit] = replacement
                    unit_waypoint_index[unit] = 0
                if RTSDiagnostics.enabled:
                    RTSDiagnostics.event("path", "ally_repath", {"unit": unit.name, "accepted": not replacement.is_empty()})
            return
        var travelled := unit.position.distance_to(next)
        _face_direction(unit, next - unit.position, delta)
        unit.position = next
        budget -= travelled
        moved = moved or travelled > 0.00001
        if unit.position.distance_to(planned[index]) > 0.00001:
            break
        index += 1
    unit_blocked_seconds.erase(unit)
    _set_unit_animation(unit, moved)
    if index >= planned.size():
        _clear_path(unit)
        if RTSDiagnostics.enabled:
            RTSDiagnostics.event("units", "order_finished", {"unit": unit.name})
    else:
        unit_waypoint_index[unit] = index

func _physics_process(delta: float) -> void:
    if outcome != Outcome.ACTIVE:
        return
    for unit in units:
        unit.tick(delta)
        if attackers.has(unit) and _in_firing_position(unit, sentry):
            _face_direction(unit, sentry.position - unit.position, delta)
            _clear_path(unit)
            _set_unit_animation(unit, false)
            _shoot(unit, sentry)
            continue
        _move_unit(unit, delta)
    if sentry.hull > 0:
        sentry.tick(delta)
        var closest: Combatant = null
        for unit in units:
            if _in_firing_position(sentry, unit):
                if closest == null or unit.position.distance_squared_to(sentry.position) < closest.position.distance_squared_to(sentry.position):
                    closest = unit
        if closest != null:
            _shoot(sentry, closest)
    _check_crates()
    if units.is_empty():
        _finish(Outcome.DEFEAT)
    elif crates.is_empty() and sentry.hull == 0:
        _finish(Outcome.VICTORY)
    for unit in selected_units:
        if selection_rings.has(unit):
            var ring: MeshInstance3D = selection_rings[unit]
            ring.position = unit.position + Vector3(0, 0.07, 0)

func _process(delta: float) -> void:
    _update_camera(delta)
    perf_accumulated += delta
    if perf_accumulated >= 3.0:
        perf_accumulated = 0.0
        if RTSDiagnostics.enabled:
            RTSDiagnostics.event("perf", "RTS_PERF", {
                "fps": Engine.get_frames_per_second(),
                "units": units.size(),
                "selected": selected_units.size(),
                "orders": unit_paths.size(),
                "resources": resources_collected
            })

func _update_camera(delta: float) -> void:
    if view_camera == null:
        return
    var desired := camera_focus + Vector3(0, camera_zoom, camera_zoom * 0.95)
    view_camera.global_position = view_camera.global_position.lerp(desired, 1.0 - exp(-minf(delta, 0.10) * 7.0))
    view_camera.look_at(camera_focus + Vector3.UP, Vector3.UP)

func _check_crates() -> void:
    for i in range(crates.size() - 1, -1, -1):
        var crate := crates[i]
        var ground_pos := Vector3(crate.position.x, 0, crate.position.z)
        for unit in units:
            if unit.position.distance_to(ground_pos) < 1.55:
                crates.remove_at(i)
                crate.queue_free()
                resources_collected += 100
                if RTSDiagnostics.enabled:
                    RTSDiagnostics.event("resource", "RTS_CRATE_COLLECTED", {"resources": resources_collected})
                _update_status()
                break

func _finish(result: Outcome) -> void:
    outcome = result
    unit_paths.clear()
    unit_waypoint_index.clear()
    unit_move_speeds.clear()
    unit_blocked_seconds.clear()
    attackers.clear()
    for unit in units:
        _set_unit_animation(unit, false)
    _update_status()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("combat", "RTS_LANDING_RESULT", {
            "outcome": Outcome.keys()[result], "resources": resources_collected
        })

func _result_text() -> String:
    if outcome == Outcome.VICTORY:
        return "ПОБЕДА"
    if outcome == Outcome.DEFEAT:
        return "ОТРЯД ПОТЕРЯН"
    return "ОПЕРАЦИЯ ПРЕРВАНА"

func _update_status() -> void:
    if status_label == null or unit_label == null:
        return
    sentry_label.text = ("СТРАЖ · %d" % sentry.hull) if sentry.hull > 0 else "ОБЛОМКИ"
    officer_button.disabled = hero.hull == 0
    escort_button.disabled = escort.hull == 0
    status_label.text = "%s  |  Припасы %d/3  |  Ресурсы %d  |  Офицер %d ОЗ  ·  Эскорт %d ОЗ" % [
        GameState.faction_name, 3 - crates.size(), resources_collected, hero.hull, escort.hull
    ]
    if outcome != Outcome.ACTIVE:
        objective_label.text = "%s  ·  НА КОРАБЛЬ для разбора операции" % _result_text()
    elif sentry.hull > 0:
        objective_label.text = "Цель: уничтожь оранжевого стража (%d ОЗ) и собери три золотых контейнера." % sentry.hull
    else:
        objective_label.text = "Страж уничтожен. Доставь отряд к оставшимся контейнерам."
    if selected_units.size() > 1:
        unit_label.text = "ВЫДЕЛЕН ОТРЯД: %d" % selected_units.size()
    elif selected_unit != null:
        unit_label.text = "ВЫДЕЛЕН: %s" % (GameState.officer_name if selected_unit == hero else "Эскорт")
    else:
        unit_label.text = "НЕТ ВЫДЕЛЕННЫХ ЮНИТОВ"
    if selected_units.any(func(unit: Combatant) -> bool: return attackers.has(unit)):
        unit_label.text += "  ·  ПРИКАЗ: АТАКА"

func _back_to_ship() -> void:
    GameState.last_report = "%s  ·  Припасы %d/3  ·  Ресурсы %d" % [
        _result_text(), 3 - crates.size(), resources_collected]
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("app", "RTS_OPERATION_END", {"collected": resources_collected})
    get_tree().change_scene_to_file("res://scenes/main.tscn")
