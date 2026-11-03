extends Node
## Real operation orders, native HUD input and the resulting combat/movement.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_QUEUE_TEST_FAIL " + message)

func _land():
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op._set_auto_fire(false) # Keep this existing scenario in explicit-order mode.
    op.sentry.damage = 0
    op.enemy_ai.movement_enabled = false # Mobile-target queues are covered in test_enemy_ai.
    for frame in range(20):
        await get_tree().process_frame
    return op

func _advance(op, frames: int) -> void:
    for frame in range(frames):
        op._physics_process(1.0 / 60.0)
        if op.units.size() == 2 and op.hero.position.distance_to(op.escort.position) < 1.099:
            _check(false, "queued movement overlapped allied actors")
            return

func _toggle(op) -> void:
    var at: Vector2 = op.queue_button.get_global_rect().get_center()
    _check(get_viewport().get_visible_rect().has_point(at), "queue toggle must be visible")
    for down in [true, false]:
        var touch := InputEventScreenTouch.new()
        touch.index = 7
        touch.position = at
        touch.pressed = down
        get_viewport().push_input(touch, true)

func _run() -> void:
    get_tree().current_scene = null
    get_tree().root.size = Vector2i(1280, 720)
    GameState.set_selection(1, 0, "Саари", "Сэйра Нэл")
    var op = await _land()
    _check(not op.append_orders and not op.queue_button.button_pressed, "queue must be opt-in")
    op.hero.position = Vector3(-8, 0, -15)
    op.escort.position = Vector3(-15, 0, -15)
    var points: Array[Vector3] = [Vector3(-8, 0, -10), Vector3(-3, 0, -10), Vector3(-3, 0, -15)]
    _toggle(op)
    _check(op.append_orders and op.unit_paths.is_empty(), "native toggle must not issue a ground order")
    for point in points:
        op._issue_move(point)
    _check(op.unit_paths[op.hero].back() == points[0] and op.unit_orders[op.hero].size() == 2,
        "queued taps must retain the active route")
    await get_tree().process_frame
    _check(op.order_markers.get_child_count() == 3, "active and queued destinations need visible markers")
    var visited := 0
    for frame in range(8 * 60):
        op._physics_process(1.0 / 60.0)
        if visited < points.size() and op.hero.position.distance_to(points[visited]) < 0.12:
            visited += 1
    _check(visited == 3 and op.unit_paths.is_empty() and op.unit_orders.is_empty(),
        "actor must visit all route points in order")

    op._issue_move(points[0])
    op._issue_move(points[1])
    _toggle(op)
    op._issue_move(Vector3(-6, 0, -15))
    _check(op.unit_orders.is_empty() and op.unit_paths[op.hero].back() == Vector3(-6, 0, -15),
        "ordinary move must replace both active and pending commands")

    op = await _land()
    _toggle(op)
    op._select_all_units()
    op._issue_move(Vector3(0, 0, -12))
    op._issue_move(Vector3(-8, 0, -12))
    _check(op.unit_orders.size() == 2, "group must keep separate queues")
    var escort_goal: Vector3 = op.unit_orders[op.escort][0]["target"]
    op._select_unit(op.hero)
    op._stop_selected_units()
    _check(not op.unit_paths.has(op.hero) and not op.unit_orders.has(op.hero)
        and op.unit_paths.has(op.escort) and op.unit_orders.has(op.escort),
        "stop must cancel only the selected actor's whole queue")
    _advance(op, 12 * 60)
    _check(op.escort.position.distance_to(escort_goal) < 0.1, "unselected ally must finish its queue")

    op = await _land()
    _toggle(op)
    op._select_all_units()
    op.hero.position = Vector3(3, 0, -3)
    op.escort.position = Vector3(1, 0, -3)
    op._update_visibility(0.0, true)
    op._issue_attack()
    op._issue_move(Vector3(-10, 0, -3))
    _check(op.attackers.size() == 2 and op.unit_orders.size() == 2,
        "queued movement must wait for the attack")
    var goal1: Vector3 = op.unit_orders[op.hero][0]["target"]
    var goal2: Vector3 = op.unit_orders[op.escort][0]["target"]
    _advance(op, 20 * 60)
    _check(op.sentry.hull == 0 and op.unit_paths.is_empty() and op.unit_orders.is_empty(),
        "destroying the target must advance both queues")
    _check(op.hero.position.distance_to(goal1) < 0.1 and op.escort.position.distance_to(goal2) < 0.1,
        "both actors must reach their later formation slots")

    op = await _land()
    _toggle(op)
    op.hero.position = Vector3(3, 0, -3)
    op._update_visibility(0.0, true)
    op._issue_move(Vector3(-6, 0, 0))
    op._issue_attack()
    op._issue_move(Vector3(-6, 0, -5))
    op.sentry.hull = 0
    _advance(op, 8 * 60)
    _check(op.hero.position.distance_to(Vector3(-6, 0, -5)) < 0.1 and op.unit_orders.is_empty(),
        "a target destroyed before its queued attack must not stall later movement")

    op = await _land()
    _toggle(op)
    op._issue_move(Vector3(-8, 0, -15))
    for i in range(op.MAX_PENDING_ORDERS + 3):
        op._issue_move(Vector3(-8 + (i % 2) * 3, 0, -12))
    _check(op.unit_orders[op.hero].size() == op.MAX_PENDING_ORDERS,
        "the bounded queue must reject excess orders without removing earlier ones")
    op.hero.hull = 1
    op.hero.position = op.sentry.position + Vector3(-2, 0, 0)
    op.sentry.damage = 12
    op._shoot(op.sentry, op.hero)
    _check(not op.unit_orders.has(op.hero), "casualty must release its pending queue")
    op._finish(op.Outcome.DEFEAT)
    _check(op.unit_orders.is_empty(), "mission end must release every queue")

    for resolution in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        get_tree().root.size = resolution
        GameState.set_selection(0, 0, "Люди", "Амина")
        op = await _land()
        _toggle(op)
        for frame in range(10):
            await get_tree().process_frame
        for button in op.find_children("*", "Button", true, false):
            if button.is_visible_in_tree():
                _check(get_viewport().get_visible_rect().encloses(button.get_global_rect()),
                    "battlefield HUD button off-screen at " + str(resolution) + ": " + button.text)
    if failures == 0:
        print("RTS_QUEUE_TEST_PASS")
    get_tree().quit(0 if failures == 0 else 1)
