extends Node
## Real scene tests for placement, economy, navigation, vision and native touch UI.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_CONSTRUCTION_TEST_FAIL " + message)

func _settle() -> void:
    for frame in range(10):
        await get_tree().process_frame

func _land(faction: int = 0):
    GameState.set_selection(faction, 0, "Люди" if faction == 0 else "Саари", "Амина" if faction == 0 else "Сэйра Нэл")
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op._set_auto_fire(false)
    op.sentry.damage = 0
    op.enemy_ai.movement_enabled = false
    await _settle()
    return op

func _advance(op, seconds: float) -> void:
    for frame in range(ceili(seconds * 60.0)):
        op._physics_process(1.0 / 60.0)

func _place(op, kind: StringName, at: Vector3) -> bool:
    op.construction.begin(kind, op)
    op.construction.choose(at, op)
    var reason: String = op.construction.validate(kind, at, op)
    _check(reason.is_empty(), "fixture site rejected: " + reason + " " + str(at))
    return op.construction.confirm(op)

func _tap_at(point: Vector2, canceled: bool = false) -> void:
    for down in [true, false]:
        var event := InputEventScreenTouch.new()
        event.position = point
        event.pressed = down
        event.canceled = canceled and not down
        get_viewport().push_input(event, true)

func _tap(button: Button) -> void:
    _check(get_viewport().get_visible_rect().encloses(button.get_global_rect()), "construction button clipped: " + button.text)
    _tap_at(button.get_global_rect().get_center())

func _run() -> void:
    var started := Time.get_ticks_msec()
    get_tree().current_scene = null
    get_tree().root.size = Vector2i(1280, 720)
    for faction in [0, 1]:
        var op = await _land(faction)
        var site := Vector3(-3, 0, -3)
        op.construction.begin(&"factory", op)
        op.construction.choose(site, op)
        _check(not op.construction.confirm(op) and op.production.balance == 0 and op.construction.buildings.size() == 1,
            "unfunded placement charged or created a building")
        op.production.credit(600)
        _check(not op.construction.validate(&"factory", Vector3(95, 0, 95), op).is_empty(), "off-map footprint accepted")
        _check(not op.construction.validate(&"factory", Vector3(60, 0, 0), op).is_empty(), "unseen footprint accepted")
        _check(not op.construction.validate(&"factory", Vector3.ZERO, op).is_empty(), "occupied unit accepted")
        _check(not op.construction.validate(&"outpost", Vector3(5, 0, 2), op).is_empty(), "supply footprint accepted")
        _check(not op.construction.validate(&"factory", op.factory.position, op).is_empty(), "existing building accepted")
        op._issue_move(site)
        _check(not op.construction.validate(&"factory", site, op).is_empty(), "accepted route destination overwritten")
        op._stop_selected_units()
        var cover_before: int = op.navigation.cover.size()
        _check(_place(op, &"factory", site), "funded factory placement failed")
        var second: Dictionary = op.construction.buildings.back()
        _check(op.production.balance == 400 and not second["ready"] and not op.navigation.is_walkable(Vector2i(-3, -3)),
            "site must charge once and reserve its footprint immediately")
        _check(not op.construction.confirm(op) and op.production.balance == 400, "repeated confirm charged twice")
        _check(op.construction.cancel_site(second, op) and not op.construction.cancel_site(second, op)
            and op.production.balance == 600 and op.navigation.is_walkable(Vector2i(-3, -3))
            and op.navigation.cover.size() == cover_before
            and not op.navigation.is_walkable(op.navigation.world_to_cell(op.factory.position)),
            "site cancellation lost resources or erased existing navigation/cover")
        _check(_place(op, &"factory", site), "second placement failed")
        second = op.construction.buildings.back()
        _advance(op, 7.5)
        _check(not second["ready"] and second["work"].completed == 0, "factory completed or produced before its timer")
        _advance(op, 0.6)
        _check(second["ready"] and is_equal_approx(second["body"].scale.y, 1.0), "construction timer did not finish")
        _check(not op.construction.cancel_site(second, op) and op.production.balance == 400, "completed building refunded")
        op._open_factory(second)
        _check(op._queue_reinforcement(), "new factory rejected training")
        op._open_factory()
        _check(op._queue_reinforcement() and op.production.balance == 200
            and second["work"].balance == 200, "factory queues must debit one shared wallet")
        _advance(op, 6.1)
        _check(op.units.size() == 4 and op.production.completed == 1 and second["work"].completed == 1,
            "independent factories did not produce in parallel")
        for unit in op.units.slice(2):
            _check(op.navigation.is_walkable(op.navigation.world_to_cell(unit.position)), "factory spawned inside a structure")
        _advance(op, 5.0)
        _check(op.units.size() == 4 and op.production.balance == 200 and op.production.total_earned == 600,
            "production duplicated a paid unit or counted refunds as new income")

        op = await _land(faction)
        op.production.credit(200)
        _check(_place(op, &"outpost", Vector3(3, 0, -2)), "outpost placement failed")
        var post: Dictionary = op.construction.buildings.back()
        op.hero.position = Vector3(-50, 0, 0)
        op.escort.position = Vector3(-55, 0, 0)
        op._update_visibility(0, true)
        _check(not op.visibility.is_visible(Vector3(5, 0, -2)), "unfinished post gave vision")
        _advance(op, 5.1)
        op._update_visibility(0, true)
        _check(post["ready"] and op.visibility.is_visible(Vector3(5, 0, -2)), "finished post gave no sight without nearby troops")
        _check(not op.navigation.is_walkable(Vector2i(3, -2)), "post footprint was walkable")
        op.sentry.damage = 1000
        op.sentry.position = op.hero.position + Vector3(2, 0, 0)
        op.sentry.cooldown = 0
        op._shoot(op.sentry, op.hero)
        op.sentry.position = op.escort.position + Vector3(2, 0, 0)
        op.sentry.cooldown = 0
        op._shoot(op.sentry, op.escort)
        _advance(op, 0.1)
        _check(op.outcome == op.Outcome.DEFEAT and not op.visibility.is_visible(Vector3(5, 0, -2))
            and not op.visibility.scanning and op.build_button.disabled, "owned post prevented defeat or left current sight open")

    var op = await _land()
    op.production.credit(200)
    op.escort.position = Vector3(-2, 0, 3)
    op._update_visibility(0, true)
    _check(op.construction.validate(&"outpost", Vector3(-1, 0, 7), op).contains("выход"),
        "placement may not close an existing factory exit")
    op.escort.position = Vector3(-3, 0, 1)
    op._update_visibility(0, true)
    op.construction.begin(&"factory", op)
    op.construction.choose(Vector3(-3, 0, -3), op)
    op.hero.position = Vector3(-3, 0, -3)
    _check(not op.construction.confirm(op) and op.production.balance == 200,
        "stale preview placed a building over a moving troop")
    op.hero.position = Vector3.ZERO
    op._queue_reinforcement()
    _check(not op.construction.confirm(op) and op.production.balance == 100,
        "stale preview spent resources reserved by a factory")

    op = await _land()
    op.production.credit(600)
    _check(_place(op, &"factory", Vector3(-3, 0, -3)), "finish fixture factory")
    _advance(op, 8.1)
    var factory: Dictionary = op.construction.buildings.back()
    op._open_factory(factory)
    op._queue_reinforcement()
    op._open_factory()
    op._queue_reinforcement()
    _check(_place(op, &"outpost", Vector3(3, 0, -2)), "finish fixture post")
    op._finish(op.Outcome.VICTORY)
    _advance(op, 20)
    _check(op.production.balance == 400 and op.units.size() == 2
        and op.construction.buildings.size() == 2 and not op.production.enabled and not factory["work"].enabled,
        "finish did not refund unfinished site and all paid queues exactly once")
    _check(op.construction.stop(op) == 0 and op.production.balance == 400, "repeated operation stop refunded twice")

    op = await _land()
    op.production.credit(200)
    op.hero.position = Vector3(-8, 0, -3)
    op.escort.position = Vector3(2, 0, -3)
    op._update_visibility(0, true)
    op._issue_move(Vector3(6, 0, -3))
    op._set_queue_mode(true)
    op._issue_move(Vector3(6, 0, -10))
    _check(_place(op, &"factory", Vector3(-3, 0, -3)), "route fixture factory")
    _check(op.unit_paths[op.hero].back() == Vector3(6, 0, -3)
        and op.unit_orders[op.hero][0]["target"] == Vector3(6, 0, -10), "construction replaced a player route or queue")
    var previous: Vector3 = op.hero.position
    for point in op.unit_paths[op.hero]:
        _check(op.navigation.has_walkable_segment(previous, point), "replanned path crosses new construction")
        previous = point
    _advance(op, 6)
    _check(op.hero.position.distance_to(Vector3(6, 0, -10)) < 0.1, "troop failed to finish its queued route around construction")

    for resolution in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        get_tree().root.size = resolution
        op = await _land()
        op.production.credit(200)
        _tap(op.build_button)
        await _settle()
        _check(op.build_panel.visible and not op.production_panel.visible, "native construction action failed")
        _tap(op.build_panel.factory_button)
        await _settle()
        var ground := Vector3(-3, 0, -3)
        var screen: Vector2 = op.view_camera.unproject_position(ground)
        _tap_at(screen, true)
        _check(not op.construction.has_candidate and op.production.balance == 200, "canceled touch placed a building")
        _tap_at(screen)
        await _settle()
        _check(op.construction.has_candidate and op.production.balance == 200
            and op.unit_paths.is_empty() and not op.build_panel.action_button.disabled,
            "preview tap spent resources, issued movement, or failed")
        _tap(op.build_panel.action_button)
        await _settle()
        _check(op.construction.buildings.size() == 2 and op.production.balance == 0,
            "native confirmation failed or charged more than once")
        _tap(op.build_panel.cancel_button)
        await _settle()
        _check(op.construction.buildings.size() == 1 and op.production.balance == 200 and op.unit_paths.is_empty(),
            "native cancel did not refund exactly once without a ground order")
        _tap(op.build_panel.outpost_button)
        op._close_construction()
        _check(op.construction.placing == &"" and op.construction.preview == null, "closing panel left a ghost building")
    if failures == 0:
        print("RTS_CONSTRUCTION_TEST_PASS factions=2 factories=parallel wallet=shared cancel=ok routes=ok vision=ok touch=3 wall_ms=%d" % (Time.get_ticks_msec() - started))
    get_tree().quit(0 if failures == 0 else 1)
