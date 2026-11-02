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

func _run() -> void:
    var tree := get_tree()
    tree.current_scene = null
    tree.root.size = Vector2i(1280, 720)
    GameState.set_selection(1, 0, "Саари", "Сэйра Нэл")
    tree.change_scene_to_file("res://scenes/operation.tscn")
    await tree.scene_changed
    var op = tree.current_scene
    op.set_physics_process(false)
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
    if failures == 0:
        print("RTS_CAMERA_TEST_PASS")
    tree.quit(0 if failures == 0 else 1)
