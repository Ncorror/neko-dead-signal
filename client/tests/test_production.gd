extends Node
## Economy, queue timing, native factory controls and live reinforcements.

const WORK := preload("res://scripts/rts_production.gd")
var failures := 0
var deployments := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_PRODUCTION_TEST_FAIL " + message)

func _deploy() -> bool:
    deployments += 1
    return true

func _settle() -> void:
    for frame in range(15):
        await get_tree().process_frame

func _land(faction: int = 0):
    GameState.set_selection(faction, 0, "Люди" if faction == 0 else "Саари", "Амина" if faction == 0 else "Сэйра Нэл")
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op.economy.income_enabled = false # Isolate the existing fixed-budget scenario.
    op.objectives.expanded = false # Retain original landing goals in this regression.
    op._set_auto_fire(false) # Keep this existing scenario in explicit-order mode.
    op.sentry.damage = 0
    op.enemy_ai.movement_enabled = false # Isolate factory timing and army routing.
    await _settle()
    return op

func _advance(op, seconds: float) -> void:
    for frame in range(ceili(seconds * 60.0)):
        op._physics_process(1.0 / 60.0)
        for i in range(op.units.size()):
            for j in range(i + 1, op.units.size()):
                if op.units[i].position.distance_to(op.units[j].position) < 1.099:
                    _check(false, "reinforcement overlapped an allied actor")
                    return

func _tap(button: Button) -> void:
    var viewport := button.get_viewport()
    var at := button.get_global_rect().get_center()
    _check(viewport.get_visible_rect().encloses(button.get_global_rect()), "factory action must be fully visible")
    for down in [true, false]:
        var touch := InputEventScreenTouch.new()
        touch.position = at
        touch.pressed = down
        viewport.push_input(touch, true)

func _run() -> void:
    var started := Time.get_ticks_msec()
    var work = WORK.new()
    _check(not work.enqueue() and work.balance == 0, "insufficient funds changed queue or balance")
    work.credit(500)
    for i in range(4):
        _check(work.enqueue(), "funded queue slot rejected")
    _check(not work.enqueue() and work.balance == 100, "full queue must not charge again")
    _check(work.cancel_last() and work.balance == 200, "last queue slot refund")
    work.tick(3.0, _deploy)
    _check(deployments == 0 and is_equal_approx(work.pending[0], 3.0), "production completed before its timer")
    work.cancel_last()
    work.cancel_last()
    _check(work.balance == 400 and work.pending.size() == 1, "cancel must preserve the active timer")
    work.tick(3.0, _deploy)
    _check(deployments == 1 and work.completed == 1 and work.pending.is_empty(), "timed completion lost or duplicated a unit")
    for i in range(3):
        work.enqueue()
    work.tick(18.0, _deploy)
    _check(deployments == 4 and work.completed == 4 and work.balance == 100, "sequential queue lost elapsed time")
    _check(work.total_earned == work.balance + work.completed * work.UNIT_COST, "economy did not conserve resources")
    work = WORK.new()
    work.credit(100)
    work.enqueue()
    work.tick(6.0, func() -> bool: return false)
    work.tick(10.0, func() -> bool: return false)
    _check(work.exit_blocked and work.pending.size() == 1 and work.balance == 0 and work.completed == 0,
        "blocked exit must retain the paid order")
    _check(work.cancel_last() and work.balance == 100 and not work.exit_blocked, "ready blocked order must refund once")
    work.enqueue()
    _check(work.stop() == 100 and work.stop() == 0 and work.balance == 100, "mission stop must be idempotent")
    _check(not work.enqueue() and work.tick(100, _deploy) == 0, "stopped production resumed")

    get_tree().current_scene = null
    get_tree().root.size = Vector2i(1280, 720)
    var op = await _land()
    _check(op.units.size() == 2 and op.hero != null and op.production.balance == 0,
        "commander must land immediately without a production cost")
    _check(not op.navigation.is_walkable(op.navigation.world_to_cell(op.factory.position)), "factory footprint must block navigation")
    op.hero.position = Vector3(5, 0, 2)
    op._check_crates()
    op._check_crates()
    _check(op.resources_collected == 100 and op.production.balance == 100 and op.crates.size() == 2,
        "shared supply pickup must fund the bank exactly once")
    for button in op.find_children("*", "Button", true, false):
        if button.text == "БАЗА":
            _tap(button)
            break
    await _settle()
    _check(op.production_panel.visible, "native base action must open factory controls")
    var selected = op.selected_unit
    _tap(op.production_panel.train_button)
    _check(op.production.balance == 0 and op.production.pending.size() == 1
        and op.units.size() == 2 and op.unit_paths.is_empty(), "training touch must pay once without a ground order")
    _advance(op, 6.1)
    _check(op.units.size() == 3 and op.production.completed == 1 and op.production.pending.is_empty(), "paid unit did not deploy")
    _check(op.selected_unit == selected and op.hero.hull > 0, "deployment must not replace the commander or selection")
    var reinforcement = op.units.back()
    _advance(op, 3.0)
    _check(not op.unit_paths.has(reinforcement), "reinforcement did not reach its rally point")
    op._select_unit(reinforcement)
    op._issue_move(Vector3(-28, 0, -26))
    _advance(op, 18.0)
    _check(reinforcement.position.distance_to(Vector3(-28, 0, -26)) < 0.15, "produced unit cannot follow a map order")
    reinforcement.position = Vector3(4, 0, -4)
    op._update_visibility(0, true)
    op._issue_attack()
    _advance(op, 10.0)
    _check(op.sentry.hull == 0, "produced unit cannot attack")

    op = await _land(1)
    op.production.credit(100)
    op._queue_reinforcement()
    var blocked: Array[Vector2i] = []
    for point in op._spawn_candidates():
        var cell: Vector2i = op.navigation.world_to_cell(point)
        if op.navigation.is_walkable(cell):
            op.navigation.grid.set_point_solid(cell, true)
            blocked.append(cell)
    _advance(op, 7.0)
    _check(op.production.exit_blocked and op.production.pending.size() == 1
        and op.units.size() == 2 and op.production.balance == 0, "crowded factory lost its finished unit")
    for cell in blocked:
        op.navigation.grid.set_point_solid(cell, false)
    _advance(op, 0.2)
    _check(op.production.completed == 1 and op.units.size() == 3 and op._reinforcement_name() == "ЗОНД",
        "opening the Saari exit must release exactly one unit")
    _advance(op, 2.0)
    _check(op.units.size() == 3, "completed order deployed twice")

    op = await _land()
    op.production.credit(900)
    for batch in [4, 4, 1]:
        for i in range(batch):
            _check(op._queue_reinforcement(), "army production rejected a funded request")
        _advance(op, float(batch) * op.production.BUILD_SECONDS + 1.0)
    _check(op.units.size() == 11 and op.production.completed == 9, "full resource budget must support nine reinforcements")
    for destination in [Vector3(-30, 0, -28), Vector3(32, 0, 24), Vector3(-28, 0, 32), Vector3(5, 0, -40)]:
        op._select_all_units()
        op._issue_move(destination)
        _check(op.unit_paths.size() == 11, "larger formation rejected a member")
        var targets: Dictionary = {}
        for unit in op.units:
            if op.unit_paths.has(unit):
                targets[unit] = op.unit_paths[unit].back()
        _advance(op, 35.0)
        _check(op.unit_paths.is_empty(), "larger army remained stuck on its route to " + str(destination))
        if not op.unit_paths.is_empty():
            var occupied: Array = []
            for actor in op.units:
                occupied.append({"unit": actor.name, "position": actor.position, "goal": targets.get(actor), "active": op.unit_paths.has(actor)})
            print("RTS_ARMY_STUCK target=", destination, " actors=", occupied, " paths=", op.unit_paths)
        for unit in targets:
            _check(unit.position.distance_to(targets[unit]) < 0.15, "larger formation changed its accepted endpoint")

    # A surviving reinforcement keeps the mission alive after both initial actors die.
    op = await _land()
    op.production.credit(200)
    op._queue_reinforcement()
    op._queue_reinforcement()
    _advance(op, 6.1)
    op.sentry.damage = 200
    op.sentry.reload_time = 0
    for initial in [op.hero, op.escort]:
        initial.position = Vector3(5, 0, -4)
        op._shoot(op.sentry, initial)
    _advance(op, 0.1)
    _check(op.outcome == op.Outcome.ACTIVE and op.units.size() == 1,
        "loss of the initial pair must not defeat a surviving reinforcement")
    op.units[0].position = Vector3(5, 0, -4)
    op._shoot(op.sentry, op.units[0])
    _advance(op, 0.1)
    _check(op.outcome == op.Outcome.DEFEAT and op.production.balance == 100
        and op.production.completed == 1 and op.production.pending.is_empty(),
        "last reinforcement must trigger defeat and refund the pending order")

    # Finishing the real mission must refund a partly built unit before the result.
    op = await _land()
    op.production.credit(200)
    op._queue_reinforcement()
    op._queue_reinforcement()
    _advance(op, 6.1)
    op.sentry.hull = 0
    for at in [Vector3(5, 0, 2), Vector3(-8, 0, 11), Vector3(13, 0, -6)]:
        op.hero.position = at
        op._check_crates()
    _advance(op, 0.1)
    _check(op.outcome == op.Outcome.VICTORY and not op.production.enabled
        and op.production.balance == 400 and op.production.pending.is_empty(),
        "victory must refund the unfinished order as well as retain gathered funds")
    _advance(op, 10.0)
    _check(op.production.completed == 1 and op.units.size() == 3,
        "a finished operation deployed a late reinforcement")

    for faction in [0, 1]:
        op = await _land(faction)
        op.production.credit(100)
        op._queue_reinforcement()
        op.hero.position = Vector3(5, 0, -4)
        op.escort.position = Vector3(5, 0, -2)
        op.sentry.damage = 200
        op.sentry.reload_time = 0
        _advance(op, 0.1)
        _check(op.outcome == op.Outcome.DEFEAT and not op.production.enabled
            and op.production.balance == 100 and op.production.pending.is_empty(),
            "last casualty must stop production and return reserved credits")
        _advance(op, 10.0)
        _check(op.units.is_empty() and op.production.completed == 0, "factory resurrected a defeated squad")
    if failures == 0:
        print("RTS_PRODUCTION_TEST_PASS army=11 group_routes=4 wall_ms=", Time.get_ticks_msec() - started)
    get_tree().quit(0 if failures == 0 else 1)
