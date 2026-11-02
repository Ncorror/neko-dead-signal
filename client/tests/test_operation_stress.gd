extends Node
## Repeatable multi-order routes through the live movement and shared-sight systems.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_STRESS_TEST_FAIL " + message)

func _point(op, rng: RandomNumberGenerator) -> Vector3:
    for attempt in range(100):
        var point := Vector3(rng.randf_range(-19, 19), 0, rng.randf_range(-19, 19))
        if op.navigation.is_walkable(op.navigation.world_to_cell(point)):
            return point
    return Vector3.ZERO

func _run() -> void:
    get_tree().current_scene = null
    GameState.set_selection(1, 0, "Саари", "Сэйра Нэл")
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op.sentry.damage = 0
    op.queue_button.button_pressed = true
    var rng := RandomNumberGenerator.new()
    rng.seed = 41835
    var completed := 0
    var frames_run := 0
    for sample in range(96):
        op._select_all_units()
        op._stop_selected_units()
        op.hero.position = _point(op, rng)
        op.escort.position = _point(op, rng)
        while op.hero.position.distance_to(op.escort.position) < 3.0:
            op.escort.position = _point(op, rng)
        var starts: Array[Vector3] = [op.hero.position, op.escort.position]
        op._update_visibility(0, true)
        var requested: Array[Vector3] = []
        for order in range(3):
            var target := _point(op, rng)
            requested.append(target)
            op._issue_move(target)
        if op.unit_orders.size() != 2 or op.unit_orders[op.hero].size() != 2 or op.unit_orders[op.escort].size() != 2:
            _check(false, "seeded three-point group route rejected at sample " + str(sample))
            print("RTS_STRESS_REJECT starts=", starts, " requested=", requested,
                " active=", op.unit_paths, " pending=", op.unit_orders)
            continue
        var hero_goal: Vector3 = op.unit_orders[op.hero].back()["target"]
        var escort_goal: Vector3 = op.unit_orders[op.escort].back()["target"]
        var routes: Array = [op.unit_paths.duplicate(true), op.unit_orders.duplicate(true)]
        for frame in range(60 * 60):
            frames_run += 1
            var before: Array[Vector3] = [op.hero.position, op.escort.position]
            op._physics_process(1.0 / 60.0)
            if op.hero.position.distance_to(op.escort.position) < 1.099:
                _check(false, "allied actors overlapped at sample " + str(sample))
                break
            var crossed_cover := false
            for i in range(2):
                var unit = op.units[i]
                for box in op.navigation.cover:
                    var padded := AABB(box.position - Vector3(0.5, 0, 0.5), box.size + Vector3(1, 0, 1))
                    if padded.intersects_segment(before[i] + Vector3.UP, unit.position + Vector3.UP) != null:
                        crossed_cover = true
            if crossed_cover:
                _check(false, "unit crossed physical obstacle clearance at sample " + str(sample))
                break
            _check(op.visibility.last_step_checks <= 128, "sight exceeded frame budget")
            if op.unit_paths.is_empty() and op.unit_orders.is_empty():
                break
        var arrived: bool = op.unit_paths.is_empty() and op.unit_orders.is_empty()
        arrived = arrived and op.hero.position.distance_to(hero_goal) < 0.15 and op.escort.position.distance_to(escort_goal) < 0.15
        _check(arrived, "group queue failed to finish at sample " + str(sample))
        if not arrived:
            print("RTS_STRESS_ROUTE starts=", starts, " goals=", [hero_goal, escort_goal],
                " actual=", [op.hero.position, op.escort.position], " active=", op.unit_paths,
                " pending=", op.unit_orders, " submitted=", routes)
        if arrived:
            completed += 1
    if failures == 0:
        print("RTS_STRESS_TEST_PASS routes=", completed, " group_orders=", completed * 3, " simulated_frames=", frames_run)
    get_tree().quit(0 if failures == 0 else 1)
