extends Node
## Run as a scene so the test exercises the app autoload, GUI and scene changes.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_LANDING_TEST_FAIL " + message)

func _advance(op, frames: int) -> void:
    for frame in range(frames):
        op._physics_process(1.0 / 60.0)

func _touch(pos: Vector2) -> void:
    for down in [true, false]:
        var tap := InputEventScreenTouch.new()
        tap.index = 0
        tap.position = pos
        tap.pressed = down
        Input.parse_input_event(tap)
        Input.flush_buffered_events()

func _run() -> void:
    var tree := get_tree()
    # Keep this driver alive while the actual game scenes change.
    tree.current_scene = null
    tree.change_scene_to_file("res://scenes/main.tscn")
    await tree.scene_changed
    await tree.process_frame
    var menu = tree.current_scene
    _touch(menu.faction_buttons[1].get_global_rect().get_center())
    _check(menu.faction_index == 1, "touch must select the Saari fleet")
    _touch(menu.officer_buttons[1].get_global_rect().get_center())
    _check(menu.officer_index == 1, "touch must select the second Saari officer")
    _touch(menu.cta.get_global_rect().get_center())
    await tree.process_frame
    await tree.process_frame
    var op = tree.current_scene
    if op == null or not op.has_method("_issue_attack"):
        _check(false, "touch on deploy must enter the operation")
        tree.quit(1)
        return
    op.set_physics_process(false)
    _check(GameState.officer_name.begins_with("Оралин"), "deploy must carry chosen officer")
    _check(op.sentry.hull == 100 and op.unit_paths.is_empty(), "fresh landing")
    _touch(op.escort_button.get_global_rect().get_center())
    _check(op.selected_unit == op.escort and op.unit_paths.is_empty(), "HUD tap selected escort without moving")
    # One physical gesture: mouse emulation must not turn a camera drag into a move order.
    var start := Vector2(650, 400)
    var down := InputEventScreenTouch.new()
    down.position = start
    down.pressed = true
    Input.parse_input_event(down)
    var drag := InputEventScreenDrag.new()
    drag.position = start + Vector2(90, 0)
    drag.relative = Vector2(90, 0)
    Input.parse_input_event(drag)
    var up := InputEventScreenTouch.new()
    up.position = drag.position
    Input.parse_input_event(up)
    Input.flush_buffered_events()
    _check(op.unit_paths.is_empty() and op.camera_focus != op.escort.position, "drag pans without ordering movement")

    op._select_all_units()
    var target_screen: Vector2 = op.view_camera.unproject_position(op.sentry.position + Vector3.UP)
    _touch(target_screen)
    _check(op.attackers.size() == 2, "touch on sentry assigns attack to both units")
    op._focus_escort()
    op._stop_selected_units()
    _check(op.attackers == [op.hero] and not op.unit_paths.has(op.escort), "stop cancels just the selected attacker")
    op._focus_hero()
    op._issue_move(Vector3(-5, 0, 0))
    _check(op.attackers.is_empty(), "move supersedes attack")
    _advance(op, 15)
    _check(op.sentry.hull == 100, "no damage outside range")

    # A static box at (9, 7) must block shots but not movement around it.
    _check(not op.navigation.has_clear_shot(Vector3(7, 0, 7), Vector3(11, 0, 7)), "cover blocks shots")
    _check(op.navigation.has_clear_shot(Vector3(7, 0, 4), Vector3(11, 0, 4)), "open firing lane")
    op._select_all_units()
    op._issue_attack()
    _advance(op, 12 * 60)
    _check(op.sentry.hull == 0 and op.attackers.is_empty(), "squad must approach and destroy sentry")
    _check(op.hero.hull < 100 or op.escort.hull < 80, "sentry must return fire")
    _check(op.outcome == op.Outcome.ACTIVE, "destroying sentry alone cannot win")

    op._focus_escort()
    op._issue_move(Vector3(5, 0, 2))
    _advance(op, 5 * 60)
    _check(op.resources_collected == 100, "escort can collect supplies alone")
    op._select_all_units()
    for point in [Vector3(-8, 0, 11), Vector3(13, 0, -6)]:
        op._issue_move(point)
        _advance(op, 12 * 60)
    _check(op.resources_collected == 300 and op.crates.is_empty(), "three shared crates credited once")
    _check(op.outcome == op.Outcome.VICTORY and op.unit_paths.is_empty(), "victory must freeze orders")
    op._issue_move(Vector3.ZERO)
    _check(op.unit_paths.is_empty(), "no new orders after victory")

    op._back_to_ship()
    await tree.scene_changed
    menu = tree.current_scene
    _check(menu.faction_index == 1 and menu.officer_index == 1, "roster selection survives return")
    _check(GameState.last_report.contains("ПОБЕДА") and GameState.last_report.contains("300"), "ship shows debrief")
    menu._deploy()
    await tree.scene_changed
    op = tree.current_scene
    op.set_physics_process(false)
    _check(op.resources_collected == 0 and op.crates.size() == 3 and op.sentry.hull == 100, "replay resets mission")
    op.hero.position = Vector3(6, 0, -4)
    op.escort.position = Vector3(6, 0, -4)
    _advance(op, 30 * 60)
    _check(op.units.is_empty() and op.selected_units.is_empty(), "dead units removed from selection")
    _check(op.outcome == op.Outcome.DEFEAT, "no survivors ends mission")
    if failures == 0:
        print("RTS_LANDING_TEST_PASS")
    tree.quit(0 if failures == 0 else 1)
