extends Node
## Actual patrol, perception, cover, last-seen memory and mobile-target orders.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_ENEMY_TEST_FAIL " + message)

func _land(faction: int = 1):
    GameState.set_selection(faction, 0, "Люди" if faction == 0 else "Саари", "Амина" if faction == 0 else "Сэйра Нэл")
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    for frame in range(8):
        await get_tree().process_frame
    return op

func _away(op) -> void:
    op.hero.position = Vector3(-40, 0, 40)
    op.escort.position = Vector3(-44, 0, 40)

func _advance(op, seconds: float) -> Dictionary:
    var walked := 0.0
    var states: Dictionary = {}
    for frame in range(ceili(seconds * 60.0)):
        var before: Vector3 = op.sentry.position
        op._physics_process(1.0 / 60.0)
        var step: float = before.distance_to(op.sentry.position)
        walked += step
        states[op.enemy_ai.state] = true
        _check(step <= op.enemy_ai.MOVE_SPEED / 60.0 + 0.0001,
            "enemy movement exceeded its continuous speed")
        _check(op.navigation.has_walkable_segment(before, op.sentry.position),
            "enemy crossed an inflated static footprint")
        if op.sentry.hull > 0:
            for unit in op.units:
                if unit.position.distance_to(op.sentry.position) < 1.099:
                    _check(false, "enemy and allied unit overlapped")
                    return {"walked": walked, "states": states}
    return {"walked": walked, "states": states}

func _run() -> void:
    var started := Time.get_ticks_msec()
    get_tree().current_scene = null
    get_tree().root.size = Vector2i(1280, 720)
    var op = await _land()
    var opening := _advance(op, 18.0)
    _check(op.hero.hull == 100 and op.escort.hull == 80 and opening.walked > 40.0
        and op.enemy_ai.state == op.enemy_ai.State.PATROL,
        "patrol attacked the untouched starting squad")
    _away(op)
    var movement := _advance(op, 12.0)
    _check(movement.walked > 25.0 and op.enemy_ai.state == op.enemy_ai.State.PATROL,
        "unengaged guardian did not patrol")
    _check(op.enemy_ai.path_requests <= 22, "patrol rebuilt its path every frame")
    _check(op.navigation.is_walkable(op.navigation.world_to_cell(op.BATTLEFIELD.GUARD_HOME)),
        "mobile guardian left a permanent obstacle at its old location")

    op = await _land()
    _away(op)
    op.sentry.position = Vector3(4, 0, 7)
    op.enemy_ai.home = op.sentry.position
    op.enemy_ai.patrol.assign([Vector3(14, 0, 7)])
    op.enemy_ai.patrol_index = 0
    _advance(op, 8.0)
    _check(op.sentry.position.distance_to(Vector3(14, 0, 7)) < 0.3,
        "patrol did not route around the central cover")

    op = await _land()
    op.hero.position = Vector3(0.5, 0, -4)
    op.escort.position = Vector3(1.5, 0, 1)
    var initial: Vector3 = op.sentry.position
    _advance(op, 2.0)
    _check(op.sentry.position.distance_to(initial) > 0.5 and op.hero.hull < 100
        and op.enemy_ai.target == op.hero, "guardian failed to detect, close and fire")
    op.sentry.damage = 200
    op.sentry.cooldown = 0
    op._shoot(op.sentry, op.hero)
    _advance(op, 0.3)
    _check(op.enemy_ai.target == op.escort and op.outcome == op.Outcome.ACTIVE,
        "guardian did not switch from its dead target to the living ally")

    op = await _land()
    op.enemy_ai.movement_enabled = false
    op.sentry.position = Vector3(5.5, 0, 7)
    op.hero.position = Vector3(12.5, 0, 7)
    op.escort.position = Vector3(-40, 0, 40)
    _advance(op, 0.5)
    _check(op.enemy_ai.target == null and op.hero.hull == 100,
        "enemy detected or shot a unit through cover")
    op.hero.position = Vector3(5.5, 0, 2)
    _advance(op, 0.3)
    _check(op.enemy_ai.target == op.hero and op.hero.hull < 100,
        "enemy failed to notice a unit after it left cover")

    op = await _land()
    op.hero.position = Vector3(0.5, 0, -4)
    op.escort.position = Vector3(-40, 0, 40)
    _advance(op, 0.25)
    var remembered: Vector3 = op.enemy_ai.last_seen
    op.hero.position = Vector3(70, 0, 70)
    movement = _advance(op, 1.0)
    _check(movement.states.has(op.enemy_ai.State.SEARCH) and op.enemy_ai.target == null
        and op.enemy_ai.last_seen == remembered and op.enemy_ai.path_goal.distance_to(remembered) < 0.1,
        "lost target was followed using its hidden new coordinates")
    movement = _advance(op, 12.0)
    _check(movement.states.has(op.enemy_ai.State.RETURN) and movement.states.has(op.enemy_ai.State.PATROL),
        "guardian failed to abandon search and resume patrol")

    op = await _land()
    _away(op)
    op.sentry.position = op.enemy_ai.home + Vector3(25, 0, 0)
    op.hero.position = op.sentry.position + Vector3(3, 0, 0)
    _advance(op, 0.25)
    _check(op.enemy_ai.state == op.enemy_ai.State.RETURN and op.enemy_ai.target == null
        and op.enemy_ai.path_goal == op.enemy_ai.home, "leash did not force a return to the guard sector")
    movement = _advance(op, 10.0)
    _check(movement.states.has(op.enemy_ai.State.PATROL), "leashed guardian never resumed its patrol")

    op = await _land()
    op.escort.position = Vector3(-40, 0, 40)
    op.enemy_ai.movement_enabled = false
    op._update_visibility(0, true)
    var revision: int = op.visibility.revision
    op.sentry.position = Vector3(6, 0, 0)
    _advance(op, 1.0 / 60.0)
    _check(op.sentry.visible and op.visibility.revision == revision,
        "moving enemy failed to appear inside an unchanged sight mask")
    op.sentry.position = Vector3(30, 0, -4)
    _advance(op, 1.0 / 60.0)
    _check(not op.sentry.visible, "enemy remained rendered after leaving current sight")
    op._issue_attack()
    _check(op.attackers.is_empty(), "hidden mobile enemy accepted an attack command")

    for faction in [0, 1]:
        op = await _land(faction)
        op.enemy_ai.detection_range = 0.0
        op.sentry.damage = 0
        op.hero.position = Vector3(2, 0, -4)
        op.escort.position = Vector3(-40, 0, 40)
        op._update_visibility(0, true)
        op._select_unit(op.hero)
        op._set_queue_mode(true)
        op._issue_attack()
        op._issue_move(Vector3(-8, 0, -4))
        _advance(op, 24.0)
        _check(op.sentry.hull == 0 and op.enemy_ai.state == op.enemy_ai.State.DEAD
            and op.attackers.is_empty() and op.unit_orders.is_empty()
            and op.hero.position.distance_to(Vector3(-8, 0, -4)) < 0.15,
            "attackers failed to chase a patrol, kill it and resume their queue")
        var dead_at: Vector3 = op.sentry.position
        _advance(op, 2.0)
        _check(op.sentry.position == dead_at, "destroyed enemy continued patrolling")

    op = await _land()
    op.enemy_ai.movement_enabled = false
    op.sentry.damage = 0
    op.hero.position = Vector3(2, 0, -4)
    op.escort.position = Vector3(-40, 0, 40)
    op._update_visibility(0, true)
    op._set_queue_mode(true)
    op._issue_attack()
    op._issue_move(Vector3(-8, 0, -4))
    op.sentry.position = Vector3(70, 0, 70)
    op._update_visibility(0, true)
    op._refresh_order_markers()
    for marker in op.order_markers.get_children():
        _check(marker.position.distance_to(op.sentry.position) > 1.0,
            "attack marker revealed an enemy's hidden new position")
    _advance(op, 8.0)
    _check(op.hero.position.distance_to(Vector3(-8, 0, -4)) < 0.15
        and op.attackers.is_empty() and op.sentry.hull == 100,
        "losing an enemy in fog must release the attack queue without hidden fire")

    op = await _land()
    op.enemy_ai.movement_enabled = false
    op.sentry.damage = 0
    op.hero.position = Vector3(2, 0, -4)
    op.escort.position = Vector3(-40, 0, 40)
    op._update_visibility(0, true)
    op._set_queue_mode(true)
    op._issue_move(Vector3(-3, 0, -4))
    op._issue_attack()
    op._issue_move(Vector3(-8, 0, -4))
    op.sentry.position = Vector3(70, 0, 70)
    op._update_visibility(0, true)
    op._refresh_order_markers()
    for marker in op.order_markers.get_children():
        _check(marker.position.distance_to(op.sentry.position) > 1.0,
            "queued attack marker leaked the hidden current position")
    _advance(op, 8.0)
    _check(op.hero.position.distance_to(Vector3(-8, 0, -4)) < 0.15 and op.unit_orders.is_empty(),
        "queued attack on a now-hidden target blocked later movement")

    op = await _land()
    op.enemy_ai.movement_enabled = false
    op.sentry.damage = 0
    op.escort.position = Vector3(-40, 0, 40)
    op._update_visibility(0, true)
    _check(not op.sentry.visible, "occupied-goal scenario must begin without enemy sight")
    op._issue_move(op.sentry.position)
    _advance(op, 8.0)
    _check(op.unit_paths.is_empty() and op.hero.position.distance_to(op.sentry.position) >= 1.099
        and op.hero.position.distance_to(op.sentry.position) <= 2.0 and op.sentry.hull == 100,
        "a newly visible hostile at a move destination must resolve to a free adjacent position")

    op = await _land()
    op.enemy_ai.movement_enabled = false
    op.sentry.damage = 0
    op.sentry.position = op.BATTLEFIELD.FACTORY_EXIT
    op.production.credit(100)
    op._queue_reinforcement()
    _advance(op, 6.2)
    _check(op.units.size() == 3 and op.production.completed == 1,
        "enemy at the factory exit prevented a valid alternate deployment")

    op = await _land(0)
    op.production.credit(900)
    for batch in [4, 4, 1]:
        for i in range(batch):
            op._queue_reinforcement()
        _advance(op, batch * 6.0 + 1.0)
    _check(op.units.size() == 11, "growing-army scenario lost units before contact")
    op._select_all_units()
    op._issue_move(Vector3(10, 0, -4))
    var attacked := false
    for frame in range(6 * 60):
        _advance(op, 1.0 / 60.0)
        if not attacked and op.visibility.is_visible(op.sentry.position):
            op._issue_attack()
            attacked = true
    _advance(op, 18.0)
    _check(attacked and op.sentry.hull == 0 and not op.units.is_empty(),
        "grown army failed to find and defeat the mobile guardian")

    op = await _land()
    _away(op)
    _advance(op, 1.0)
    var final_at: Vector3 = op.sentry.position
    op._finish(op.Outcome.DEFEAT)
    _advance(op, 5.0)
    _check(op.sentry.position == final_at and not op.enemy_ai.enabled
        and op.enemy_ai.target == null, "mission end did not stop enemy movement and targeting")
    if failures == 0:
        print("RTS_ENEMY_TEST_PASS factions=2 army=11 patrol=ok cover=ok search=ok chase=ok fog=ok wall_ms=", Time.get_ticks_msec() - started)
    get_tree().quit(0 if failures == 0 else 1)
