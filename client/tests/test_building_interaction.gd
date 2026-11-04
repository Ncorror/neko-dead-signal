extends Node
## Owned building sight, a real narrow passage and native placement gestures.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_BUILDING_INTERACTION_TEST_FAIL " + message)

func _settle() -> void:
    for frame in range(10):
        await get_tree().process_frame

func _land(faction: int = 0):
    GameState.set_selection(faction, 0, "Люди" if faction == 0 else "Саари", "Амина" if faction == 0 else "Сэйра")
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op.economy.income_enabled = false
    op.objectives.expanded = false
    op._set_auto_fire(false)
    op.sentry.damage = 0
    op.sentry.position = Vector3(80, 0, -80)
    op.enemy_ai.movement_enabled = false
    await _settle()
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
    _check(reason.is_empty() and op.construction.confirm(op), "site rejected: " + str(at) + " " + reason)
    return op.construction.buildings.back()

func _touch(index: int, at: Vector2, down: bool, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = at
    event.pressed = down
    event.canceled = canceled
    get_viewport().push_input(event, true)

func _drag(index: int, at: Vector2, relative: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = at
    event.relative = relative
    get_viewport().push_input(event, true)

func _tap(button: Button) -> void:
    _check(get_viewport().get_visible_rect().encloses(button.get_global_rect()), "button clipped: " + button.text)
    var at := button.get_global_rect().get_center()
    _touch(0, at, true)
    _touch(0, at, false)

func _run() -> void:
    get_tree().current_scene = null
    for faction in [0, 1]:
        var op = await _land(faction)
        op.production.credit(5000)
        op.hero.position = Vector3(-80, 0, 75)
        op.escort.position = Vector3(-85, 0, 75)
        op._update_visibility(0, true)
        _check(op.visibility.is_visible(op.factory.position) and op.factory.visible,
            "original factory disappeared from owned sight")
        var right := _place(op, &"extractor", Vector3(-19, 0, 20))
        var left := _place(op, &"extractor", Vector3(-25, 0, 20))
        var generator := _place(op, &"generator", Vector3(-19, 0, 35))
        var post := _place(op, &"outpost", Vector3(-19, 0, 50))
        op.hero.position = Vector3(-80, 0, 75)
        op._update_visibility(0, true)
        for entry in [right, left, generator, post]:
            var center: Vector3 = entry["node"].position
            _check(op.visibility.is_visible(center) and entry["node"].visible,
                "owned construction site lost its local sight: " + str(entry["kind"]))
        _check(not op.visibility.is_visible(post["node"].position + Vector3(0, 0, 6)),
            "unfinished post received its powered extended sight")
        _advance(op, 8.2)
        for entry in [right, left, generator, post]:
            var center: Vector3 = entry["node"].position
            var extent: Vector3 = op.construction.DEFINITIONS[entry["kind"]]["size"] * 0.5
            for x in [-extent.x, extent.x]:
                for z in [-extent.z, extent.z]:
                    _check(op.visibility.is_visible(center + Vector3(x, 0, z)),
                        "completed building footprint remained under fog")
        var near := Vector3(-16.5, 0, 20)
        _check(op.visibility.is_visible(near), "building could not observe beyond its own hull")
        op.navigation.set_blocked_box(Vector3(-17, 0, 20), Vector3(0.4, 3, 5), 0.0)
        op._update_visibility(0, true)
        _check(not op.visibility.is_visible(near), "building sight ignored a different occluder")
        _check(not op.navigation.has_clear_shot(right["node"].position, near), "building sight exception also bypassed weapon cover")
        op.navigation.remove_blocked_box(Vector3(-17, 0, 20))

        # Existing placement margins already permit one walkable grid column.
        # Keep their sizes and place troops through it in the real operation.
        for z in range(16, 25):
            _check(op.navigation.is_walkable(Vector2i(-22, z)), "one-cell passage was blocked")
        op.hero.position = Vector3(-22, 0, 16)
        op._select_unit(op.hero)
        op.build_panel.hide()
        op._issue_move(Vector3(-22, 0, 24))
        _advance(op, 3)
        _check(op.hero.position.distance_to(Vector3(-22, 0, 24)) < 0.1, "officer failed to traverse the narrow passage")
        op.escort.position = Vector3(-22, 0, 16)
        op.hero.position = Vector3(-80, 0, 75)
        op._select_unit(op.escort)
        op._issue_move(Vector3(-22, 0, 24))
        _advance(op, 3)
        _check(op.escort.position.distance_to(Vector3(-22, 0, 24)) < 0.1, "escort failed to traverse the narrow passage")
        op._update_visibility(0, true)
        var queued_observers: Array[Vector3] = [op.hero.position]
        _check(op.visibility.request_snapshot(queued_observers, true, op.construction.local_observers()),
            "queued building sight fixture failed to start")
        op.visibility.advance(op.navigation, 1)
        op.sentry.weapon_range = 250
        op.sentry.damage = 1000
        for unit in op.units.duplicate():
            op.sentry.cooldown = 0
            op._shoot(op.sentry, unit)
        _advance(op, 0.1)
        op.visibility.advance(op.navigation, 10000)
        _check(op.outcome == op.Outcome.DEFEAT and op.visibility.visible.count(1) == 0
            and not op.visibility.scanning, "building or queued scan kept sight active after defeat")

    for resolution in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        get_tree().root.size = resolution
        var op = await _land(1)
        op.production.credit(200)
        _tap(op.build_button)
        await _settle()
        _tap(op.build_panel.factory_button)
        await _settle()
        var first := Vector3(-3, 0, -3)
        var screen: Vector2 = op.view_camera.unproject_position(first)
        _touch(5, screen, true)
        _check(op.placement_touch_active and op.construction.has_candidate and op.construction.candidate == first,
            "placement did not start on finger down")
        var focus: Vector3 = op.camera_focus
        for target in [Vector3(-6, 0, -3), Vector3(-9, 0, -5), first]:
            var next: Vector2 = op.view_camera.unproject_position(target)
            _drag(5, next, next - screen)
            screen = next
            _check(op.construction.candidate == target and op.camera_focus == focus,
                "held finger did not move only the preview: " + str(resolution))
        var panel: Vector2 = op.build_panel.action_button.get_global_rect().get_center()
        _drag(5, panel, panel - screen)
        _touch(5, panel, false)
        _check(op.construction.candidate == first and not op.placement_touch_active and op.touch_points.is_empty()
            and op.production.balance == 200 and op.construction.buildings.size() == 1 and op.unit_paths.is_empty(),
            "drag over UI moved the site, built, issued an order or retained a finger")
        var other: Vector2 = op.view_camera.unproject_position(Vector3(-6, 0, -3))
        _touch(7, other, true)
        _drag(7, screen, screen - other)
        _touch(7, screen, false, true)
        _check(op.construction.candidate == first and op.touch_points.is_empty(), "canceled drag did not restore the previous candidate")
        _touch(7, other, true)
        var second := other + Vector2(100, 0)
        _touch(9, second, true)
        var zoom: float = op.camera_zoom
        _drag(9, second + Vector2(80, 0), Vector2(80, 0))
        _touch(7, other, false)
        _touch(9, second + Vector2(80, 0), false)
        _check(op.camera_zoom < zoom and op.construction.candidate == first and op.touch_points.is_empty()
            and op.production.balance == 200 and op.unit_paths.is_empty(), "placement pinch moved a site or issued a command")
        _tap(op.build_panel.action_button)
        await _settle()
        _check(op.construction.buildings.size() == 2 and op.production.balance == 0, "explicit confirmation did not charge once")
        _tap(op.build_panel.cancel_button)
        await _settle()
        _check(op.construction.buildings.size() == 1 and op.production.balance == 200, "dragged site cancellation did not refund once")
        _tap(op.build_panel.generator_button)
        _touch(2, Vector2(300, 400), true)
        op.notification(NOTIFICATION_WM_WINDOW_FOCUS_OUT)
        _check(not op.placement_touch_active and op.touch_points.is_empty(), "focus loss retained placement gesture")
        op._close_construction()
    if failures == 0:
        print("RTS_BUILDING_INTERACTION_TEST_PASS factions=2 own_sight=ok cover=ok passage=officer,escort drag=3 ui=ok cancel=ok pinch=ok defeat=ok")
    get_tree().quit(0 if failures == 0 else 1)
