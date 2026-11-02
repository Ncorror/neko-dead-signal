extends Node
## Movement through the actual operation scene, including new orders and casualties.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_SQUAD_TEST_FAIL " + message)

func _land():
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op.sentry.damage = 0
    return op

func _advance(op, frames: int) -> void:
    for frame in range(frames):
        op._physics_process(1.0 / 60.0)
        if op.units.size() == 2:
            if op.hero.position.distance_to(op.escort.position) < 1.099:
                _check(false, "allied actors overlapped during movement")
                return

func _run() -> void:
    get_tree().current_scene = null
    get_tree().root.size = Vector2i(1280, 720)
    GameState.set_selection(1, 0, "Саари", "Сэйра Нэл")
    var op = await _land()
    op.hero.position = Vector3(-3, 0, 0)
    op.escort.position = Vector3(3, 0, 0)
    op._select_all_units()
    op._issue_move(Vector3(0, 0, -16))
    _check(op.unit_paths.size() == 2, "group order must accept both actors")
    var hero_goal: Vector3 = op.unit_paths[op.hero].back()
    var escort_goal: Vector3 = op.unit_paths[op.escort].back()
    _check(hero_goal.x < escort_goal.x and hero_goal.distance_to(escort_goal) > 2.0,
        "assignment should retain left and right positions")
    var reverse_selection: Array[LandingCombatant] = [op.escort, op.hero]
    op._select_units(reverse_selection)
    op._issue_move(Vector3(0, 0, -16))
    _check(op.unit_paths[op.hero].back() == hero_goal and op.unit_paths[op.escort].back() == escort_goal,
        "selection order must not exchange formation slots")
    _advance(op, 8 * 60)
    _check(op.unit_paths.is_empty() and op.hero.position.distance_to(hero_goal) < 0.05,
        "open-ground formation failed to arrive")
    op._issue_move(Vector3(-12, 0, -8))
    _check(op.unit_paths.size() == 2, "resolve a group destination inside a static obstacle")
    hero_goal = op.unit_paths[op.hero].back()
    escort_goal = op.unit_paths[op.escort].back()
    _check(hero_goal.distance_to(escort_goal) >= 1.1, "blocked destination collapsed both slots")
    _advance(op, 12 * 60)
    _check(op.unit_paths.is_empty(), "group stuck on blocked destination")

    op = await _land()
    op.hero.position = Vector3(-8, 0, 0)
    op.escort.position = Vector3(-4, 0, 3)
    op._select_unit(op.hero)
    op._issue_move(Vector3(4, 0, 0))
    _advance(op, 18)
    op.escort.position = Vector3(-3, 0, 0)
    _advance(op, 10 * 60)
    _check(op.unit_paths.is_empty() and op.hero.position.distance_to(Vector3(4, 0, 0)) < 0.1,
        "actor did not reroute around a newly occupied path")
    _check(op.navigation.is_walkable(Vector2i(-3, 0)), "temporary occupancy leaked into static grid")

    op = await _land()
    op.hero.position = Vector3(-4, 0, -15)
    op.escort.position = Vector3(4, 0, -15)
    op._select_unit(op.hero)
    op._issue_move(op.escort.position)
    op._select_unit(op.escort)
    op._issue_move(Vector3(-4, 0, -15))
    _advance(op, 15 * 60)
    _check(op.unit_paths.is_empty() and op.hero.position.x > 2 and op.escort.position.x < -2,
        "opposing orders deadlocked")

    op = await _land()
    op.navigation.configure(12.0, 1.0)
    for x in [-2.0, 2.0]:
        op.navigation.set_blocked_box(Vector3(x, 0, 0), Vector3(2, 2, 20), 0.0)
    op.hero.position = Vector3(0, 0, -7)
    op.escort.position = Vector3(0, 0, -4)
    op._select_all_units()
    op._issue_move(Vector3(0, 0, 7))
    _check(op.unit_paths.size() == 2, "one-cell corridor group order was rejected")
    _advance(op, 10 * 60)
    _check(op.unit_paths.is_empty() and op.hero.position.z > 3 and op.escort.position.z > op.hero.position.z,
        "corridor movement must preserve front/back order")
    op._select_all_units()
    op._issue_move(Vector3(0, 0, -7))
    op._stop_selected_units()
    _check(op.unit_paths.is_empty() and op.unit_move_speeds.is_empty() and op.unit_blocked_seconds.is_empty(),
        "stop must clear movement bookkeeping")
    op = await _land()
    op._select_all_units()
    op._issue_move(Vector3(-10, 0, 0))
    op.escort.hull = 1
    op.escort.position = op.sentry.position + Vector3(-2, 0, 0)
    op.sentry.damage = 12
    op._shoot(op.sentry, op.escort)
    _check(not op.units.has(op.escort) and not op.unit_paths.has(op.escort)
        and not op.unit_move_speeds.has(op.escort) and not op.unit_blocked_seconds.has(op.escort),
        "casualty must release paths and movement state")
    op = await _land()
    op.hero.position = Vector3(0, 0, -12)
    op.escort.position = Vector3(-6, 0, -12)
    op._select_unit(op.hero)
    op._issue_move(Vector3(4, 0, -8))
    _advance(op, 10)
    _check(absf(angle_difference(op.hero.rotation.y, PI / 4.0)) < 0.25,
        "unit should face its diagonal movement")
    op._issue_move(Vector3(-4, 0, -8))
    _advance(op, 15)
    _check(op.hero.rotation.y < -0.3, "new direction should turn the model")
    op = await _land()
    op.hero.position = Vector3(0, 0, -12)
    op.escort.position = Vector3(-6, 0, -12)
    op._select_unit(op.hero)
    op._issue_move(Vector3(0, 0, -12.1))
    _advance(op, 45)
    _check(op.unit_paths.is_empty() and absf(angle_difference(op.hero.rotation.y, PI)) < 0.01,
        "very short movement must finish turning after arrival")
    if failures == 0:
        print("RTS_SQUAD_TEST_PASS")
    get_tree().quit(0 if failures == 0 else 1)
