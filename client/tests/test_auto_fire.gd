extends Node
## Return fire and fire on the move without changing player routes or queues.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_AUTO_FIRE_TEST_FAIL " + message)

func _land(faction: int = 1, officer: int = 0):
    var officer_name := "Сэйра Нэл"
    if faction == 0:
        officer_name = "Лира Восс — снайпер-разведчик" if officer == 3 else "Амина"
    GameState.set_selection(faction, officer, "NEKO" if faction == 0 else "КОНТУР", officer_name)
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op.economy.income_enabled = false # Isolate the existing fixed-budget scenario.
    op.objectives.expanded = false # Retain original landing goals in this regression.
    op.enemy_ai.movement_enabled = false
    for frame in range(8):
        await get_tree().process_frame
    return op

func _away(op) -> void:
    op.hero.position = Vector3(-40, 0, 40)
    op.escort.position = Vector3(-44, 0, 40)

func _advance(op, seconds: float) -> int:
    var moving_hits := 0
    for frame in range(ceili(seconds * 60.0)):
        var before: Vector3 = op.hero.position
        var hull: int = op.sentry.hull
        op._physics_process(1.0 / 60.0)
        if op.hero.position.distance_to(before) > 0.001 and op.sentry.hull < hull:
            moving_hits += 1
    return moving_hits

func _tap(button: Button) -> void:
    var at := button.get_global_rect().get_center()
    _check(get_viewport().get_visible_rect().encloses(button.get_global_rect()), "fire mode button clipped")
    for pressed in [true, false]:
        var touch := InputEventScreenTouch.new()
        touch.position = at
        touch.pressed = pressed
        get_viewport().push_input(touch, true)

func _run() -> void:
    var started := Time.get_ticks_msec()
    get_tree().current_scene = null
    get_tree().root.size = Vector2i(1280, 720)
    for faction in [0, 1]:
        for kind in ["officer", "escort", "reinforcement"]:
            var op = await _land(faction)
            _away(op)
            var unit = op.hero if kind == "officer" else op.escort
            if kind == "reinforcement":
                op.production.credit(100)
                op._queue_reinforcement()
                _advance(op, 7.2)
                unit = op.units.back()
            op._select_unit(unit)
            op._stop_selected_units()
            unit.position = Vector3(1.5, 0, -4)
            op._update_visibility(0, true)
            var origin: Vector3 = unit.position
            _advance(op, 8.5)
            _check(op.auto_fire.enabled and op.sentry.hull == 0 and unit.hull > 0,
                "idle " + kind + " failed to close and return fire for faction " + str(faction))
            _check(unit.position.distance_to(origin) > 1.0 and unit.position.distance_to(origin) < 2.5
                and op.attackers.is_empty() and op.unit_orders.is_empty(),
                "return fire changed player orders or chased too far")

        var op = await _land(faction)
        op.hero.position = Vector3(3.5, 0, -6)
        op.escort.position = Vector3(-40, 0, 40)
        op._update_visibility(0, true)
        op._set_queue_mode(true)
        op._issue_move(Vector3(12, 0, -6))
        op._issue_move(Vector3(18, 0, -6))
        var moving_hits := _advance(op, 0.6)
        _check(moving_hits > 0 and op.unit_paths[op.hero].back() == Vector3(12, 0, -6)
            and op.unit_orders[op.hero][0]["target"] == Vector3(18, 0, -6),
            "fire on the move replaced the active route or queued destination")
        moving_hits += _advance(op, 2.6)
        _check(moving_hits >= 2 and op.hero.position.distance_to(Vector3(18, 0, -6)) < 0.1
            and op.unit_paths.is_empty() and op.unit_orders.is_empty()
            and op.auto_fire.memory.is_empty() and op.hero.hull < 100,
            "moving under fire must finish the route without a later defensive pursuit")
        var hull: int = op.sentry.hull
        _advance(op, 1.0)
        _check(op.sentry.hull == hull and hull == 100 - 2 * op.hero.damage,
            "firing range or shared weapon cooldown was ignored")

    var op = await _land()
    op.hero.position = Vector3(1.5, 0, -4)
    op.escort.position = Vector3(-40, 0, 40)
    op._update_visibility(0, true)
    _advance(op, 0.1)
    _check(op.auto_fire.moving.has(op.hero), "scenario did not start a defensive approach")
    op._set_queue_mode(true)
    op._issue_move(Vector3(-10, 0, -4))
    _check(not op.auto_fire.moving.has(op.hero) and op.auto_fire.memory.is_empty()
        and op.unit_orders.is_empty() and op.unit_paths[op.hero].back() == Vector3(-10, 0, -4),
        "a queued-mode manual move must immediately override automatic pursuit")
    op._set_auto_fire(false)
    _advance(op, 3.0)
    _check(op.hero.position.distance_to(Vector3(-10, 0, -4)) < 0.1,
        "switching fire mode canceled a player move")

    op = await _land()
    op.hero.position = Vector3(1.5, 0, -4)
    op.hero.weapon_range = 1.0
    op.escort.position = Vector3(-40, 0, 40)
    op.sentry.damage = 1
    op.sentry.weapon_range = 20.0
    op._update_visibility(0, true)
    _advance(op, 0.3)
    var anchor: Vector3 = op.auto_fire.memory[op.hero]["anchor"]
    var held: Vector3 = op.hero.position
    op.sentry.position = Vector3(10, 0, -4)
    op._update_visibility(0, true)
    _advance(op, 2.5)
    _check(op.hero.position.distance_to(held) < 0.001
        and op.auto_fire.memory[op.hero]["anchor"] == anchor,
        "repeated hits moved the defence anchor beyond its allowed area")
    op.sentry.position = Vector3(50, 0, 50)
    op._update_visibility(0, true)
    _advance(op, 0.1)
    _check(op.auto_fire.memory.is_empty() and op.auto_fire.moving.is_empty()
        and op.hero.position.distance_to(held) < 0.001,
        "losing sight left an automatic pursuit active")

    op = await _land()
    op.hero.position = Vector3(3.5, 0, -6)
    op.escort.position = Vector3(-40, 0, 40)
    op.sentry.damage = 0
    op.sentry.hull = 12
    op._update_visibility(0, true)
    op._issue_move(Vector3(12, 0, -6))
    _advance(op, 2.0)
    _check(op.sentry.hull == 0 and op.hero.position.distance_to(Vector3(12, 0, -6)) < 0.1,
        "an automatic kill stopped the current movement order")

    op = await _land()
    op.sentry.damage = 0
    op.sentry.position = Vector3(5.5, 0, 7)
    op.hero.position = Vector3(12.5, 0, 7)
    op.hero.weapon_range = 10.0
    op.escort.position = Vector3(5.5, 0, -0.5)
    op._update_visibility(0, true)
    _check(op.sentry.visible, "cover scenario needs shared sight of the enemy")
    _advance(op, 0.5)
    _check(op.sentry.hull == 100, "automatic fire pierced static cover")
    op.hero.position = Vector3.ZERO
    op.hero.weapon_range = 20.0
    op.escort.position = Vector3(-40, 0, 40)
    op.sentry.position = Vector3(10, 0, 0)
    op._update_visibility(0, true)
    _advance(op, 0.5)
    _check(not op.sentry.visible and op.sentry.hull == 100, "automatic fire targeted an unseen enemy")

    op = await _land()
    op.hero.position = Vector3(3, 0, -4)
    op.escort.position = Vector3(-40, 0, 40)
    op.sentry.damage = 0
    op._update_visibility(0, true)
    op._issue_attack()
    _advance(op, 1.0 / 60.0)
    var hull: int = op.sentry.hull
    op._issue_move(Vector3(12, 0, -6))
    _advance(op, 0.3)
    _check(op.sentry.hull == hull, "changing from attack to movement reset weapon cooldown")

    op = await _land()
    op.hero.position = Vector3(1.5, 0, -4)
    op.escort.position = Vector3(-40, 0, 40)
    op._update_visibility(0, true)
    _advance(op, 0.1)
    op._stop_selected_units()
    var stopped: Vector3 = op.hero.position
    _advance(op, 0.05)
    _check(op.hero.position == stopped and op.auto_fire.memory.is_empty(),
        "stop did not cancel the defensive route")
    op._finish(op.Outcome.VICTORY)
    hull = op.sentry.hull
    _advance(op, 2.0)
    _check(op.sentry.hull == hull and op.auto_fire.memory.is_empty() and op.auto_fire_button.disabled,
        "mission end left automatic fire or pursuit active")

    for resolution in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        get_tree().root.size = resolution
        op = await _land(0)
        op.sentry.damage = 0
        _tap(op.auto_fire_button)
        _check(not op.auto_fire.enabled and op.unit_paths.is_empty(),
            "native fire-mode toggle issued a ground order or failed")
        op.hero.position = Vector3(3, 0, -4)
        op.escort.position = Vector3(-40, 0, 40)
        op._update_visibility(0, true)
        _advance(op, 1.0)
        _check(op.sentry.hull == 100, "manual mode still fired automatically")
        op._issue_attack()
        _advance(op, 1.0)
        _check(op.sentry.hull < 100, "manual mode blocked an explicit attack")
        op._stop_selected_units()
        _tap(op.auto_fire_button)
        _check(op.auto_fire.enabled, "native toggle failed to restore automatic fire")
    # Lyra keeps auto-fire, but cannot fire while traversing a player route.
    op = await _land(0, 3)
    op.sentry.damage = 0
    _check(absf(op.hero.weapon_range - 16.0) < 0.001, "Lyra sniper range is not 16")
    op.hero.position = Vector3(3.5, 0, -6)
    op.sentry.position = Vector3(10, 0, -6)
    op.escort.position = Vector3(-40, 0, 40)
    op._update_visibility(0, true)
    op._issue_move(Vector3(12, 0, -6))
    var lyra_target_hull: int = op.sentry.hull
    _advance(op, 0.35)
    _check(op.sentry.hull == lyra_target_hull,
        "Lyra fired while moving; sniper must plant before shooting")
    op._stop_selected_units()
    _advance(op, 1.0)
    _check(op.sentry.hull < lyra_target_hull,
        "stationary Lyra failed to use automatic sniper fire")

    if failures == 0:
        print("RTS_AUTO_FIRE_TEST_PASS factions=2 roles=3 move=ok queue=ok manual=ok cover=ok fog=ok lyra_sniper=ok")
    get_tree().quit(0 if failures == 0 else 1)
