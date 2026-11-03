extends Node
## Regression from Android 0.0.8: last casualty froze a stale sight snapshot.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_RESULT_TEST_FAIL " + message)

func _settle() -> void:
    for frame in range(15):
        await get_tree().process_frame

func _land():
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    await _settle()
    return op

func _tap(button: Button) -> void:
    var viewport := button.get_viewport()
    var at := button.get_global_rect().get_center()
    _check(viewport.get_visible_rect().has_point(at), "result button must be visible")
    for down in [true, false]:
        var touch := InputEventScreenTouch.new()
        touch.position = at
        touch.pressed = down
        viewport.push_input(touch, true)

func _check_layout(op) -> void:
    var frame: Rect2 = op.get_viewport().get_visible_rect()
    var popup: Rect2 = Rect2(Vector2(op.result_dialog.position), Vector2(op.result_dialog.size))
    _check(frame.encloses(popup) and popup.size.y <= 480,
        "embedded result window exceeds screen: " + str(popup) + " in " + str(frame))
    var inner: Rect2 = op.result_dialog.get_visible_rect()
    for control in [op.result_heading, op.result_summary, op.result_dialog.get_ok_button(), op.result_dialog.get_cancel_button()]:
        _check(inner.encloses(control.get_global_rect()), "result content or action clipped by its viewport")

func _lose(op, pending_snapshot: bool) -> void:
    op.hero.position = Vector3(5, 0, -4)
    op.escort.position = Vector3(5, 0, -2)
    op._update_visibility(0, true)
    _check(op.sentry.visible, "loss scenario needs a revealed enemy before casualties")
    op._select_all_units()
    op.queue_button.button_pressed = true
    op._issue_move(Vector3(4, 0, 0))
    op._issue_move(Vector3(-4, 0, 0))
    if pending_snapshot:
        var observers: Array[Vector3] = [Vector3(4, 0, -4), Vector3(4, 0, -2)]
        op.visibility.request_snapshot(observers)
        op.visibility.advance(op.navigation, 1)
        _check(op.visibility.scanning, "scenario must leave an unfinished observer snapshot")
    op.sentry.damage = 200
    op.sentry.reload_time = 0
    op.sentry.cooldown = 0
    op._physics_process(1.0 / 60.0)
    _check(op.units.size() == 1 and op.outcome == op.Outcome.ACTIVE and not op.result_dialog.visible,
        "first casualty must not end a mission with one survivor")
    op._physics_process(1.0 / 60.0)

func _run() -> void:
    var tree := get_tree()
    tree.root.gui_embed_subwindows = true
    tree.current_scene = null
    GameState.set_selection(1, 0, "Саари", "Сэйра Нэл")
    for pending in [false, true]:
        tree.root.size = Vector2i(1280, 720)
        var op = await _land()
        _lose(op, pending)
        await _settle()
        _check(op.outcome == op.Outcome.DEFEAT and op.units.is_empty(), "last casualty must produce defeat")
        _check(op.visibility.visible.count(1) == 0 and not op.visibility.scanning,
            "defeat must remove current sight and cancel stale scan jobs immediately")
        _check(op.visibility.was_explored(Vector3(5, 0, -4)), "defeat must preserve exploration memory")
        var mask: Image = op.sight_texture.get_image()
        _check(mask.get_data().count(255) == 0, "rendered fog mask retained a bright current-sight region")
        _check(not op.sentry.visible, "live enemy must be hidden without surviving observers")
        for crate in op.crates:
            _check(not crate.visible, "crate must be hidden after all observers die")
        _check(op.unit_paths.is_empty() and op.unit_orders.is_empty() and op.selected_units.is_empty()
            and op.order_markers.get_child_count() == 0, "defeat must release orders, selection and markers")
        _check(op.result_dialog.visible and op.result_heading.text == "ПОРАЖЕНИЕ",
            "a prominent defeat dialog must appear automatically")
        _check_layout(op)
        var revision: int = op.visibility.revision
        for frame in range(30):
            op._physics_process(1.0 / 60.0)
        _check(op.visibility.revision == revision and op.visibility.visible.count(1) == 0,
            "stopped physics must not revive sight or finish the mission again")
        _tap(op.result_dialog.get_cancel_button())
        await _settle()
        _check(not op.result_dialog.visible and tree.current_scene == op,
            "map action must preserve debrief and allow inspection")
        _tap(op.result_button)
        await _settle()
        _check(op.result_dialog.visible, "result must be reopenable after inspecting the map")
        op._result_action(&"logs")
        await _settle()
        _check(op.diagnostics_panel.popup.visible, "logs must remain accessible from the result")
        _tap(op.diagnostics_panel.popup.get_ok_button())
        op._show_result()
        await _settle()
        _tap(op.result_dialog.get_ok_button())
        await tree.scene_changed
        _check(GameState.last_report.contains("ПОРАЖЕНИЕ"), "ship must receive the defeat report")

    for resolution in [Vector2i(2048, 945), Vector2i(1024, 600)]:
        tree.root.size = resolution
        var op = await _land()
        _lose(op, true)
        await _settle()
        _check(op.result_dialog.visible, "defeat dialog missing at " + str(resolution))
        _check_layout(op)
        _tap(op.result_dialog.get_cancel_button())
        await _settle()
        _check(not op.result_dialog.visible, "visible cancel action failed at " + str(resolution))
    var op = await _land()
    op._finish(op.Outcome.VICTORY)
    await _settle()
    _check(op.result_dialog.visible and op.result_heading.text == "ПОБЕДА", "victory must retain its own explicit result")
    _check(op.visibility.visible.count(1) > 0, "living winners should keep their legitimate sight")
    if failures == 0:
        print("RTS_RESULT_TEST_PASS")
    tree.quit(0 if failures == 0 else 1)
