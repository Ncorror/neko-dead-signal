extends Node3D
## Local landing encounter. The server does not simulate these orders.

const Combatant := preload("res://scripts/combatant.gd")
enum Outcome { ACTIVE, VICTORY, DEFEAT }

const PATH_GRID := preload("res://scripts/rts_navigation.gd")
const FORMATION := preload("res://scripts/rts_formation.gd")
const DIAGNOSTICS_UI := preload("res://scripts/rts_diagnostics_ui.gd")
const RIGGED_AMINA := "res://assets/characters/amina/amina_rigged.glb"
const LYRA_MOTION := preload("res://scripts/lyra_voss_animations.gd")
const STATIC_AMINA_PREVIEW := "res://assets/characters/amina/preview.glb"
const MODEL_FIT := preload("res://scripts/rts_character_fit.gd")
const VISIBILITY := preload("res://scripts/rts_visibility.gd")
const FOG_SHADER := preload("res://shaders/ground_visibility.gdshader")
const BATTLEFIELD := preload("res://scripts/rts_battlefield.gd")
const PRODUCTION := preload("res://scripts/rts_production.gd")
const PRODUCTION_PANEL := preload("res://scripts/rts_production_panel.gd")
const MINIMAP := preload("res://scripts/rts_minimap.gd")
const ENEMY_AI := preload("res://scripts/rts_enemy_ai.gd")
const AUTO_FIRE := preload("res://scripts/rts_auto_fire.gd")
const CONSTRUCTION := preload("res://scripts/rts_construction.gd")
const BUILD_PANEL := preload("res://scripts/rts_build_panel.gd")
const ECONOMY := preload("res://scripts/rts_economy.gd")
const OBJECTIVES := preload("res://scripts/rts_objectives.gd")
const BUILDING_LABELS := preload("res://scripts/rts_building_labels.gd")
const STATIC_AMINA_WORLD_HEIGHT := 1.90
const STATIC_AMINA_FRONT_YAW_DEGREES := 0.0
const LYRA_BASE_RANGE := 16.0
const LYRA_SIGHT_RADIUS := 16.0

const MAP_LIMIT := BATTLEFIELD.PLAYABLE_LIMIT
const OFFICER_SPEED := 5.8
const ESCORT_SPEED := 4.7
const CAMERA_MIN_ZOOM := 4.0
const CAMERA_MAX_ZOOM := 37.0
const TOUCH_DRAG_THRESHOLD := 16.0
const TOUCH_PAN_MULTIPLIER := 0.0014
const MAX_GESTURE_DELTA := 45.0
const MAX_PENDING_ORDERS := 16
const CAMERA_FOCUS_RESPONSE := 10.0
const CAMERA_MINIMAP_RESPONSE := 8.5

var hero: Combatant
var escort: Combatant
var selected_unit: Combatant
var selected_units: Array[Combatant] = []
var units: Array[Combatant] = []
var sentry: Combatant
var sentry_label: Label3D
var attackers: Array[Combatant] = []
var attack_targets: Dictionary = {}
var known_enemy_positions: Dictionary = {}
var attack_last_seen: Dictionary = {}
var attack_repath_age: Dictionary = {}
var attack_lost_age: Dictionary = {}
var enemy_ai = ENEMY_AI.new()
var auto_fire = AUTO_FIRE.new()
var auto_fire_button: Button
var outcome := Outcome.ACTIVE
var objective_label: Label
var officer_button: Button
var escort_button: Button
var result_dialog: ConfirmationDialog
var result_heading: Label
var result_summary: Label
var result_button: Button
var return_dialog: ConfirmationDialog
var diagnostics_panel: Node
var production = PRODUCTION.new()
var construction = CONSTRUCTION.new()
var economy = ECONOMY.new()
var objectives = OBJECTIVES.new()
var objectives_dialog: AcceptDialog
var objectives_age := 0.0
var build_panel
var active_factory: Dictionary = {}
var build_button: Button
var factory: Node3D
var production_panel
var minimap
var reinforcement_serial := 0
var unit_paths: Dictionary = {}
var unit_waypoint_index: Dictionary = {}
var unit_move_speeds: Dictionary = {}
var unit_blocked_seconds: Dictionary = {}
var unit_headings: Dictionary = {}
var unit_pass_sides: Dictionary = {}
var unit_orders: Dictionary = {}
var append_orders := false
var queue_button: Button
var order_markers: Node3D
var enemy_order_markers: Array[Node3D] = []
var orders_ui_dirty := true
var visibility = VISIBILITY.new()
var sight_texture: ImageTexture
var sight_timer := 0.0
var world_obstacles: Array[MeshInstance3D] = []
var explored_obstacles: Array[MeshInstance3D] = []
var selection_rings: Dictionary = {}
var navigation = PATH_GRID.new()
var animation_players: Dictionary = {}
var animation_state: Dictionary = {}
var perf_accumulated: float = 0.0
var perf_max_frame_ms := 0.0
var perf_frames_over_40ms := 0
var crates: Array[Node3D] = []
var supply_caches: Array[Node3D] = []
var resources_collected: int = 0
var camera_focus: Vector3 = Vector3.ZERO
var camera_zoom: float = 22.0
var camera_render_focus: Vector3 = Vector3.ZERO
var camera_focus_velocity: Vector3 = Vector3.ZERO
var camera_render_zoom: float = 22.0
var camera_pose_initialized := false
var camera_focus_response := CAMERA_FOCUS_RESPONSE
var view_camera: Camera3D
var building_labels = BUILDING_LABELS.new()
var status_label: Label
var unit_label: Label

var touch_points: Dictionary = {}
var touch_index := -1
var pinch_distance := 0.0
var pinch_used := false
var touch_start: Vector2 = Vector2.ZERO
var touch_dragged: bool = false
var touch_tracking: bool = false
var placement_touch_active := false
var placement_had_candidate := false
var placement_previous_candidate := Vector3.ZERO

func _ready() -> void:
    navigation.configure(MAP_LIMIT, 1.0)
    _create_world()
    _create_visibility()
    _create_ui()
    economy.recalculate(self)
    _select_unit(hero)
    camera_focus = hero.global_position
    _update_camera(1.0)
    _update_status()
    _update_visibility(0.0, true)
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("app", "RTS_OPERATION_START", {
            "faction": GameState.faction_index,
            "officer": GameState.officer_index, "input": "ORDERS_ONLY", "map_size": str(BATTLEFIELD.WORLD_BOUNDS.size)
        })

func _create_world() -> void:
    var sky := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("#030c11")
    sky.environment = environment
    add_child(sky)
    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = BATTLEFIELD.WORLD_BOUNDS.size
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
        world_obstacles.append(_make_box(p, obstacle_size, Color("#4f6269")))
        navigation.set_blocked_box(p, obstacle_size, 0.75)

    for feature in BATTLEFIELD.OUTER_COVER:
        var part := _make_box(feature[0], feature[1], Color("#405b64"))
        world_obstacles.append(part)
        navigation.set_blocked_box(feature[0], feature[1], 0.75)
    _create_factory()

    for p in BATTLEFIELD.MISSION_SUPPLIES:
        var crate := _make_box(p, Vector3(1.25, 1, 1.25), Color("#e7b65b"))
        crate.name = "PrototypeSupplyCrate"
        crates.append(crate)
    for p in BATTLEFIELD.REMOTE_SUPPLIES:
        var cache := _make_box(p, Vector3(1.6, 1.1, 1.6), Color("#7ebba3"))
        cache.name = "RemoteSupplyCache"
        supply_caches.append(cache)

    sentry = Combatant.new()
    sentry.name = "SignalGuardian"
    sentry.position = BATTLEFIELD.GUARD_HOME
    sentry.weapon_range = 6.5
    sentry.damage = 12
    sentry.reload_time = 1.1
    add_child(sentry)
    var footprint := Vector3(1.2, 1.2, 1.2)
    _make_box(Vector3.ZERO, footprint, Color("#a54a47"), sentry)
    _make_box(Vector3(0, 1.2, 0), Vector3(0.65, 0.95, 0.65), Color("#ff9257"), sentry).name = "Beacon"
    _make_box(Vector3(0, 1.4, 0.6), Vector3(0.18, 0.18, 1.1), Color("#d18c68"), sentry)
    var patrol_points: Array[Vector3] = []
    patrol_points.assign(BATTLEFIELD.GUARD_PATROL)
    enemy_ai.configure(sentry.position, patrol_points)
    sentry_label = Label3D.new()
    sentry_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sentry_label.position.y = 2.8
    sentry_label.pixel_size = 0.009
    sentry.add_child(sentry_label)

    objectives.install(self)

    view_camera = Camera3D.new()
    view_camera.current = true
    view_camera.fov = 55.0
    add_child(view_camera)
    view_camera.global_position = Vector3(0, camera_zoom, camera_zoom)
    order_markers = Node3D.new()
    order_markers.name = "OrderMarkers"
    add_child(order_markers)

func _create_visibility() -> void:
    visibility.configure(BATTLEFIELD.WORLD_BOUNDS)
    sight_texture = ImageTexture.create_from_image(visibility.mask_image())
    var fog := MeshInstance3D.new()
    fog.name = "GroundFog"
    var plane := PlaneMesh.new()
    plane.size = visibility.bounds.size
    fog.mesh = plane
    fog.position.y = 0.035
    var mat := ShaderMaterial.new()
    mat.shader = FOG_SHADER
    mat.render_priority = -10
    mat.set_shader_parameter("sight_mask", sight_texture)
    mat.set_shader_parameter("map_origin", BATTLEFIELD.WORLD_BOUNDS.position)
    mat.set_shader_parameter("map_size", BATTLEFIELD.WORLD_BOUNDS.size)
    fog.material_override = mat
    fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(fog)

func _update_visibility(delta: float, force: bool = false) -> void:
    sight_timer += delta
    if force or sight_timer >= 0.15:
        var observers: Array[Vector3] = []
        var building_observers: Array[Vector3] = []
        var building_radii: Array[float] = []
        for unit in units:
            if unit.hull > 0:
                observers.append(unit.position)
                if _is_lyra_unit(unit):
                    # Long-range scout contribution without changing escort sight.
                    building_observers.append(unit.position)
                    building_radii.append(LYRA_SIGHT_RADIUS)
        if outcome == Outcome.ACTIVE and not units.is_empty():
            building_observers.append_array(construction.local_observers())
            building_radii.append_array(construction.observer_radii())
        if force:
            while visibility.scanning:
                visibility.advance(navigation, 128)
        visibility.request_snapshot(observers, force, building_observers, building_radii)
        sight_timer = 0.0
    var changed: bool = visibility.advance(navigation, 128)
    if force:
        while visibility.scanning:
            changed = visibility.advance(navigation, 128) or changed
    if not changed and not force:
        return
    _apply_visibility()

func _apply_visibility() -> void:
    sight_texture.update(visibility.mask_image())
    _apply_enemy_visibility()
    for collection in [crates, supply_caches]:
        for crate in collection:
            crate.visible = visibility.is_visible(crate.position)
    for obstacle in world_obstacles:
        if visibility.was_explored(obstacle.position) and not explored_obstacles.has(obstacle):
            explored_obstacles.append(obstacle)
        obstacle.visible = explored_obstacles.has(obstacle)
    _update_status()

func _active_enemies() -> Array[Combatant]:
    var result: Array[Combatant] = [sentry]
    result.append_array(objectives.enemies())
    return result

func _apply_enemy_visibility() -> void:
    var guardian_visible: bool = visibility.is_visible(sentry.position)
    sentry.visible = guardian_visible or (sentry.hull == 0 and visibility.was_explored(sentry.position))
    sentry_label.visible = guardian_visible
    objectives.apply_visibility(self)
    for enemy in _active_enemies():
        if visibility.is_visible(enemy.position):
            known_enemy_positions[enemy] = enemy.position


func _create_factory() -> void:
    factory = Node3D.new()
    factory.name = "FieldFactory"
    factory.position = BATTLEFIELD.FACTORY_POSITION
    add_child(factory)
    var color := Color("#426877") if GameState.faction_index == 0 else Color("#75608d")
    _make_box(Vector3.ZERO, BATTLEFIELD.FACTORY_SIZE, color, factory)
    _make_box(Vector3(0, 1.6, 0), Vector3(2.3, 0.35, 2.3), color.lightened(0.2), factory)
    _make_box(Vector3(0, 1.95, 0), Vector3(0.4, 0.7, 0.4), Color("#62ecf0"), factory)
    var label := Label3D.new()
    label.text = "ШТАБ" if GameState.faction_index == 0 else "КОМАНДНЫЙ\nУЗЕЛ"
    label.position.y = 3.0
    label.pixel_size = 0.012
    label.outline_size = 4
    label.no_depth_test = true
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.set_meta("map_anchor", label.position)
    factory.add_child(label)
    navigation.set_blocked_box(factory.position, BATTLEFIELD.FACTORY_SIZE, 0.75)
    construction.register_initial(factory, production, label)
    active_factory = construction.buildings[0]

func _reinforcement_name() -> String:
    return "СТРЕЛОК" if GameState.faction_index == 0 else "ЗОНД"

func _open_factory(entry: Dictionary = {}) -> void:
    if entry.is_empty():
        entry = construction.buildings[0]
    if not entry["ready"]:
        build_panel.inspect(entry)
        return
    active_factory = entry
    construction.cancel_preview()
    build_panel.hide()
    camera_focus_response = CAMERA_FOCUS_RESPONSE
    camera_focus = entry["node"].position
    _clamp_camera_focus()
    production_panel.show()
    production_panel.refresh()

func _factory_work():
    return production if active_factory.is_empty() else active_factory["work"]

func _open_construction() -> void:
    if outcome != Outcome.ACTIVE:
        return
    _reset_touch_state()
    production_panel.hide()
    build_panel.catalog()

func _close_construction() -> void:
    construction.cancel_preview()
    build_panel.hide()
    _reset_touch_state()

func _replan_after_building() -> void:
    for unit in unit_paths.keys():
        var old_goal: Vector3 = unit_paths[unit].back()
        var replacement: Array[Vector3] = navigation.get_path(unit.position, old_goal, _other_unit_positions(unit))
        if not replacement.is_empty() and replacement.back().distance_to(old_goal) < 0.05:
            unit_paths[unit] = replacement
            unit_waypoint_index[unit] = 0
    orders_ui_dirty = true

func _queue_reinforcement() -> bool:
    var work = _factory_work()
    var accepted: bool = outcome == Outcome.ACTIVE and work.enqueue()
    _update_status()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("production", "enqueue", {"accepted": accepted, "balance": production.balance, "pending": work.pending.size(), "factory": active_factory["id"]})
    return accepted

func _cancel_reinforcement() -> bool:
    var work = _factory_work()
    var accepted: bool = outcome == Outcome.ACTIVE and work.cancel_last()
    _update_status()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("production", "cancel", {"accepted": accepted, "balance": production.balance, "pending": work.pending.size(), "factory": active_factory["id"]})
    return accepted

func _spawn_candidates(entry: Dictionary = {}) -> Array[Vector3]:
    if entry.is_empty():
        entry = construction.buildings[0]
    var candidates: Array[Vector3] = []
    for radius in range(5):
        for x in range(-radius, radius + 1):
            for z in range(-radius, radius + 1):
                if maxi(absi(x), absi(z)) == radius:
                    candidates.append(entry["exit"] + Vector3(x, 0, z) * 1.5)
    return candidates

func _find_spawn_point(entry: Dictionary = {}) -> Variant:
    if entry.is_empty():
        entry = construction.buildings[0]
    for point in _spawn_candidates(entry):
        if not navigation.is_walkable(navigation.world_to_cell(point)):
            continue
        if not navigation.is_walkable(navigation.world_to_cell(entry["exit"])) \
            or navigation.grid.get_id_path(navigation.world_to_cell(entry["exit"]), navigation.world_to_cell(point)).is_empty():
            continue
        var free := true
        for enemy in _active_enemies():
            if enemy.hull > 0 and enemy.position.distance_to(point) < PATH_GRID.UNIT_SEPARATION:
                free = false
        for unit in units:
            if unit.position.distance_to(point) < PATH_GRID.UNIT_SEPARATION:
                free = false
                break
        if free:
            return point
    return null

func _deploy_reinforcement(entry: Dictionary = {}) -> bool:
    if entry.is_empty():
        entry = construction.buildings[0]
    var point: Variant = _find_spawn_point(entry)
    if point == null or units.is_empty() or outcome != Outcome.ACTIVE:
        return false
    reinforcement_serial += 1
    var unit := _make_unit("Reinforcement_%02d" % reinforcement_serial, point,
        Color("#91b9a8") if GameState.faction_index == 0 else Color("#bca3d5"), false)
    unit.set_meta("callsign", "%s %02d" % [_reinforcement_name(), reinforcement_serial])
    if GameState.faction_index == 1:
        for child in unit.get_children():
            if child is MeshInstance3D:
                var sphere := SphereMesh.new()
                sphere.radius = 0.5
                sphere.height = 1.0
                child.mesh = sphere
                child.position.y = 1.0
                break
    _make_box(Vector3(0, 1.1, 0.45), Vector3(0.16, 0.16, 0.65), Color("#b7eef0"), unit)
    var occupied := _other_unit_positions(unit)
    for other in units:
        if other != unit and unit_paths.has(other):
            occupied.append(unit_paths[other].back())
    var route: Array[Vector3] = navigation.get_path(unit.position, entry["rally"], occupied)
    if not route.is_empty():
        unit_paths[unit] = route
        unit_waypoint_index[unit] = 0
        unit_move_speeds[unit] = ESCORT_SPEED
    orders_ui_dirty = true
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("production", "deployed", {"unit": unit.name, "at": str(point), "units": units.size(), "factory": entry["id"]})
    return true

func _make_unit(unit_name: String, at: Vector3, color: Color, is_commander: bool) -> Combatant:
    var unit := Combatant.new()
    if not is_commander:
        unit.hull = 80
        unit.damage = 16
    elif GameState.faction_index == 0 and GameState.officer_index == 3:
        # Approved base sniper distance. Prepared Position extends this to 18
        # only when that active skill is implemented; do not grant it passively.
        unit.weapon_range = LYRA_BASE_RANGE
        unit.set_meta("neko_class", "lyra_sniper")
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
    if not is_commander and unit_name == "EscortUnit":
        var caption := Label3D.new()
        caption.name = "EscortLabel"
        caption.text = "ЭСКОРТ · ЗАГЛУШКА"
        caption.position.y = 2.2
        caption.pixel_size = 0.012
        caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        unit.add_child(caption)
    if is_commander:
        _attach_optional_rigged_amina(unit, visual)
        _attach_optional_rigged_lyra(unit, visual)
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


func _attach_optional_rigged_lyra(unit: Node3D, placeholder: MeshInstance3D) -> void:
    if GameState.faction_index != 0 or GameState.officer_index != 3:
        return
    var result: Dictionary = LYRA_MOTION.mount(unit, 1.9)
    if not bool(result.get("ok", false)):
        push_warning("RTS_LYRA_LOAD_FAILED " + str(result.get("reason", "unknown")))
        return
    placeholder.hide()
    animation_players[unit] = result["player"]
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("visual", "lyra_rig_ready", {
            "officer": 3, "clips": LYRA_MOTION.loaded_count(result["player"])
        })

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

func _is_lyra_unit(unit: Node3D) -> bool:
    return unit == hero and GameState.faction_index == 0 and GameState.officer_index == 3


func _auto_fire_allowed(unit: Node3D) -> bool:
    # Existing units keep fire-on-the-move. Lyra plants before a sniper shot.
    return not (_is_lyra_unit(unit) and unit_paths.has(unit))


func _set_unit_animation(unit: Node3D, moving: bool) -> void:
    if not animation_players.has(unit):
        return
    var player: AnimationPlayer = animation_players[unit]
    if not is_instance_valid(player):
        return
    if unit == hero and GameState.faction_index == 0 and GameState.officer_index == 3:
        animation_state[unit] = LYRA_MOTION.play_movement(player, moving,
            float(unit_move_speeds.get(unit, OFFICER_SPEED)))
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
    title.text = "NEKO: DEAD SIGNAL  /  RTS OPERATION"
    title.add_theme_font_size_override("font_size", 22)
    title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.add_child(title)

    status_label = Label.new()
    status_label.add_theme_font_size_override("font_size", 16)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.add_child(status_label)

    objective_label = Label.new()
    objective_label.add_theme_font_size_override("font_size", 17)
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.add_child(objective_label)

    var controls := HFlowContainer.new()
    controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
    controls.add_theme_constant_override("h_separation", 9)
    controls.add_theme_constant_override("v_separation", 7)
    top.add_child(controls)

    officer_button = _add_button(controls, "ОФИЦЕР", _focus_hero)
    escort_button = _add_button(controls, "ЭСКОРТ", _focus_escort)
    _add_button(controls, "ВСЕ", _select_all_units)
    _add_button(controls, "БАЗА", _open_factory)
    build_button = _add_button(controls, "СТРОЙКА", _open_construction)
    _add_button(controls, "ЦЕЛИ", _show_objectives)
    _add_button(controls, "СТОП", _stop_selected_units)
    auto_fire_button = _add_button(controls, "ОГОНЬ: АВТО", func() -> void: pass)
    auto_fire_button.toggle_mode = true
    auto_fire_button.button_pressed = true
    auto_fire_button.tooltip_text = "Режим всего отряда. Авто: ответный огонь и стрельба на ходу. Ручной: только твои приказы атаки."
    auto_fire_button.toggled.connect(_set_auto_fire)
    queue_button = _add_button(controls, "ОЧЕРЕДЬ", func() -> void: pass)
    queue_button.toggle_mode = true
    queue_button.tooltip_text = "Включи, чтобы добавлять точки и атаки после текущего приказа. СТОП отменяет всю очередь выделенных бойцов."
    queue_button.toggled.connect(_set_queue_mode)
    _add_button(controls, "−", _zoom_out)
    _add_button(controls, "+", _zoom_in)
    if RTSDiagnostics.enabled and GameState.faction_index == 0 and GameState.officer_index == 0:
        _add_button(controls, "ОСМОТР 3D", _inspect_commander)
    if RTSDiagnostics.enabled:
        diagnostics_panel = DIAGNOSTICS_UI.new()
        add_child(diagnostics_panel)
        diagnostics_panel.install(self, controls)
    result_button = _add_button(controls, "ИТОГ", _show_result)
    result_button.hide()
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
    unit_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    unit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(unit_label)
    var hint := Label.new()
    hint.text = "Касание — приказ. Свайп — камера. Два пальца — масштаб. ОЧЕРЕДЬ — точки маршрута."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hint.add_theme_font_size_override("font_size", 14)
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(hint)
    minimap = MINIMAP.new()
    root.add_child(minimap)
    minimap.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    minimap.offset_left = -205
    minimap.offset_right = -15
    minimap.offset_top = -298
    minimap.offset_bottom = -90
    minimap.install(self)
    production_panel = PRODUCTION_PANEL.new()
    root.add_child(production_panel)
    production_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    production_panel.offset_left = -602
    production_panel.offset_right = -222
    production_panel.offset_top = -402
    production_panel.offset_bottom = -90
    production_panel.install(self)
    production_panel.hide()
    build_panel = BUILD_PANEL.new()
    root.add_child(build_panel)
    build_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
    build_panel.offset_left = -602
    build_panel.offset_right = -222
    build_panel.offset_top = -402
    build_panel.offset_bottom = -90
    build_panel.install(self)
    build_panel.hide()
    _create_result_dialog()
    objectives_dialog = AcceptDialog.new()
    objectives_dialog.title = "Цели операции"
    objectives_dialog.get_ok_button().text = "ЗАКРЫТЬ"
    add_child(objectives_dialog)
    return_dialog = ConfirmationDialog.new()
    return_dialog.title = "Вернуться на корабль?"
    return_dialog.dialog_text = "Текущая операция завершится. Вернуться на корабль?"
    return_dialog.ok_button_text = "На корабль"
    return_dialog.cancel_button_text = "Остаться"
    return_dialog.confirmed.connect(_back_to_ship)
    add_child(return_dialog)

func _show_objectives() -> void:
    _reset_touch_state()
    objectives_dialog.dialog_text = objectives.details(self)
    objectives_dialog.popup_centered(Vector2i(760, 360))

func _create_result_dialog() -> void:
    result_dialog = ConfirmationDialog.new()
    result_dialog.title = "NEKO RTS · Итог операции"
    result_dialog.min_size = Vector2i(640, 300)
    result_dialog.get_ok_button().text = "НА КОРАБЛЬ"
    result_dialog.get_cancel_button().text = "КАРТА"
    for button in [result_dialog.get_ok_button(), result_dialog.get_cancel_button()]:
        button.custom_minimum_size = Vector2(150, 48)
        button.add_theme_font_size_override("font_size", 18)
    result_dialog.confirmed.connect(_back_to_ship)
    if RTSDiagnostics.enabled:
        var logs_button := result_dialog.add_button("ЛОГИ", true, "logs")
        logs_button.custom_minimum_size = Vector2(110, 48)
        result_dialog.custom_action.connect(_result_action)
    add_child(result_dialog)
    var content := VBoxContainer.new()
    content.custom_minimum_size = Vector2(580, 210)
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    content.add_theme_constant_override("separation", 18)
    result_dialog.add_child(content)
    result_heading = Label.new()
    result_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_heading.add_theme_font_size_override("font_size", 40)
    content.add_child(result_heading)
    result_summary = Label.new()
    # An embedded Window asks for minimum height before its VBox is sorted.
    # Give wrapped text a real width on that first layout pass.
    result_summary.custom_minimum_size.x = 560.0
    result_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    result_summary.add_theme_font_size_override("font_size", 20)
    content.add_child(result_summary)

func _show_result() -> void:
    if outcome == Outcome.ACTIVE or result_dialog == null:
        return
    _reset_touch_state()
    result_heading.text = _result_text()
    result_heading.add_theme_color_override("font_color", Color("#ff9c96") if outcome == Outcome.DEFEAT else Color("#62ecf0"))
    var explanation := "Весь отряд потерян. Текущий обзор закрыт." if outcome == Outcome.DEFEAT else "Все задачи операции выполнены."
    result_summary.text = "%s\nПрипасы %d/3  ·  Ресурсы %d  ·  Выпущено %d\nВернись на корабль или осмотри карту и сохрани логи." % [
        explanation, 3 - crates.size(), production.balance, _production_completed()]
    result_dialog.popup_centered(Vector2i(680, 330))

func _result_action(action: StringName) -> void:
    if action == &"logs" and diagnostics_panel != null:
        result_dialog.hide()
        diagnostics_panel._open()

func _add_button(container: Container, name: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = name
    button.custom_minimum_size = Vector2(94, 47)
    button.pressed.connect(action)
    container.add_child(button)
    return button

func _set_queue_mode(enabled: bool) -> void:
    append_orders = enabled
    queue_button.text = "ОЧЕРЕДЬ: ВКЛ" if enabled else "ОЧЕРЕДЬ"
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("units", "queue_mode", {"append": enabled})
    _update_status()

func _set_auto_fire(enabled: bool) -> void:
    auto_fire.set_enabled(enabled, self)
    auto_fire_button.set_pressed_no_signal(enabled)
    _update_status()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("combat", "auto_fire_mode", {"enabled": enabled})

func _focus_hero() -> void:
    if hero.hull > 0:
        _select_unit(hero)
        camera_focus_response = CAMERA_FOCUS_RESPONSE
        camera_focus = hero.global_position

func _inspect_commander() -> void:
    # Strategic camera zoom only. No direct-control/joystick mode.
    if hero == null or hero.hull <= 0:
        return
    _select_unit(hero)
    camera_focus_response = CAMERA_FOCUS_RESPONSE
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
        camera_focus_response = CAMERA_FOCUS_RESPONSE
        camera_focus = escort.global_position

func _select_unit(unit: Combatant) -> void:
    var just_one: Array[Combatant] = [unit]
    _select_units(just_one)

func _select_all_units() -> void:
    _select_units(units.duplicate())

func _select_units(new_selection: Array[Combatant]) -> void:
    orders_ui_dirty = true
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
        auto_fire.cancel(unit, self)
        _clear_path(unit)
        _clear_attack(unit)
        unit_orders.erase(unit)
        unit_headings.erase(unit)
    orders_ui_dirty = true
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

func _input(event: InputEvent) -> void:
    # Keep ownership of a placement gesture when the finger crosses a panel.
    # Fresh touches still go through the GUI before reaching the battlefield.
    if not placement_touch_active or event.device == InputEvent.DEVICE_ID_EMULATION:
        return
    if event is InputEventScreenTouch:
        _handle_touch(event)
    elif event is InputEventScreenDrag:
        _handle_drag(event)

func _unhandled_input(event: InputEvent) -> void:
    # UI widgets consume their input before _unhandled_input. Never react to an
    # Android emulated mouse event as if it were an independent finger gesture.
    if event.device == InputEvent.DEVICE_ID_EMULATION:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        _handle_back()
        get_viewport().set_input_as_handled()
    elif event is InputEventScreenTouch:
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
        elif mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
            _stop_camera_travel()
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
            if construction.placing != &"":
                placement_touch_active = true
                placement_had_candidate = construction.has_candidate
                placement_previous_candidate = construction.candidate
                _stop_camera_travel()
                _move_placement_preview(touch.position)
        else:
            _restore_placement_preview()
            _stop_camera_travel()
            pinch_used = true
            touch_tracking = false
            touch_dragged = false
            var points := touch_points.values()
            pinch_distance = points[0].distance_to(points[1])
    else:
        touch_points.erase(touch.index)
        if touch.canceled or pinch_used:
            if touch.canceled:
                _restore_placement_preview()
            touch_tracking = false
            touch_dragged = false
            pinch_distance = 0.0
        elif touch_tracking and touch.index == touch_index:
            touch_tracking = false
            if placement_touch_active:
                _move_placement_preview(touch.position)
            elif not touch_dragged:
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
            placement_touch_active = false
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
        if placement_touch_active:
            touch_dragged = true
            _move_placement_preview(drag.position)
            get_viewport().set_input_as_handled()
            return
        if not touch_dragged:
            if drag.position.distance_to(touch_start) < TOUCH_DRAG_THRESHOLD:
                return
            _stop_camera_travel()
            touch_dragged = true
            get_viewport().set_input_as_handled()
            return
        _pan_camera(drag.relative)
    get_viewport().set_input_as_handled()

func _move_placement_preview(at: Vector2) -> void:
    if construction.placing == &"" or not get_viewport().get_visible_rect().has_point(at):
        return
    for control in [build_panel, production_panel, minimap, build_button.get_parent()]:
        if control.visible and control.get_global_rect().has_point(at):
            return
    var point: Variant = _screen_to_ground(at)
    if point != null:
        construction.choose(point, self)
        build_panel.refresh()

func _restore_placement_preview() -> void:
    if not placement_touch_active or construction.placing == &"":
        return
    construction.has_candidate = placement_had_candidate
    construction.candidate = placement_previous_candidate
    if not placement_had_candidate:
        construction.preview.hide()
    else:
        construction.refresh_preview(self)
    build_panel.refresh()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        _reset_touch_state()
        _stop_camera_travel()
    elif what == NOTIFICATION_WM_GO_BACK_REQUEST and return_dialog != null:
        _handle_back()

func _handle_back() -> void:
    _reset_touch_state()
    _stop_camera_travel()
    if return_dialog.visible:
        return_dialog.hide()
    elif diagnostics_panel != null and diagnostics_panel.popup.visible:
        diagnostics_panel.popup.hide()
    elif objectives_dialog.visible:
        objectives_dialog.hide()
    elif result_dialog.visible:
        result_dialog.hide()
    elif build_panel.visible:
        _close_construction()
    elif production_panel.visible:
        production_panel.hide()
    else:
        return_dialog.popup_centered(Vector2i(520, 200))

func _stop_camera_travel() -> void:
    # A deliberate pan takes over from the visible location, not the distant
    # minimap destination. Release of a normal minimap tap still eases to it.
    if camera_pose_initialized:
        camera_focus = camera_render_focus
        camera_focus_velocity = Vector3.ZERO
        camera_focus_response = CAMERA_FOCUS_RESPONSE

func _reset_touch_state() -> void:
    touch_points.clear()
    touch_index = -1
    pinch_used = false
    pinch_distance = 0.0
    touch_tracking = false
    touch_dragged = false
    placement_touch_active = false

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
    if construction.placing != &"":
        var place: Variant = _screen_to_ground(screen_pos)
        if place != null:
            construction.choose(place, self)
            build_panel.refresh()
        return
    var nearest: Combatant = null
    var best := 28.0
    var candidates := units.duplicate()
    for enemy in _active_enemies():
        if enemy.hull > 0 and visibility.is_visible(enemy.position):
            candidates.append(enemy)
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
    if nearest != null and not units.has(nearest):
        _issue_attack(nearest)
    elif nearest != null:
        _select_unit(nearest)
    else:
        for entry in construction.buildings:
            if _screen_hits_building(screen_pos, entry):
                if entry["kind"] == &"factory" and entry["ready"]:
                    _open_factory(entry)
                else:
                    build_panel.inspect(entry)
                return
        if selected_unit != null:
            var point: Variant = _screen_to_ground(screen_pos)
            if point != null:
                _issue_move(point)

func _screen_hits_factory(at: Vector2) -> bool:
    return _screen_hits_building(at, construction.buildings[0])

func _screen_hits_building(at: Vector2, entry: Dictionary) -> bool:
    var location: Vector3 = entry["node"].position
    if view_camera.is_position_behind(location + Vector3.UP):
        return false
    var size: Vector3 = CONSTRUCTION.DEFINITIONS[entry["kind"]]["size"]
    var bounds := AABB(location - Vector3(size.x * 0.5, 0, size.z * 0.5), Vector3(size.x, 3.1, size.z))
    var corners := PackedVector2Array()
    for i in range(8):
        corners.append(view_camera.unproject_position(bounds.get_endpoint(i)))
    return Geometry2D.is_point_in_polygon(at, Geometry2D.convex_hull(corners))

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
        starts.append(_last_order_position(unit) if append_orders else unit.position)
        group_speed = minf(group_speed, OFFICER_SPEED if unit == hero else ESCORT_SPEED)
    for unit in units:
        if not selected_units.has(unit):
            occupied.append(unit.position)
    for enemy in _active_enemies():
        if enemy.hull > 0 and visibility.is_visible(enemy.position):
            occupied.append(enemy.position)
    var destinations: Array[Vector3] = FORMATION.destinations(navigation, starts, destination, occupied)
    var accepted := 0
    for i in range(destinations.size()):
        var unit: Combatant = ordered[i]
        if _submit_order(unit, {"type": "move", "target": destinations[i], "speed": group_speed, "group": ordered}):
            accepted += 1
    _update_status()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("units", "RTS_GROUP_ORDER", {
            "requested": n, "accepted": accepted, "target": str(destination), "append": append_orders
        })

func _last_order_position(unit: Combatant) -> Vector3:
    if auto_fire.moving.has(unit):
        return unit.position
    var pending: Array = unit_orders.get(unit, [])
    for i in range(pending.size() - 1, -1, -1):
        if pending[i]["type"] == "move":
            return pending[i]["target"]
    if unit_paths.has(unit):
        return unit_paths[unit].back()
    return unit.position

func _submit_order(unit: Combatant, order: Dictionary) -> bool:
    if append_orders and not auto_fire.moving.has(unit) and (unit_paths.has(unit) or attackers.has(unit) or unit_orders.has(unit)):
        var pending: Array = unit_orders.get(unit, [])
        if pending.size() >= MAX_PENDING_ORDERS:
            if RTSDiagnostics.enabled:
                RTSDiagnostics.event("units", "queue_full", {"unit": unit.name, "limit": MAX_PENDING_ORDERS})
            return false
        pending.append(order)
        unit_orders[unit] = pending
        orders_ui_dirty = true
        if RTSDiagnostics.enabled:
            RTSDiagnostics.event("units", "order_queued", {"unit": unit.name, "type": order["type"], "pending": pending.size()})
        return true
    if not _execute_order(unit, order):
        return false
    unit_orders.erase(unit)
    return true

func _execute_order(unit: Combatant, order: Dictionary) -> bool:
    if unit.hull <= 0 or outcome != Outcome.ACTIVE:
        return false
    var is_attack: bool = order["type"] == "attack"
    var enemy: Combatant = order.get("target_unit", sentry)
    if is_attack and (not is_instance_valid(enemy) or enemy.hull <= 0 or not visibility.is_visible(enemy.position)):
        return false
    var target: Vector3 = enemy.position if is_attack else order["target"]
    var planned: Array[Vector3] = []
    if not is_attack or not _in_firing_position(unit, enemy):
        var avoid: Array[Vector3] = []
        var moving_group: Array = order.get("group", [])
        for other in units:
            if other != unit and not moving_group.has(other):
                avoid.append(other.position)
        for foe in _active_enemies():
            if foe.hull > 0 and visibility.is_visible(foe.position):
                avoid.append(foe.position)
        planned = navigation.get_path(unit.position, target, avoid)
        if planned.is_empty():
            if RTSDiagnostics.enabled:
                RTSDiagnostics.event("path", "RTS_PATH_BLOCKED", {"unit": unit.name, "target": str(target)})
            return false
    auto_fire.cancel(unit, self)
    _clear_path(unit)
    _clear_attack(unit)
    if not planned.is_empty():
        unit_paths[unit] = planned
        unit_waypoint_index[unit] = 0
        if not is_attack:
            unit_move_speeds[unit] = order["speed"]
            if RTSDiagnostics.enabled:
                RTSDiagnostics.event("units", "RTS_MOVE_ORDER", {
                    "unit": unit.name, "target": str(planned.back()), "waypoints": planned.size(),
                    "group_speed": order["speed"]
                })
    if is_attack:
        attackers.append(unit)
        attack_targets[unit] = enemy
        attack_last_seen[unit] = enemy.position
        attack_repath_age[unit] = 0.0
        attack_lost_age[unit] = 0.0
    orders_ui_dirty = true
    return true

func _start_next_order(unit: Combatant) -> void:
    if unit_paths.has(unit) or attackers.has(unit) or not unit_orders.has(unit):
        return
    var pending: Array = unit_orders[unit]
    # Bounded by MAX_PENDING_ORDERS. A destroyed target or an unavailable
    # destination cannot hold every later command in the queue forever.
    while not pending.is_empty():
        var order: Dictionary = pending.pop_front()
        if pending.is_empty():
            unit_orders.erase(unit)
        var accepted := _execute_order(unit, order)
        orders_ui_dirty = true
        if RTSDiagnostics.enabled:
            RTSDiagnostics.event("units", "queued_order_started" if accepted else "queued_order_skipped", {
                "unit": unit.name, "type": order["type"], "pending": pending.size()
            })
        if accepted:
            return

func _clear_path(unit: Combatant) -> void:
    if unit_paths.has(unit):
        orders_ui_dirty = true
    unit_paths.erase(unit)
    unit_waypoint_index.erase(unit)
    unit_move_speeds.erase(unit)
    unit_blocked_seconds.erase(unit)
    unit_pass_sides.erase(unit)

func _issue_attack(enemy: Combatant = null) -> void:
    if enemy == null:
        enemy = sentry
    if outcome != Outcome.ACTIVE or enemy.hull <= 0 or not visibility.is_visible(enemy.position):
        return
    var accepted := 0
    for unit in selected_units:
        if _submit_order(unit, {"type": "attack", "target_unit": enemy, "last_seen": enemy.position}):
            accepted += 1
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("combat", "attack_order", {"count": accepted, "target": str(enemy.name), "append": append_orders})
    _update_status()

func _in_firing_position(shooter: Combatant, target: Combatant) -> bool:
    return shooter.position.distance_to(target.position) <= shooter.weapon_range and navigation.has_clear_shot(shooter.position, target.position)

func _clear_attack(unit: Combatant) -> void:
    attackers.erase(unit)
    attack_targets.erase(unit)
    attack_last_seen.erase(unit)
    attack_repath_age.erase(unit)
    attack_lost_age.erase(unit)

func _update_attack_order(unit: Combatant, delta: float) -> bool:
    var enemy: Combatant = attack_targets.get(unit, sentry)
    if not is_instance_valid(enemy) or enemy.hull <= 0:
        _clear_attack(unit)
        _clear_path(unit)
        return false
    var seen: bool = visibility.is_visible(enemy.position)
    if seen:
        attack_last_seen[unit] = enemy.position
        attack_lost_age[unit] = 0.0
        if _in_firing_position(unit, enemy):
            _face_direction(unit, enemy.position - unit.position)
            _clear_path(unit)
            _set_unit_animation(unit, false)
            _shoot(unit, enemy)
            return true
    else:
        attack_lost_age[unit] = attack_lost_age.get(unit, 0.0) + delta
        if attack_lost_age[unit] >= 4.0:
            _clear_attack(unit)
            _clear_path(unit)
            orders_ui_dirty = true
            return false
    var remembered: Vector3 = attack_last_seen.get(unit, unit.position)
    var age: float = attack_repath_age.get(unit, 0.0) + delta
    attack_repath_age[unit] = age
    if age >= 0.4 and (not unit_paths.has(unit) or (seen and unit_paths[unit].back().distance_to(remembered) > 1.0)):
        attack_repath_age[unit] = 0.0
        var route: Array[Vector3] = navigation.get_path(unit.position, remembered, _other_unit_positions(unit))
        if not route.is_empty():
            unit_paths[unit] = route
            unit_waypoint_index[unit] = 0
    if not seen and not unit_paths.has(unit):
        _clear_attack(unit)
        orders_ui_dirty = true
    return false

func _shoot(shooter: Combatant, target: Combatant, reason: StringName = &"order") -> void:
    var previous_hull: int = target.hull
    if not shooter.fire_at(target):
        return
    if units.has(target) and not units.has(shooter) and target.hull > 0 and target.hull < previous_hull:
        auto_fire.record_hit(target, shooter, self)
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("combat", "hit", {"from": shooter.name, "to": target.name, "health": target.hull, "reason": str(reason)})
    var origin := shooter.position + Vector3.UP
    var end := target.position + Vector3.UP
    var tracer := _make_box(Vector3.ZERO, Vector3(0.07, 0.07, origin.distance_to(end)),
        Color("#85f0ff") if units.has(shooter) else Color("#ff6c4f"))
    tracer.position = (origin + end) * 0.5
    tracer.look_at(end)
    var fade := create_tween()
    fade.tween_interval(0.12)
    fade.tween_callback(tracer.queue_free)
    if target.hull == 0:
        orders_ui_dirty = true
        if not units.has(target):
            target.get_node("Beacon").hide()
            for unit in attackers.duplicate():
                if attack_targets.get(unit, sentry) == target:
                    _clear_path(unit)
                    _clear_attack(unit)
            if target == sentry:
                enemy_ai.stop(true)
            auto_fire.enemy_destroyed(target, self)
        else:
            target.hide()
            units.erase(target)
            auto_fire.cancel(target, self)
            _clear_attack(target)
            _clear_path(target)
            unit_orders.erase(target)
            unit_headings.erase(target)
            if selected_units.has(target):
                _select_units(units.duplicate())
    _update_status()

func _other_unit_positions(unit: Combatant) -> Array[Vector3]:
    var positions: Array[Vector3] = []
    for other in units:
        if other != unit:
            positions.append(other.position)
    for enemy in _active_enemies():
        if unit != enemy and enemy.hull > 0 and visibility.is_visible(enemy.position):
            positions.append(enemy.position)
    return positions

func _can_step(unit: Combatant, destination: Vector3) -> bool:
    if not navigation.has_walkable_segment(unit.position, destination):
        return false
    for other in units:
        if other == unit:
            continue
        var closest := Geometry3D.get_closest_point_to_segment(other.position, unit.position, destination)
        if closest.distance_to(other.position) < PATH_GRID.UNIT_SEPARATION:
            return false
    for enemy in _active_enemies():
        if unit == enemy or enemy.hull <= 0:
            continue
        var closest := Geometry3D.get_closest_point_to_segment(enemy.position, unit.position, destination)
        if closest.distance_to(enemy.position) < PATH_GRID.UNIT_SEPARATION:
            return false
    return true

func _passing_step(unit: Combatant, target: Vector3, distance: float) -> Variant:
    var direction := (target - unit.position).normalized()
    var preferred: float = unit_pass_sides.get(unit, 1.0)
    # Both approaching actors first pass on the same side relative to their
    # own heading. Every candidate checks the entire swept segment.
    for side in [preferred, -preferred]:
        for angle in [PI * 0.25, PI * 0.5, PI * 0.75]:
            var candidate: Vector3 = unit.position + direction.rotated(Vector3.UP, angle * side) * distance
            if absf(candidate.x) > MAP_LIMIT or absf(candidate.z) > MAP_LIMIT:
                continue
            if _can_step(unit, candidate):
                unit_pass_sides[unit] = side
                return candidate
    return null

func _face_direction(unit: Combatant, direction: Vector3) -> void:
    if direction.length_squared() > 0.000001:
        unit_headings[unit] = atan2(direction.x, direction.z)

func _turn_unit(unit: Combatant, delta: float) -> void:
    if unit_headings.has(unit):
        unit.rotation.y = lerp_angle(unit.rotation.y, unit_headings[unit], 1.0 - exp(-delta * 10.0))

func _move_unit(unit: Combatant, delta: float) -> void:
    if not unit_paths.has(unit):
        _set_unit_animation(unit, false)
        return
    var planned: Array[Vector3] = unit_paths[unit]
    var index: int = int(unit_waypoint_index.get(unit, 0))
    for enemy in _active_enemies():
        if unit == enemy or enemy.hull <= 0 or not visibility.is_visible(enemy.position) \
            or planned.back().distance_to(enemy.position) >= PATH_GRID.UNIT_SEPARATION:
            continue
        # A hidden/moving hostile can occupy a previously accepted destination.
        # Resolve that physical obstruction once it becomes visible; allied
        # traffic still keeps the original accepted destination below.
        var requested: Vector3 = planned.back()
        var resolved: Array[Vector3] = navigation.get_path(unit.position, requested, _other_unit_positions(unit))
        if not resolved.is_empty():
            planned = resolved
            index = 0
            unit_paths[unit] = planned
            orders_ui_dirty = true
            if RTSDiagnostics.enabled:
                RTSDiagnostics.event("path", "hostile_goal_occupied", {"unit": unit.name,
                    "requested": str(requested), "resolved": str(planned.back())})
    var speed: float = unit_move_speeds.get(unit, OFFICER_SPEED if unit == hero else ESCORT_SPEED)
    var budget := speed * delta
    var moved := false
    while index < planned.size() and budget > 0.0:
        var next := unit.position.move_toward(planned[index], budget)
        if not _can_step(unit, next):
            unit_waypoint_index[unit] = index
            var passing: Variant = _passing_step(unit, planned[index], minf(budget, unit.position.distance_to(planned[index])))
            if passing != null:
                _face_direction(unit, passing - unit.position)
                unit.position = passing
            _set_unit_animation(unit, passing != null)
            var blocked: float = unit_blocked_seconds.get(unit, 0.0) + delta
            unit_blocked_seconds[unit] = blocked
            if blocked >= 0.4:
                var replacement: Array[Vector3] = navigation.get_path(unit.position, planned.back(), _other_unit_positions(unit))
                unit_blocked_seconds[unit] = 0.0
                # A passing ally can temporarily occupy the destination. Keep
                # the accepted goal instead of silently finishing elsewhere.
                var same_goal: bool = not replacement.is_empty() and replacement.back().distance_to(planned.back()) < 0.05
                if same_goal:
                    unit_paths[unit] = replacement
                    unit_waypoint_index[unit] = 0
                if RTSDiagnostics.enabled:
                    RTSDiagnostics.event("path", "ally_repath", {"unit": unit.name, "accepted": same_goal})
            return
        var travelled := unit.position.distance_to(next)
        _face_direction(unit, next - unit.position)
        unit.position = next
        budget -= travelled
        moved = moved or travelled > 0.00001
        if unit.position.distance_to(planned[index]) > 0.00001:
            break
        index += 1
    unit_blocked_seconds.erase(unit)
    unit_pass_sides.erase(unit)
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
        _start_next_order(unit)
        if attackers.has(unit):
            if not _update_attack_order(unit, delta):
                _move_unit(unit, delta)
        else:
            auto_fire.update_motion(unit, delta, self)
            _move_unit(unit, delta)
            auto_fire.try_fire(unit, self)
        _turn_unit(unit, delta)
    if sentry.hull > 0:
        sentry.tick(delta)
    enemy_ai.tick(delta, self)
    objectives.tick_defences(delta, self)
    _check_crates()
    if not units.is_empty() and not objectives.complete(self):
        construction.tick(delta, self)
        if economy.tick(delta, self):
            for building in construction.buildings:
                if building["ready"] and building["label"] != null:
                    construction._update_visual(building)
            _update_status()
        for entry in construction.buildings:
            if entry["kind"] != &"factory" or not entry["ready"] or not entry.get("powered", false):
                continue
            var work = entry["work"]
            var previously_blocked: bool = work.exit_blocked
            var delivered: int = work.tick(delta, _deploy_reinforcement.bind(entry))
            if delivered > 0:
                _update_status()
            if previously_blocked != work.exit_blocked and RTSDiagnostics.enabled:
                RTSDiagnostics.event("production", "exit_state", {"blocked": work.exit_blocked, "factory": entry["id"]})
    if objectives.tick(delta, self):
        _update_status()
    # Capture text must be committed before victory stops the next physics tick.
    # It also tracks progress/reset when the fog snapshot itself is unchanged.
    _apply_enemy_visibility()
    _update_visibility(delta)
    if units.is_empty():
        _finish(Outcome.DEFEAT)
    elif objectives.complete(self):
        _finish(Outcome.VICTORY)
    for unit in selected_units:
        if selection_rings.has(unit):
            var ring: MeshInstance3D = selection_rings[unit]
            ring.position = unit.position + Vector3(0, 0.07, 0)

func _process(delta: float) -> void:
    _update_camera(delta)
    building_labels.layout(view_camera, construction.buildings)
    if orders_ui_dirty:
        orders_ui_dirty = false
        _refresh_order_markers()
        _update_status()
    for marker in enemy_order_markers:
        var enemy: Combatant = marker.get_meta("enemy", sentry)
        if is_instance_valid(enemy) and visibility.is_visible(enemy.position):
            marker.position = enemy.position
    objectives_age += delta
    if objectives_dialog.visible and objectives_age >= 0.2:
        objectives_age = 0.0
        objectives_dialog.dialog_text = objectives.details(self)
    perf_accumulated += delta
    perf_max_frame_ms = maxf(perf_max_frame_ms, delta * 1000.0)
    if delta > 0.04:
        perf_frames_over_40ms += 1
    if perf_accumulated >= 3.0:
        perf_accumulated = 0.0
        if RTSDiagnostics.enabled:
            RTSDiagnostics.event("perf", "RTS_PERF", {
                "fps": Engine.get_frames_per_second(),
                "max_frame_ms": snappedf(perf_max_frame_ms, 0.1),
                "frames_over_40ms": perf_frames_over_40ms,
                "units": units.size(),
                "selected": selected_units.size(),
                "orders": unit_paths.size(),
                "queued_orders": _pending_order_count(),
                "sight_revision": visibility.revision,
                "sight_checks": visibility.last_step_checks,
                "resources": resources_collected,
                "balance": production.balance, "production_queue": _production_queue_count(),
                "buildings": construction.buildings.size()
            })
        perf_max_frame_ms = 0.0
        perf_frames_over_40ms = 0

func _update_camera(delta: float) -> void:
    if view_camera == null:
        return
    if not camera_pose_initialized:
        camera_render_focus = camera_focus
        camera_render_zoom = camera_zoom
        camera_pose_initialized = true
    else:
        var step := clampf(delta, 0.0, 0.10)
        # Exact critically damped step: gentle acceleration, continuous velocity
        # on retarget, and the same response at 30/60/120 FPS.
        var offset := camera_render_focus - camera_focus
        var change := camera_focus_velocity + offset * camera_focus_response
        var decay := exp(-step * camera_focus_response)
        camera_render_focus = camera_focus + (offset + change * step) * decay
        camera_focus_velocity = (camera_focus_velocity - change * (camera_focus_response * step)) * decay
        var weight := 1.0 - exp(-step * 7.0)
        camera_render_zoom = lerpf(camera_render_zoom, camera_zoom, weight)
    # Position and look target share one eased centre. Looking at the final
    # destination while position was still travelling made the view swivel.
    view_camera.global_position = camera_render_focus + Vector3(0, camera_render_zoom, camera_render_zoom * 0.95)
    view_camera.look_at(camera_render_focus + Vector3.UP, Vector3.UP)

func _check_crates() -> void:
    _collect_supplies(crates, true)
    _collect_supplies(supply_caches, false)

func _collect_supplies(collection: Array[Node3D], mission: bool) -> void:
    for i in range(collection.size() - 1, -1, -1):
        var crate := collection[i]
        var ground_pos := Vector3(crate.position.x, 0, crate.position.z)
        for unit in units:
            if unit.position.distance_to(ground_pos) < 1.55:
                collection.remove_at(i)
                crate.queue_free()
                resources_collected += 100
                production.credit(100)
                if RTSDiagnostics.enabled:
                    RTSDiagnostics.event("resource", "RTS_CRATE_COLLECTED", {"resources": resources_collected, "mission": mission, "balance": production.balance})
                _update_status()
                break

func _finish(result: Outcome) -> void:
    if outcome != Outcome.ACTIVE:
        return
    outcome = result
    economy.stop()
    var refunded: int = construction.stop(self)
    enemy_ai.stop(sentry.hull <= 0)
    auto_fire.stop(self)
    production_panel.hide()
    build_panel.hide()
    objectives_dialog.hide()
    unit_paths.clear()
    unit_waypoint_index.clear()
    unit_move_speeds.clear()
    unit_blocked_seconds.clear()
    unit_headings.clear()
    unit_pass_sides.clear()
    unit_orders.clear()
    attackers.clear()
    attack_targets.clear()
    attack_last_seen.clear()
    attack_repath_age.clear()
    attack_lost_age.clear()
    orders_ui_dirty = true
    for unit in units:
        _set_unit_animation(unit, false)
    if result == Outcome.DEFEAT:
        visibility.clear_current()
        _apply_visibility()
        var empty_selection: Array[Combatant] = []
        _select_units(empty_selection)
    _refresh_order_markers()
    result_button.show()
    _update_status()
    _show_result()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("combat", "RTS_LANDING_RESULT", {
            "outcome": Outcome.keys()[result], "resources": resources_collected, "balance": production.balance, "refunded": refunded
        })

func _result_text() -> String:
    if outcome == Outcome.VICTORY:
        return "ПОБЕДА"
    if outcome == Outcome.DEFEAT:
        return "ПОРАЖЕНИЕ"
    return "ОПЕРАЦИЯ ПРЕРВАНА"

func _update_status() -> void:
    if status_label == null or unit_label == null:
        return
    sentry_label.text = ("СТРАЖ · %d\n%s" % [sentry.hull, enemy_ai.state_text()]) if sentry.hull > 0 else "ОБЛОМКИ"
    officer_button.disabled = hero.hull == 0
    escort_button.disabled = escort.hull == 0
    auto_fire_button.text = "ОГОНЬ: АВТО" if auto_fire.enabled else "ОГОНЬ: РУЧНОЙ"
    auto_fire_button.disabled = outcome != Outcome.ACTIVE
    build_button.disabled = outcome != Outcome.ACTIVE
    status_label.text = "%s  |  Припасы %d/3  |  Ресурсы %d  |  Офицер %d ОЗ  ·  Эскорт %d ОЗ" % [
        GameState.faction_name, 3 - crates.size(), production.balance, hero.hull, escort.hull
    ]
    status_label.text += "  ·  Армия %d  ·  %s" % [units.size(), economy.summary()]
    if production_panel != null:
        production_panel.refresh()
    if outcome != Outcome.ACTIVE:
        objective_label.text = "%s  ·  НА КОРАБЛЬ для разбора операции" % _result_text()
    elif objectives.expanded:
        objective_label.text = objectives.summary(self)
    elif sentry.hull > 0 and visibility.is_visible(sentry.position):
        objective_label.text = "Цель: уничтожь оранжевого стража (%d ОЗ) и собери три золотых контейнера." % sentry.hull
    elif sentry.hull > 0:
        objective_label.text = "Разведай планету. Найди стража и три контейнера. Обзор отряда общий."
    else:
        objective_label.text = "Страж уничтожен. Доставь отряд к оставшимся контейнерам."
    if selected_units.size() > 1:
        unit_label.text = "ВЫДЕЛЕН ОТРЯД: %d" % selected_units.size()
    elif selected_unit != null:
        unit_label.text = "ВЫДЕЛЕН: %s" % (GameState.officer_name if selected_unit == hero else selected_unit.get_meta("callsign", "Эскорт"))
    else:
        unit_label.text = "НЕТ ВЫДЕЛЕННЫХ ЮНИТОВ"
    if selected_units.any(func(unit: Combatant) -> bool: return attackers.has(unit)):
        unit_label.text += "  ·  ПРИКАЗ: АТАКА"
    elif selected_units.any(func(unit: Combatant) -> bool: return auto_fire.moving.has(unit)):
        unit_label.text += "  ·  ОТВЕТНЫЙ ОГОНЬ"
    elif selected_units.any(func(unit: Combatant) -> bool: return unit_paths.has(unit)):
        unit_label.text += "  ·  ПРИКАЗ: ДВИЖЕНИЕ"
    var longest_queue := 0
    for unit in selected_units:
        var pending: Array = unit_orders.get(unit, [])
        longest_queue = maxi(longest_queue, pending.size())
    if longest_queue > 0:
        unit_label.text += "  ·  ОЧЕРЕДЬ: %d/%d" % [longest_queue, MAX_PENDING_ORDERS]

func _production_queue_count() -> int:
    var count := 0
    for entry in construction.buildings:
        if entry["work"] != null:
            count += entry["work"].pending.size()
    return count

func _production_completed() -> int:
    var count := 0
    for entry in construction.buildings:
        if entry["work"] != null:
            count += entry["work"].completed
    return count

func _pending_order_count() -> int:
    var count := 0
    for pending in unit_orders.values():
        count += pending.size()
    return count

func _refresh_order_markers() -> void:
    if order_markers == null:
        return
    enemy_order_markers.clear()
    for marker in order_markers.get_children():
        order_markers.remove_child(marker)
        marker.queue_free()
    if outcome != Outcome.ACTIVE:
        return
    for unit in selected_units:
        var number := 1
        if attackers.has(unit):
            var enemy: Combatant = attack_targets.get(unit, sentry)
            var known: Vector3 = enemy.position if visibility.is_visible(enemy.position) else attack_last_seen.get(unit, unit.position)
            _make_order_marker(known, number, Color("#ff9257"), true, enemy)
            number += 1
        elif unit_paths.has(unit):
            if auto_fire.moving.has(unit):
                var enemy: Combatant = auto_fire.memory[unit]["target"]
                var known: Vector3 = enemy.position if visibility.is_visible(enemy.position) else unit_paths[unit].back()
                _make_order_marker(known, number, Color("#ff9257"), true, enemy)
            else:
                _make_order_marker(unit_paths[unit].back(), number, Color("#62ecf0"))
            number += 1
        for order in unit_orders.get(unit, []):
            var attack: bool = order["type"] == "attack"
            var enemy: Combatant = order.get("target_unit", sentry) if attack else null
            var point: Vector3 = order.get("last_seen", unit.position) if attack else order["target"]
            if attack and is_instance_valid(enemy):
                point = enemy.position if visibility.is_visible(enemy.position) else known_enemy_positions.get(enemy, point)
            _make_order_marker(point, number, Color("#e7b65b"), attack, enemy)
            number += 1

func _make_order_marker(at: Vector3, number: int, color: Color, tracks_enemy: bool = false, enemy: Combatant = null) -> void:
    for existing in order_markers.get_children():
        if existing.get_meta("tracks_enemy", false) == tracks_enemy and existing.get_meta("enemy", sentry) == (enemy if enemy != null else sentry) and existing.position.distance_to(at) < 0.1:
            var sequence: Label3D = existing.get_node("Sequence")
            if not sequence.text.split(" · ").has(str(number)):
                sequence.text += " · " + str(number)
            return
    var marker := Node3D.new()
    marker.position = at
    marker.set_meta("tracks_enemy", tracks_enemy)
    if tracks_enemy:
        marker.set_meta("enemy", enemy if enemy != null else sentry)
        enemy_order_markers.append(marker)
    order_markers.add_child(marker)
    var ring := MeshInstance3D.new()
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.38
    mesh.outer_radius = 0.50
    mesh.rings = 12
    mesh.ring_segments = 8
    ring.mesh = mesh
    var mat := _material(color)
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring.material_override = mat
    ring.position.y = 0.06
    marker.add_child(ring)
    var label := Label3D.new()
    label.name = "Sequence"
    label.text = str(number)
    label.modulate = color
    label.font_size = 36
    label.pixel_size = 0.018
    label.outline_size = 4
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.position.y = 0.65
    marker.add_child(label)

func _back_to_ship() -> void:
    economy.stop()
    construction.stop(self)
    enemy_ai.stop(sentry.hull <= 0)
    auto_fire.stop(self)
    GameState.last_report = "%s  ·  Припасы %d/3  ·  Ресурсы %d" % [
        _result_text(), 3 - crates.size(), production.balance]
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("app", "RTS_OPERATION_END", {"collected": resources_collected})
    get_tree().change_scene_to_file("res://scenes/main.tscn")
