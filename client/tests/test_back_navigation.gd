extends Node
## Android Back closes a layer first, then requests an explicit scene exit.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_BACK_TEST_FAIL " + message)

func _tap(button: Button) -> void:
    var viewport := button.get_viewport()
    _check(viewport.get_visible_rect().encloses(button.get_global_rect()), "back dialog button clipped")
    for down in [true, false]:
        var event := InputEventScreenTouch.new()
        event.position = button.get_global_rect().get_center()
        event.pressed = down
        viewport.push_input(event, true)

func _run() -> void:
    get_tree().current_scene = null
    for resolution in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        get_tree().root.size = resolution
        GameState.set_selection(0, 0, "Люди", "Амина")
        get_tree().change_scene_to_file("res://scenes/operation.tscn")
        await get_tree().scene_changed
        var op = get_tree().current_scene
        op.set_physics_process(false)
        op.economy.income_enabled = false # Isolate the existing fixed-budget scenario.
        op.objectives.expanded = false # Retain the original ground-operation goals in this regression.
        op.production.credit(300)
        op._issue_move(Vector3(-20, 0, -20))
        op._open_factory()
        op.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not op.production_panel.visible and not op.return_dialog.visible, "Back did not close factory first")
        op._open_construction()
        op.build_panel.choose(&"factory")
        op.construction.choose(Vector3(-3, 0, -3), op)
        op.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not op.build_panel.visible and op.construction.placing == &"" and op.production.balance == 300,
            "Back left a ghost preview or charged resources")
        op.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        await get_tree().process_frame
        _check(op.return_dialog.visible, "system Back did not request a return confirmation")
        _tap(op.return_dialog.get_cancel_button())
        await get_tree().process_frame
        _check(get_tree().current_scene == op and not op.return_dialog.visible and op.unit_paths.has(op.hero),
            "canceling return changed scene or discarded orders")
        op._open_construction()
        op.build_panel.choose(&"factory")
        op.construction.choose(Vector3(-3, 0, -3), op)
        _check(op.construction.confirm(op), "paid-site Back fixture failed")
        op.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not op.build_panel.visible and op.construction.buildings.size() == 2 and op.production.balance == 100,
            "closing site details canceled paid construction")
        var escape := InputEventKey.new()
        escape.keycode = KEY_ESCAPE
        escape.pressed = true
        op.get_viewport().push_input(escape, true)
        await get_tree().process_frame
        _check(op.return_dialog.visible, "Escape did not use the same confirmation")
        op.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not op.return_dialog.visible and op.production.balance == 100, "canceling Escape altered paid construction")
        op.diagnostics_panel._open()
        op.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not op.diagnostics_panel.popup.visible and not op.return_dialog.visible, "Back did not close diagnostics first")
        op._finish(op.Outcome.VICTORY)
        op.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not op.result_dialog.visible and not op.return_dialog.visible, "Back did not close operation result first")
        op.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        await get_tree().process_frame
        _tap(op.return_dialog.get_ok_button())
        await get_tree().scene_changed
        _check(get_tree().current_scene.get_script() == load("res://scripts/main.gd"), "confirmed Back failed to return to ground command")
    if failures == 0:
        print("RTS_BACK_TEST_PASS viewports=3 modal=ok preview=ok cancel=ok confirm=ok")
    get_tree().quit(0 if failures == 0 else 1)
