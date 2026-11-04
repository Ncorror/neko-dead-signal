extends Node

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_CAMERA_TEST_FAIL " + message)

func _touch(index: int, point: Vector2, pressed: bool) -> void:
    var touch := InputEventScreenTouch.new()
    touch.index = index
    touch.position = point
    touch.pressed = pressed
    get_viewport().push_input(touch, true)

func _drag(index: int, point: Vector2, delta: Vector2) -> void:
    var drag := InputEventScreenDrag.new()
    drag.index = index
    drag.position = point
    drag.relative = delta
    get_viewport().push_input(drag, true)

func _pinch(from_x: float, to_x: float) -> void:
    _touch(5, Vector2(400, 450), true)
    _touch(9, Vector2(from_x, 450), true)
    _drag(9, Vector2(to_x, 450), Vector2(to_x - from_x, 0))
    _touch(5, Vector2(400, 450), false)
    _touch(9, Vector2(to_x, 450), false)

func _advance_camera(op, seconds: float, fps: int = 120) -> void:
    for frame in range(roundi(seconds * fps)):
        op._update_camera(1.0 / float(fps))

func _test_minimap_travel(op) -> void:
    op.set_process(false)
    op._stop_selected_units()
    op.camera_zoom = 22.0
    op.camera_focus = Vector3.ZERO
    _advance_camera(op, 2.0)
    var before: Vector3 = op.view_camera.global_position
    var forward: Vector3 = op.view_camera.global_basis.z
    var target := Vector3(70, 0, -70)
    var at: Vector2 = op.minimap.global_position + op.minimap.world_to_map(target)
    _touch(13, at, true)
    _touch(13, at, false)
    _check(op.camera_focus.distance_to(target) < 0.01 and op.unit_paths.is_empty(),
        "native minimap tap must select the camera destination without a unit order")
    _check(op.view_camera.global_position.distance_to(before) < 0.001,
        "minimap input teleported the rendered camera before its next frame")
    op._update_camera(1.0 / 120.0)
    var moved: float = op.view_camera.global_position.distance_to(before)
    _check(moved > 0.01 and moved < target.length() * 0.02,
        "first minimap frame must make a small forward step, not a jump")
    _check(op.view_camera.global_basis.z.dot(forward) > 0.9999,
        "minimap travel swivelled the camera toward the destination")
    var previous: float = op.camera_render_focus.distance_to(target)
    for frame in range(180):
        op._update_camera(1.0 / 120.0)
        var remaining: float = op.camera_render_focus.distance_to(target)
        _check(remaining <= previous + 0.0001, "camera overshot or reversed during its approach")
        _check(op.view_camera.global_basis.z.dot(forward) > 0.9999,
            "camera orientation changed during a translation")
        previous = remaining
    _check(previous < 0.01, "minimap camera did not settle at its destination")

    var positions: Array[Vector3] = []
    for fps in [30, 60, 120]:
        op.camera_focus = Vector3.ZERO
        _advance_camera(op, 2.0, fps)
        op.camera_focus = Vector3(-60, 0, 60)
        _advance_camera(op, 0.5, fps)
        positions.append(op.view_camera.global_position)
    _check(positions[0].distance_to(positions[1]) < 0.002
        and positions[1].distance_to(positions[2]) < 0.002,
        "camera response must be consistent at 30, 60 and 120 FPS")
    var remaining: float = positions[0].distance_to(Vector3(-60, 22, 80.9))
    _check(remaining > 5.0 and remaining < 8.0,
        "minimap should ease slightly slower while retaining a prompt response")

    before = op.view_camera.global_position
    op.minimap._navigate(op.minimap.world_to_map(Vector3(80, 0, -80)))
    op._update_camera(5.0)
    _check(op.view_camera.global_position.distance_to(before) < 130.0
        and op.camera_render_focus.distance_to(op.camera_focus) > 1.0,
        "one delayed frame must not teleport the camera to the far target")
    var visible: Vector3 = op.camera_render_focus
    _touch(14, Vector2(600, 350), true)
    _drag(14, Vector2(630, 350), Vector2(30, 0))
    _check(op.camera_focus.distance_to(visible) < 0.001,
        "manual pan must take over at the visible camera location")
    _drag(14, Vector2(650, 350), Vector2(20, 0))
    _touch(14, Vector2(650, 350), false)
    var manual_target: Vector3 = op.camera_focus
    _advance_camera(op, 1.0)
    _check(op.camera_focus == manual_target and op.camera_render_focus.distance_to(manual_target) < 0.01
        and op.unit_paths.is_empty(), "manual pan resumed the old flight or issued a ground order")

    _touch(15, at, true)
    op._update_camera(1.0 / 120.0)
    visible = op.camera_render_focus
    var cancel := InputEventScreenTouch.new()
    cancel.index = 15
    cancel.position = at
    cancel.canceled = true
    get_viewport().push_input(cancel, true)
    _check(op.minimap.touch_index == -1 and op.camera_focus.distance_to(visible) < 0.001,
        "canceled minimap touch must release the finger and stop its pending travel")
    _advance_camera(op, 0.5)
    _check(op.camera_render_focus.distance_to(visible) < 0.001,
        "canceled camera travel continued drifting")
    op.minimap._navigate(op.minimap.world_to_map(Vector3(-70, 0, 70)))
    op.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    _check(op.camera_focus.distance_to(op.camera_render_focus) < 0.001,
        "focus loss must stop unfinished camera travel")

func _run() -> void:
    var tree := get_tree()
    tree.current_scene = null
    tree.root.size = Vector2i(1280, 720)
    GameState.set_selection(1, 0, "Саари", "Сэйра Нэл")
    tree.change_scene_to_file("res://scenes/operation.tscn")
    await tree.scene_changed
    var op = tree.current_scene
    op.set_physics_process(false)
    op.economy.income_enabled = false # Isolate the existing fixed-budget scenario.
    op.objectives.expanded = false # Retain original landing goals in this regression.
    for frame in range(20):
        await tree.process_frame
    var original_zoom: float = op.camera_zoom
    for label in ["+", "−"]:
        var before: float = op.camera_zoom
        for button in op.find_children("*", "Button", true, false):
            if button.text == label:
                var point: Vector2 = button.get_global_rect().get_center()
                _check(get_viewport().get_visible_rect().has_point(point), "zoom button must be visible")
                _touch(0, point, true)
                _touch(0, point, false)
                break
        _check(op.camera_zoom < before if label == "+" else op.camera_zoom > before,
            "native touch must activate zoom button " + label)
    _pinch(600, 800)
    _check(is_equal_approx(op.camera_zoom, original_zoom * 0.5), "spreading fingers should zoom in")
    _check(op.unit_paths.is_empty() and op.touch_points.is_empty(), "pinch release must not issue movement")
    op.camera_zoom = 5.0
    _pinch(600, 1000)
    _check(is_equal_approx(op.camera_zoom, op.CAMERA_MIN_ZOOM), "close zoom clamp")
    op.camera_zoom = 30.0
    _pinch(600, 420)
    _check(is_equal_approx(op.camera_zoom, op.CAMERA_MAX_ZOOM), "far zoom clamp")
    _touch(2, Vector2(500, 450), true)
    _touch(3, Vector2(700, 450), true)
    op.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
    _check(op.touch_points.is_empty() and not op.pinch_used, "focus loss must clear gesture")
    op.camera_zoom = 4.0
    for frame in range(30):
        await tree.process_frame
    var destination: Vector2 = op.view_camera.unproject_position(Vector3(2, 0, 0))
    _touch(0, destination, true)
    _touch(0, destination, false)
    _check(op.unit_paths.has(op.hero), "a fresh tap after pinch must still issue an order")
    _test_minimap_travel(op)
    if failures == 0:
        print("RTS_CAMERA_TEST_PASS minimap=smooth fps=30,60,120 cancel=ok pan_override=ok")
    tree.quit(0 if failures == 0 else 1)
