extends Node
## Time-based resources, power allocation, paused work and brownout sight.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_ECONOMY_TEST_FAIL " + message)

func _land(faction: int = 0):
    GameState.set_selection(faction, 0, "Люди" if faction == 0 else "Саари", "Амина" if faction == 0 else "Сэйра")
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op.objectives.expanded = false
    op._set_auto_fire(false)
    op.sentry.position = Vector3(60, 0, -60)
    op.sentry.damage = 0
    op.enemy_ai.movement_enabled = false
    for frame in range(10):
        await get_tree().process_frame
    return op

func _advance(op, seconds: float) -> void:
    for frame in range(ceili(seconds * 60.0)):
        op._physics_process(1.0 / 60.0)

func _start(op, kind: StringName, at: Vector3) -> Dictionary:
    op.hero.position = at + Vector3(0, 0, 5)
    op._update_visibility(0, true)
    op.construction.begin(kind, op)
    op.construction.choose(at, op)
    var reason: String = op.construction.validate(kind, at, op)
    _check(reason.is_empty(), "site rejected: " + reason + " " + str(at))
    var before: int = op.production.balance
    _check(op.construction.confirm(op), "funded construction rejected")
    _check(op.production.balance == before - op.construction.DEFINITIONS[kind]["cost"], "construction did not debit shared resources exactly once")
    return op.construction.buildings.back()

func _run() -> void:
    get_tree().current_scene = null
    for faction in [0, 1]:
        var op = await _land(faction)
        _advance(op, 4.9)
        _check(op.production.balance == 0, "passive supply paid early")
        _advance(op, 0.2)
        _check(op.production.balance == 2 and op.economy.used == 4 and op.economy.capacity == 10,
            "active idle supply or initial power budget is wrong")
        op.production.credit(2000)
        var mine := _start(op, &"extractor", Vector3(-16, 0, 8))
        _advance(op, 7.5)
        _check(not mine["ready"] and mine["income_age"] == 0, "unfinished extractor earned resources")
        _advance(op, 0.7)
        _check(mine["ready"] and mine["powered"], "ready extractor was not powered")
        mine["income_age"] = 0.0
        op.economy.base_age = 0.0
        var balance: int = op.production.balance
        _advance(op, 4.8)
        _check(op.production.balance == balance, "extractor paid before five working seconds")
        _advance(op, 0.3)
        _check(op.production.balance == balance + 12, "five seconds must pay +2 supply and +10 extraction")
        op.economy.tick(-10, op)
        _check(op.production.balance == balance + 12, "negative time changed the wallet")
        op._queue_reinforcement()
        _check(op.production.balance == balance - 88, "training did not use the same income wallet")
        op._finish(op.Outcome.VICTORY)
        balance = op.production.balance
        _advance(op, 20)
        _check(op.production.balance == balance and not op.economy.enabled, "income continued after mission end")

        op = await _land(faction)
        op.production.credit(3000)
        _start(op, &"factory", Vector3(-16, 0, 8))
        _advance(op, 8.2)
        var third := _start(op, &"factory", Vector3(-23, 0, 8))
        _advance(op, 8.2)
        _check(not third["powered"] and op.economy.demand == 12 and op.economy.used == 8,
            "overloaded power grid did not leave the extra factory unpowered")
        op._open_factory(third)
        op._queue_reinforcement()
        _advance(op, 6.2)
        _check(third["work"].pending.size() == 1 and is_equal_approx(third["work"].pending[0], 6.0)
            and op.units.size() == 2 and op.production_panel.queue_label.text.contains("НЕТ ПИТАНИЯ"),
            "unpowered factory did not pause its paid order")
        var generator := _start(op, &"generator", Vector3(-30, 0, 8))
        _advance(op, 5.8)
        _check(not generator["ready"] and not third["powered"], "unfinished generator supplied power")
        _advance(op, 0.5)
        _check(generator["ready"] and third["powered"] and op.economy.capacity == 22, "generator did not restore power")
        _advance(op, 6.2)
        _check(op.units.size() == 3 and third["work"].completed == 1, "restored factory failed to resume and release its unit")

    var op = await _land()
    op.production.credit(3000)
    _start(op, &"factory", Vector3(-16, 0, 8))
    _start(op, &"outpost", Vector3(-30, 0, 8))
    var post := _start(op, &"outpost", Vector3(-46, 0, 8))
    _advance(op, 5.2)
    op.hero.position = Vector3(-80, 0, 75)
    op.escort.position = Vector3(-85, 0, 75)
    op._update_visibility(0, true)
    _check(post["powered"] and op.visibility.is_visible(Vector3(-46, 0, -6)), "powered post gave no sight")
    _advance(op, 3.1)
    op._update_visibility(0, true)
    _check(not post["powered"] and not op.visibility.is_visible(Vector3(-46, 0, -6)), "power loss left post sight active")
    _start(op, &"generator", Vector3(-60, 0, 8))
    _advance(op, 6.2)
    op.hero.position = Vector3(-80, 0, 75)
    op._update_visibility(0, true)
    _check(post["powered"] and op.visibility.is_visible(Vector3(-46, 0, -6)), "restored power did not restore post sight")
    var balance: int = op.production.balance
    op.sentry.weapon_range = 250
    op.sentry.damage = 1000
    for unit in op.units.duplicate():
        op.sentry.cooldown = 0
        op._shoot(op.sentry, unit)
    _advance(op, 0.1)
    balance = op.production.balance
    _advance(op, 20)
    _check(op.outcome == op.Outcome.DEFEAT and op.production.balance == balance and not op.visibility.is_visible(Vector3(-46, 0, -6)),
        "defeat did not stop income and post sight")
    if failures == 0:
        print("RTS_ECONOMY_TEST_PASS factions=2 supply=ok extraction=ok power=ok pause_resume=ok sight=ok finish=ok")
    get_tree().quit(0 if failures == 0 else 1)
