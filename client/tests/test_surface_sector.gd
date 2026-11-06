extends Node
## Real collider ray picking, native controls, full landmark traversal and old-save isolation.

const TERRAIN := preload("res://scripts/surface_terrain.gd")
const OLD := preload("res://scripts/world_progress.gd")
const PATH := "user://surface-scene-regression/sector.json"
const OLD_PATH := "user://surface-scene-regression/legacy.json"
var zone
var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("SURFACE_SECTOR_TEST_FAIL " + message)

func _clean() -> void:
    for path in [PATH, OLD_PATH]:
        for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
            if FileAccess.file_exists(path + suffix):
                DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))

func _touch(at: Vector2, pressed: bool, canceled: bool = false, index: int = 0) -> void:
    var event := InputEventScreenTouch.new()
    event.position = at
    event.pressed = pressed
    event.canceled = canceled
    event.index = index
    zone.get_viewport().push_input(event, true)

func _press(button: Button) -> void:
    _check(button.is_visible_in_tree() and button.get_viewport().get_visible_rect().encloses(button.get_global_rect()),
        "button clipped: " + button.text + " " + str(button.get_global_rect()))
    for down in [true, false]:
        var event := InputEventScreenTouch.new()
        event.position = button.get_global_rect().get_center()
        event.pressed = down
        button.get_viewport().push_input(event, true)

func _settle() -> void:
    for frame in range(10):
        await get_tree().process_frame
        if is_instance_valid(zone):
            zone._process(0)

func _adopt() -> void:
    await get_tree().scene_changed
    zone = get_tree().current_scene
    zone.set_physics_process(false)
    zone.set_process(false)
    await get_tree().physics_frame
    await get_tree().physics_frame
    await _settle()

func _advance(seconds: float) -> void:
    for frame in range(ceili(seconds * 60)):
        var before: Vector3 = zone.hero.position
        zone._physics_process(1.0 / 60)
        zone._process(1.0 / 60)
        var at: Vector3 = zone.hero.position
        _check(absf(at.y - zone.world.terrain.height(at.x, at.z) - 0.04) < 0.001, "hero floated or sank into a slope")
        _check(zone.navigation.has_walkable_segment(before, at), "walking crossed a footprint or steep slope")
        _check(Vector2(at.x - before.x, at.z - before.z).length() <= 4.2 / 60 + 0.001, "walking jumped along grid cells")
        if before.distance_to(at) > 0.001 and frame % 15 == 0:
            var query := PhysicsRayQueryParameters3D.create(before + Vector3.UP, at + Vector3.UP, 2)
            _check(zone.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "walking entered an actual prop collider")

func _walk() -> void:
    var seconds := 0.0
    while not zone.route.is_empty() and seconds < 90:
        _advance(0.25)
        seconds += 0.25
    _check(zone.route.is_empty(), "surface route did not finish")

func _centre() -> Vector2:
    return Vector2(get_viewport().get_visible_rect().get_center().x,
        (zone.top_panel.get_global_rect().end.y + zone.bottom_panel.get_global_rect().position.y) * 0.5)

func _run() -> void:
    get_tree().current_scene = null
    _clean()
    GameState.world_progress_path = OLD_PATH
    GameState.surface_progress_path = PATH
    GameState.set_selection(0, 0, "Люди", "Амина")
    var old = OLD.new()
    old.open_profile(OLD_PATH, 0, 0)
    old.begin_quest()
    for i in range(3):
        old.activate(i)
    old.claim_reward()
    var legacy_bytes := FileAccess.get_file_as_string(OLD_PATH)
    for size in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        get_tree().root.size = size
        zone = null
        get_tree().change_scene_to_file("res://scenes/main.tscn")
        await get_tree().scene_changed
        await _settle()
        var menu = get_tree().current_scene
        _press(menu.surface_button)
        await _adopt()
        _check(zone.world.terrain.mesh.get_aabb().size.x == 128 and zone.visited.has(0), "ship did not enter the 128x128 first sector")
        _check(zone.bottom_panel.get_global_rect().position.y - zone.top_panel.get_global_rect().end.y > 220,
            "landscape HUD left too little playfield at " + str(size))
        _check(zone.camera.unproject_position(zone.hero.position + Vector3.UP).distance_to(_centre()) < 2,
            "hero is not centred between panels")
        for button in [zone.sites_button, zone.goal_button, zone.logs_button, zone.return_button]:
            _check(get_viewport().get_visible_rect().encloses(button.get_global_rect()), "surface control is clipped")
        # Real physics ray must hit the authored triangle, including at raised landmarks.
        for site in TERRAIN.SITES:
            var from: Vector3 = site + Vector3.UP * 40
            var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 80, 1)
            var hit: Dictionary = zone.get_world_3d().direct_space_state.intersect_ray(query)
            _check(not hit.is_empty() and absf(hit["position"].y - zone.world.terrain.height(site.x, site.z)) < 0.001,
                "terrain collider and surface height disagree at " + str(site))
        var destination: Vector3 = zone.hero.position + Vector3(3, 0, 0)
        destination = zone.world.terrain.on_ground(destination, 0)
        var pixel: Vector2 = zone.camera.unproject_position(destination)
        var picked: Variant = zone._ground(pixel)
        print("SURFACE_PICK_DEBUG size=%s hero=%s zoom=%s pixel=%s picked=%s target=%s" % [size, zone.hero.position, zone.zoom, pixel, picked, destination])
        _check(picked != null and picked.distance_to(destination) < 0.03, "touch ray does not match terrain: picked=%s target=%s size=%s" % [picked, destination, size])
        _touch(pixel, true)
        _touch(pixel, false)
        _walk()
        _check(Vector2(zone.hero.position.x - destination.x, zone.hero.position.z - destination.z).length() < 0.1,
            "native terrain tap failed: at=%s target=%s size=%s ui=%s" % [zone.hero.position, destination, size, zone._over_ui(pixel)])
        _gestures()
        _press(zone.sites_button)
        await _settle()
        _check(zone.journal.visible and zone.site_buttons.size() == 5, "site list did not open")
        _press(zone.site_buttons[1])
        await _settle()
        _check(zone.goal == 1 and not zone.following and zone.route.is_empty(), "site selection moved the hero or failed to preview")
        _press(zone.goal_button)
        _walk()
        _check(zone.visited.has(1) and zone.following, "wreck was unreachable via the native goal button")
        _press(zone.logs_button)
        await _settle()
        _check(zone.diagnostics_panel.popup.visible, "surface logs did not open")
        zone._handle_back()

    # A complete circuit over different elevations and all forked routes.
    for site in [2, 3, 4, 0]:
        _press(zone.sites_button)
        await _settle()
        _press(zone.site_buttons[site])
        await _settle()
        _press(zone.goal_button)
        _walk()
        _check(zone.visited.has(site), "landmark not discovered: " + str(site))
        _check(zone.camera.unproject_position(zone.hero.position + Vector3.UP).distance_to(_centre()) < 35,
            "camera lost the hero on an elevation change")
    _check(zone.visited.size() == 5 and not zone._move_to(Vector3(80, 0, 0)), "full circuit or map boundary failed")
    var at: Vector3 = zone.hero.position
    zone._change_zoom(1.2)
    var scale: float = zone.zoom
    zone.notification(NOTIFICATION_APPLICATION_PAUSED)
    _check(FileAccess.get_file_as_string(OLD_PATH) == legacy_bytes, "new scene wrote into the old world profile")
    _press(zone.return_button)
    await _settle()
    _press(zone.return_dialog.get_ok_button())
    await get_tree().scene_changed
    zone = null
    await _settle()
    var ship = get_tree().current_scene
    _press(ship.surface_button)
    await _adopt()
    _check(zone.hero.position.distance_to(at) < 0.001 and zone.visited.size() == 5 and zone.zoom == scale,
        "surface reentry lost position, exploration or zoom")
    _check(FileAccess.get_file_as_string(OLD_PATH) == legacy_bytes, "surface reentry changed old quest bytes")
    _clean()
    if failures == 0:
        print("SURFACE_SECTOR_TEST_PASS sizes=3 terrain_picking=physics controls=native gestures=cancel,pinch,ui elevations=grounded sites=5 old_save=byte_identical reload=ok")
    get_tree().quit(0 if failures == 0 else 1)

func _gestures() -> void:
    zone._stop()
    var centre := _centre()
    _touch(centre, true)
    _touch(centre, false, true)
    _check(zone.route.is_empty(), "canceled touch issued a move")
    _touch(centre, true)
    _touch(centre + Vector2(70, 0), true, false, 1)
    var drag := InputEventScreenDrag.new()
    drag.index = 1
    drag.position = centre + Vector2(110, 0)
    drag.relative = Vector2(40, 0)
    zone.get_viewport().push_input(drag, true)
    _touch(drag.position, false, false, 1)
    _touch(centre, false)
    _check(zone.route.is_empty(), "pinch issued a move")
    var ui_at: Vector2 = zone.save_label.get_global_rect().get_center()
    _touch(ui_at, true)
    _touch(centre, true, false, 1)
    _touch(centre, false, false, 1)
    _touch(ui_at, false)
    _check(zone.route.is_empty(), "a gesture starting on HUD leaked a world order")
    _press(zone.follow_button)
