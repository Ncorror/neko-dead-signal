extends Node
## Full operation with normal damage and income, no granted money or teleporting troops.

var op
var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> bool:
    if not ok:
        failures += 1
        push_error("RTS_EXTENDED_PLAY_TEST_FAIL " + message)
    return ok

func _advance(seconds: float) -> void:
    for frame in range(ceili(seconds * 60.0)):
        op._physics_process(1.0 / 60.0)

func _move(point: Vector3, seconds: float) -> void:
    op._select_all_units()
    op._issue_move(point)
    _advance(seconds)

func _place(kind: StringName, at: Vector3) -> bool:
    op._update_visibility(0, true)
    op.construction.begin(kind, op)
    op.construction.choose(at, op)
    var reason: String = op.construction.validate(kind, at, op)
    return _check(reason.is_empty() and op.construction.confirm(op), "playthrough site " + str(at) + ": " + reason)

func _run() -> void:
    get_tree().current_scene = null
    GameState.set_selection(0, 0, "Люди", "Амина")
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    op = get_tree().current_scene
    op.set_physics_process(false)
    _move(Vector3(-8, 0, 11), 8)
    _move(Vector3(5, 0, 2), 8)
    if op.sentry.hull > 0:
        _move(Vector3(8, 0, -4), 8)
        op._issue_attack()
        _advance(12)
    _move(Vector3(13, 0, -6), 9)
    if not _check(op.sentry.hull == 0 and op.crates.is_empty() and op.outcome == op.Outcome.ACTIVE,
        "normal opening failed: guard=%d crates=%d troops=%d" % [op.sentry.hull, op.crates.size(), op.units.size()]):
        get_tree().quit(1)
        return
    _move(Vector3(0, 0, -9), 8)
    if not _place(&"generator", Vector3(-4, 0, -5)) or not _place(&"extractor", Vector3(3, 0, -4)):
        get_tree().quit(1)
        return
    _advance(160)
    op._open_factory()
    for i in range(4):
        _check(op._queue_reinforcement(), "natural resource income could not fund the army")
    _advance(25)
    for i in range(op.objectives.relays.size()):
        var relay: Dictionary = op.objectives.relays[i]
        _move(relay["node"].position, 32)
        if relay["enemy"].hull > 0:
            op._select_all_units()
            op._issue_attack(relay["enemy"])
            _advance(12)
        if not _check(not op.units.is_empty() and relay["enemy"].hull == 0,
            "army lost at relay %d, guard=%d" % [i + 1, relay["enemy"].hull]):
            get_tree().quit(1)
            return
        if not relay["captured"]:
            op._select_unit(op.units.back())
            op._issue_move(relay["node"].position)
            _advance(10)
        _check(relay["captured"], "survivor could not capture relay " + str(i + 1))
        if i == 0:
            op._open_factory()
            for extra in range(2):
                op._queue_reinforcement()
            _advance(13)
    _check(op.outcome == op.Outcome.VICTORY and op.objectives.captured() == 2
        and op.economy.earned > 0 and op.production.completed >= 4,
        "normal-damage operation did not finish with the expanded goals")
    if failures == 0:
        print("RTS_EXTENDED_PLAY_TEST_PASS cheats=none income=%d produced=%d survivors=%d relays=2" % [
            op.economy.earned, op.production.completed, op.units.size()])
    get_tree().quit(0 if failures == 0 else 1)
