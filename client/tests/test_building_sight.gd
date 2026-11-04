extends Node
## Actual reveal ranges, new exploration, power transitions and dense-base sight budget.

const SIGHT := preload("res://scripts/rts_visibility.gd")
const NAV := preload("res://scripts/rts_navigation.gd")
var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_BUILDING_SIGHT_TEST_FAIL " + message)

func _scan(sight, nav) -> int:
    var frames := 0
    while sight.scanning and frames < 100:
        sight.advance(nav, 128)
        _check(sight.last_step_checks <= 128, "wide sight exceeded the existing per-frame ray budget")
        frames += 1
    _check(not sight.scanning, "wide sight failed to publish a complete snapshot")
    return frames

func _land(faction: int):
    GameState.set_selection(faction, 0, "Люди" if faction == 0 else "Саари", "Амина" if faction == 0 else "Сэйра")
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op.economy.income_enabled = false
    op.objectives.expanded = false
    op._set_auto_fire(false)
    op.sentry.damage = 0
    op.enemy_ai.movement_enabled = false
    op.escort.position = Vector3(-80, 0, 80)
    for frame in range(10):
        await get_tree().process_frame
    return op

func _advance(op, seconds: float) -> void:
    for frame in range(ceili(seconds * 60)):
        op._physics_process(1.0 / 60.0)

func _place(op, kind: StringName, at: Vector3) -> Dictionary:
    op.hero.position = at + Vector3(0, 0, 5)
    op._update_visibility(0, true)
    op.construction.begin(kind, op)
    op.construction.choose(at, op)
    var reason: String = op.construction.validate(kind, at, op)
    _check(reason.is_empty() and op.construction.confirm(op), "wide-sight fixture site rejected: " + reason)
    return op.construction.buildings.back()

func _run() -> void:
    var nav = NAV.new()
    nav.configure(96)
    var sight = SIGHT.new()
    sight.configure(Rect2(-100, -100, 200, 200))
    var center: Array[Vector3] = [Vector3.ZERO]
    var empty: Array[Vector3] = []
    var ranges: Array[float] = [12.0]
    sight.request_snapshot(center, true)
    _scan(sight, nav)
    _check(not sight.was_explored(Vector3(10, 0, 0)), "range fixture already explored the building-only ring")
    sight.request_snapshot(empty, true, center, ranges)
    _scan(sight, nav)
    _check(sight.is_visible(Vector3(10, 0, 0)) and sight.was_explored(Vector3(10, 0, 0)),
        "building did not discover new terrain beyond the unit's radius")
    _check(not sight.is_visible(Vector3(13, 0, 0)), "ordinary building exceeded radius 12")
    ranges[0] = 18.0
    _check(sight.request_snapshot(empty, false, center, ranges), "stationary source radius change did not trigger an update")
    _scan(sight, nav)
    _check(sight.is_visible(Vector3(16, 0, 0)) and not sight.is_visible(Vector3(19, 0, 0)), "outpost radius must be 18")
    ranges[0] = 12.0
    sight.request_snapshot(empty, false, center, ranges)
    _scan(sight, nav)
    _check(not sight.is_visible(Vector3(16, 0, 0)) and sight.was_explored(Vector3(16, 0, 0)),
        "reduced sight retained current vision or erased exploration memory")
    _check(not sight.request_snapshot(empty, false, center, ranges), "unchanged stationary source rebuilt its mask")

    var city: Array[Vector3] = []
    var city_ranges: Array[float] = []
    for x in range(4):
        for z in range(3):
            var at := Vector3(-9 + x * 6, 0, -6 + z * 6)
            city.append(at)
            city_ranges.append(18.0 if x == 0 and z == 0 else 12.0)
            nav.set_blocked_box(at, Vector3(3, 1.6, 3), 0.75)
    var max_frames := 0
    var started := Time.get_ticks_msec()
    for step in range(5):
        var scout: Array[Vector3] = [Vector3(25 + step, 0, 0)]
        sight.request_snapshot(scout, true, city, city_ranges)
        max_frames = maxi(max_frames, _scan(sight, nav))
    var wall_ms := Time.get_ticks_msec() - started
    _check(max_frames <= 30, "twelve-building base takes too many budgeted frames: " + str(max_frames))

    get_tree().current_scene = null
    for faction in [0, 1]:
        var op = await _land(faction)
        op.production.credit(3000)
        op.hero.position = Vector3(-85, 0, 80)
        op._update_visibility(0, true)
        var base_ring: Vector3 = op.factory.position + Vector3(-10, 0, 0)
        op.sentry.position = base_ring
        op._apply_enemy_visibility()
        _check(op.visibility.is_visible(base_ring) and op.sentry.visible,
            "base did not reveal an enemy beyond infantry sight without troops nearby")
        op.sentry.position = op.factory.position + Vector3(-14, 0, 0)
        op._apply_enemy_visibility()
        _check(not op.sentry.visible, "base leaked an enemy beyond its new range")
        op.sentry.position = Vector3(80, 0, -80)
        var at := Vector3(20, 0, 50)
        op.hero.position = at + Vector3(0, 0, 5)
        op._update_visibility(0, true)
        var new_ring := at + Vector3(0, 0, -10)
        _check(not op.visibility.was_explored(new_ring), "extractor reveal fixture was already explored")
        var mine := _place(op, &"extractor", at)
        op.hero.position = Vector3(-85, 0, 80)
        op._update_visibility(0, true)
        _advance(op, 7.5)
        _check(not mine["ready"] and not op.visibility.is_visible(new_ring), "unfinished site received completed building sight")
        _advance(op, 0.8)
        op._update_visibility(0, true)
        _check(mine["ready"] and op.visibility.is_visible(new_ring) and op.visibility.was_explored(new_ring),
            "completed extractor failed to reveal new ground beyond unit sight")

        op = await _land(faction)
        op.production.credit(3000)
        _place(op, &"factory", Vector3(35, 0, 10))
        _place(op, &"outpost", Vector3(55, 0, 10))
        var post := _place(op, &"outpost", Vector3(65, 0, 10))
        op.hero.position = Vector3(-85, 0, 80)
        op._update_visibility(0, true)
        _advance(op, 5.2)
        var edge := Vector3(81, 0, 10)
        op._update_visibility(0, true)
        _check(post["powered"] and op.visibility.is_visible(edge), "powered post did not reveal radius 18")
        _advance(op, 3.1)
        op._update_visibility(0, true)
        _check(not post["powered"] and not op.visibility.is_visible(edge)
            and op.visibility.is_visible(Vector3(75, 0, 10)), "power loss did not reduce post range from 18 to 12")
    if failures == 0:
        print("RTS_BUILDING_SIGHT_TEST_PASS factions=2 unit=8 building=12 outpost=18 site=8 reveal=new enemy=ok power=ok city=12 max_snapshot_frames=%d wall_ms=%d" % [max_frames, wall_ms])
    get_tree().quit(0 if failures == 0 else 1)
