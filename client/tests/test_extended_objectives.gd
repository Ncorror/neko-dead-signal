extends Node
## Multiple targets, hidden contacts, one-time capture rewards and complete victory.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_OBJECTIVES_TEST_FAIL " + message)

func _land(faction: int = 0):
    GameState.set_selection(faction, 0, "Люди" if faction == 0 else "Саари", "Амина" if faction == 0 else "Сэйра")
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op.economy.income_enabled = false
    op._set_auto_fire(false)
    op.sentry.damage = 0
    op.enemy_ai.movement_enabled = false
    for enemy in op.objectives.enemies():
        enemy.damage = 0
    for frame in range(10):
        await get_tree().process_frame
    return op

func _advance(op, seconds: float) -> void:
    for frame in range(ceili(seconds * 60.0)):
        op._physics_process(1.0 / 60.0)

func _build(op, kind: StringName, at: Vector3) -> void:
    op.hero.position = at + Vector3(0, 0, 5)
    op._update_visibility(0, true)
    op.construction.begin(kind, op)
    op.construction.choose(at, op)
    var reason: String = op.construction.validate(kind, at, op)
    _check(reason.is_empty() and op.construction.confirm(op), "mission building rejected: " + reason)

func _tap(button: Button) -> void:
    var view := button.get_viewport()
    _check(view.get_visible_rect().encloses(button.get_global_rect()), "new catalog button off-screen: " + button.text)
    for down in [true, false]:
        var touch := InputEventScreenTouch.new()
        touch.position = button.get_global_rect().get_center()
        touch.pressed = down
        view.push_input(touch, true)

func _run() -> void:
    get_tree().current_scene = null
    for faction in [0, 1]:
        var op = await _land(faction)
        _check(op.objectives.expanded and op._active_enemies().size() == 3, "expanded mission did not create three enemies")
        var first: Dictionary = op.objectives.relays[0]
        var second: Dictionary = op.objectives.relays[1]
        _check(not first["node"].visible and not first["enemy"].visible, "unexplored relay or defence was revealed")
        op._issue_attack(first["enemy"])
        _check(op.attackers.is_empty(), "manual attack accepted a hidden defence")
        op.hero.position = Vector3(3, 0, -4)
        op._update_visibility(0, true)
        op._issue_attack()
        _advance(op, 9)
        for crate in op.crates.duplicate():
            op.hero.position = Vector3(crate.position.x, 0, crate.position.z)
            op._check_crates()
        _advance(op, 0.1)
        _check(op.crates.is_empty() and op.sentry.hull == 0 and op.outcome == op.Outcome.ACTIVE,
            "old three-container goal ended the expanded mission early")

        first["enemy"].position = Vector3(-20, 0, -4)
        second["enemy"].position = Vector3(-20, 0, 3)
        op.hero.position = Vector3(-24, 0, -4)
        op.escort.position = Vector3(-24, 0, 3)
        op._update_visibility(0, true)
        op._select_unit(op.hero)
        op._issue_attack(first["enemy"])
        op._select_unit(op.escort)
        op._issue_attack(second["enemy"])
        _check(op.attack_targets[op.hero] == first["enemy"] and op.attack_targets[op.escort] == second["enemy"],
            "separate attack orders selected the wrong enemy")
        op.hero.damage = 200
        op.hero.cooldown = 0
        op._shoot(op.hero, first["enemy"])
        _check(not op.attackers.has(op.hero) and op.attackers.has(op.escort), "one enemy death canceled unrelated attacks")
        op._refresh_order_markers()
        _check(op.enemy_order_markers[0].position == second["enemy"].position, "marker followed the original sentry instead of its target")
        var marker_position: Vector3 = op.enemy_order_markers[0].position
        op._set_queue_mode(true)
        op._issue_move(Vector3(-24, 0, 12))
        second["enemy"].position = Vector3(50, 0, 50)
        op._update_visibility(0, true)
        op._process(0.05)
        _check(op.enemy_order_markers[0].position == marker_position, "marker leaked an unseen defence position")
        _advance(op, 6)
        _check(op.escort.position.distance_to(Vector3(-24, 0, 12)) < 0.1 and not op.attackers.has(op.escort),
            "losing the second target failed to release its queued movement")
        second["enemy"].position = op.objectives.POSITIONS[1] + Vector3(0, 0, 4)
        op.hero.position = second["enemy"].position + Vector3(-4, 0, 0)
        op.hero.damage = 12
        op._select_unit(op.hero)
        op._set_queue_mode(false)
        op._update_visibility(0, true)
        op._issue_attack(second["enemy"])
        _advance(op, 9)
        _check(second["enemy"].hull == 0, "manual attack could not destroy the second defence")

        op.hero.position = first["node"].position
        _advance(op, 3)
        _check(first["label"].text.ends_with("%"), "stationary capture progress did not refresh")
        op.hero.position += Vector3(0, 0, 5)
        _advance(op, 0.1)
        _check(first["progress"] == 0 and not first["captured"], "capture continued after the area was abandoned")
        _check(first["label"].text.ends_with("ЗАЙМИ ПОСЛЕ БОЯ"), "abandoned capture left stale progress text")
        var bank: int = op.production.balance
        op.hero.position = first["node"].position
        _advance(op, 6.2)
        _check(first["captured"] and op.production.balance == bank + 150, "first capture failed to pay exactly once")
        _check(first["label"].text == "УЗЕЛ 1 · ЗАХВАЧЕН", "captured relay retained its percentage")
        _advance(op, 7)
        _check(op.production.balance == bank + 150, "captured relay paid repeatedly")
        op.hero.position = second["node"].position
        _advance(op, 6.2)
        _check(op.objectives.captured() == 2 and op.outcome == op.Outcome.ACTIVE,
            "mission did not require a working extraction and power base")
        _build(op, &"generator", Vector3(28, 0, 24))
        _advance(op, 6.2)
        _check(op.outcome == op.Outcome.ACTIVE, "generator alone completed the development objective")
        _build(op, &"extractor", Vector3(21, 0, 24))
        _advance(op, 8.3)
        _check(op.outcome == op.Outcome.VICTORY and not op.economy.enabled and op.objectives.captured() == 2,
            "complete expanded objectives did not finish with victory")
        for frame in range(10):
            await get_tree().process_frame
        for control in [op.result_heading, op.result_summary, op.result_dialog.get_ok_button()]:
            _check(control.get_viewport().get_visible_rect().encloses(control.get_global_rect()), "expanded result UI clipped")
        op = await _land(faction)
        _check(op.production.balance == 0 and op.objectives.captured() == 0 and op._active_enemies()[1].hull == 120,
            "replay retained captures, money or dead defences")

    for size in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        get_tree().root.size = size
        var op = await _land()
        op.production.credit(500)
        op._open_construction()
        await get_tree().process_frame
        for button in [op.build_panel.factory_button, op.build_panel.outpost_button, op.build_panel.extractor_button, op.build_panel.generator_button]:
            _check(get_viewport().get_visible_rect().encloses(button.get_global_rect()), "four-building catalog clipped at " + str(size))
        _tap(op.build_panel.extractor_button)
        op.construction.choose(Vector3(-3, 0, -3), op)
        op.build_panel.refresh()
        await get_tree().process_frame
        _tap(op.build_panel.action_button)
        await get_tree().process_frame
        _check(op.construction.buildings.back()["kind"] == &"extractor" and op.production.balance == 350,
            "native extractor control failed or issued a duplicate charge")
        _tap(op.build_panel.cancel_button)
        await get_tree().process_frame
        _tap(op.build_panel.generator_button)
        _check(op.construction.placing == &"generator" and op.production.balance == 500 and op.unit_paths.is_empty(),
            "native generator selection spent money or moved a troop")
        op._close_construction()
        op._show_objectives()
        op.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not op.objectives_dialog.visible and not op.return_dialog.visible, "Back did not close goals before requesting a return")
    if failures == 0:
        print("RTS_OBJECTIVES_TEST_PASS factions=2 enemies=3 targets=independent fog=ok capture=ok rewards=once victory=ok ui=3")
    get_tree().quit(0 if failures == 0 else 1)
