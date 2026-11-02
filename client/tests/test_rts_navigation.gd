extends SceneTree
## Runtime test of Godot's actual AStarGrid2D implementation.

const NAV := preload("res://scripts/rts_navigation.gd")

func _initialize() -> void:
    call_deferred("_test_paths")

func _fail(message: String) -> void:
    push_error("RTS_NAV_TEST_FAIL: " + message)
    quit(1)

func _test_paths() -> void:
    var nav = NAV.new()
    nav.configure(24.0, 1.0)
    nav.set_blocked_box(Vector3.ZERO, Vector3(4.0, 2.0, 4.0), 0.75)

    if nav.is_walkable(Vector2i(0, 0)):
        _fail("center obstacle is walkable")
        return
    if not nav.is_walkable(Vector2i(-8, 0)):
        _fail("free cell is marked blocked")
        return

    var route: Array[Vector3] = nav.get_path(Vector3(-9, 0, 0), Vector3(9, 0, 0))
    if route.is_empty():
        _fail("obstacle route not found")
        return
    var detoured := false
    for p in route:
        var cell: Vector2i = nav.world_to_cell(p)
        if not nav.is_walkable(cell):
            _fail("path intersects solid grid cell " + str(cell))
            return
        if absf(p.z) >= 3.0:
            detoured = true
    if not detoured:
        _fail("path failed to detour around obstacle")
        return

    var clipped: Array[Vector3] = nav.get_path(Vector3(-9, 0, 0), Vector3(100, 0, 0))
    if clipped.is_empty():
        _fail("off-map destination was not clamped")
        return

    var blocked_start: Array[Vector3] = nav.get_path(Vector3.ZERO, Vector3(9, 0, 0))
    if not blocked_start.is_empty():
        _fail("path accepted a blocked starting cell")
        return

    var resolved: Array[Vector3] = nav.get_path(Vector3(-9, 0, 0), Vector3(0, 0, 0))
    if resolved.is_empty() or not nav.is_walkable(nav.world_to_cell(resolved.back())):
        _fail("blocked destination was not resolved")
        return

    var open_nav = NAV.new()
    open_nav.configure(24.0, 1.0)
    var start := Vector3(-7.7, 0, -6.2)
    var goal := Vector3(8.2, 0, 5.1)
    var direct: Array[Vector3] = open_nav.get_path(start, goal)
    if direct.size() != 1 or not direct[0].is_equal_approx(goal):
        _fail("open-ground order must be one straight segment")
        return
    # Independent geometry check against the inflated square of blocked cells.
    var obstacle := AABB(Vector3(-2.5, -0.5, -2.5), Vector3(5, 1, 5))
    var previous := Vector3(-9, 0, 0)
    for point in route:
        if obstacle.intersects_segment(previous, point) != null:
            _fail("smoothed segment cuts a blocked obstacle corner")
            return
        previous = point
    open_nav.grid.set_point_solid(Vector2i(0, -1), true)
    if open_nav.has_walkable_segment(Vector3(-1, 0, -1), Vector3(1, 0, 1)):
        _fail("diagonal corner cutting must remain blocked")
        return

    print("RTS_NAV_TEST_PASS: obstacles, detour, bounds, blocked endpoints")
    quit(0)
