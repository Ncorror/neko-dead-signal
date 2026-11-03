extends Node
## World/nav/fog alignment, distant exploration and native minimap input.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_LARGE_MAP_TEST_FAIL " + message)

func _touch(point: Vector2, pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = 3
    event.position = point
    event.pressed = pressed
    get_viewport().push_input(event, true)

func _settle() -> void:
    for frame in range(20):
        await get_tree().process_frame

func _run() -> void:
    var tree := get_tree()
    tree.current_scene = null
    GameState.set_selection(0, 0, "Люди", "Амина")
    for resolution in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        tree.root.size = resolution
        tree.change_scene_to_file("res://scenes/operation.tscn")
        await tree.scene_changed
        var op = tree.current_scene
        op.set_physics_process(false)
        op.sentry.damage = 0
        await _settle()
        _check(op.visibility.bounds == Rect2(-100, -100, 200, 200)
            and op.sight_texture.get_width() == 200 and op.navigation.world_limit == 96,
            "terrain, fog and navigation must share the large-map bounds")
        _check(op.crates.size() == 3 and op.supply_caches.size() == 6, "mission and optional supply counts")
        _check(not op.supply_caches[0].visible, "unscouted remote supplies leaked into view")
        var frame := get_viewport().get_visible_rect()
        _check(frame.encloses(op.minimap.get_global_rect()), "minimap must be visible at " + str(resolution))
        var destination := Vector3(80, 0, -80)
        var at: Vector2 = op.minimap.global_position + op.minimap.world_to_map(destination)
        _touch(at, true)
        _touch(at, false)
        _check(op.camera_focus.distance_to(destination) < 0.1 and op.unit_paths.is_empty(),
            "minimap touch must navigate the camera without a move order")
        _touch(at, true)
        var next := Vector3(-80, 0, 80)
        var drag := InputEventScreenDrag.new()
        drag.index = 3
        drag.position = op.minimap.global_position + op.minimap.world_to_map(next)
        drag.relative = drag.position - at
        get_viewport().push_input(drag, true)
        _touch(drag.position, false)
        _check(op.camera_focus.distance_to(next) < 0.1 and op.unit_paths.is_empty(),
            "minimap dragging must move only the camera")
        op._open_factory()
        await _settle()
        _check(frame.encloses(op.production_panel.get_global_rect()), "factory panel must be visible")
        _check(not op.production_panel.get_global_rect().intersects(op.minimap.get_global_rect()),
            "factory panel must not cover the minimap")
        for button in [op.production_panel.train_button, op.production_panel.cancel_button]:
            _check(frame.encloses(button.get_global_rect()), "factory action clipped")
        op.production_panel.hide()
        op.hero.position = Vector3(-58, 0, -42)
        op._update_visibility(0, true)
        _check(op.supply_caches[0].visible, "distant scout did not reveal a supply cache")
        op._check_crates()
        op._check_crates()
        _check(op.supply_caches.size() == 5 and op.crates.size() == 3
            and op.resources_collected == 100 and op.production.balance == 100,
            "optional cache must fund production once without completing a mission objective")
        op._select_unit(op.hero)
        op._issue_move(Vector3(-80, 0, -78))
        for step in range(12 * 60):
            op._physics_process(1.0 / 60.0)
            _check(op.visibility.last_step_checks <= 128, "large-map sight exceeded its ray budget")
        _check(op.hero.position.distance_to(Vector3(-80, 0, -78)) < 0.15,
            "path request beyond the previous map failed")
    if failures == 0:
        print("RTS_LARGE_MAP_TEST_PASS")
    tree.quit(0 if failures == 0 else 1)
