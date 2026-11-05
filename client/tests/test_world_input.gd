extends Node
## Native gestures and UI at Android aspect ratios; damaged saves remain escapable.

const PATH := "user://world-input-regression/progress.json"
var failures := 0
var zone

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD_INPUT_TEST_FAIL " + message)

func _touch(index: int, at: Vector2, down: bool, canceled: bool = false) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = at
    event.pressed = down
    event.canceled = canceled
    zone.get_viewport().push_input(event, true)

func _drag(index: int, at: Vector2, relative: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = at
    event.relative = relative
    zone.get_viewport().push_input(event, true)

func _press(button: Button) -> void:
    var viewport := button.get_viewport()
    for down in [true, false]:
        var touch := InputEventScreenTouch.new()
        touch.position = button.get_global_rect().get_center()
        touch.pressed = down
        viewport.push_input(touch, true)

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        if FileAccess.file_exists(PATH + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

func _settle() -> void:
    for frame in range(8):
        await get_tree().process_frame

func _run() -> void:
    get_tree().current_scene = null
    GameState.world_progress_path = PATH
    GameState.set_selection(0, 0, "Люди", "Амина")
    for size in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        _clean()
        get_tree().root.size = size
        get_tree().change_scene_to_file("res://scenes/world_zone.tscn")
        await get_tree().scene_changed
        zone = get_tree().current_scene
        zone.set_physics_process(false)
        await _settle()
        var bounds: Rect2 = zone.get_viewport().get_visible_rect()
        for control in [zone.top_panel, zone.bottom_panel, zone.journal_button, zone.goal_button,
            zone.follow_button, zone.stop_button, zone.plus_button, zone.minus_button, zone.logs_button, zone.return_button]:
            _check(bounds.encloses(control.get_global_rect()), "native UI clipped at " + str(size))
        var start := Vector2(bounds.size.x * 0.62, bounds.size.y * 0.57)
        var original: Vector3 = zone.hero.position
        var original_focus: Vector3 = zone.focus
        _touch(0, start, true)
        _drag(0, start + Vector2(25, 0), Vector2(25, 0))
        _drag(0, start + Vector2(55, 0), Vector2(30, 0))
        _touch(0, start + Vector2(55, 0), false)
        _check(zone.route.is_empty() and zone.hero.position == original and not zone.following
            and zone.focus != original_focus, "swipe moved the hero or failed to pan")
        _touch(0, start, true)
        _touch(1, start + Vector2(50, 0), true)
        var zoom: float = zone.zoom
        _drag(1, start + Vector2(100, 0), Vector2(50, 0))
        _touch(1, start + Vector2(100, 0), false)
        _drag(0, start + Vector2(20, 0), Vector2(20, 0))
        _touch(0, start + Vector2(20, 0), false)
        _check(zone.zoom < zoom and zone.route.is_empty() and zone.contacts.is_empty(), "pinch/release issued an order or failed to zoom")
        _touch(0, start, true)
        _touch(0, start, false, true)
        _check(zone.route.is_empty(), "canceled touch became a movement order")
        _touch(0, start, true)
        _touch(0, zone.return_button.get_global_rect().get_center(), false)
        _check(not zone.return_dialog.visible and zone.route.is_empty(), "release over UI triggered a button or world order")
        _touch(0, start, true)
        _touch(1, zone.return_button.get_global_rect().get_center(), true)
        _touch(1, zone.return_button.get_global_rect().get_center(), false)
        _touch(0, start, false)
        _check(not zone.return_dialog.visible and zone.route.is_empty(), "second finger activated the return button")
        _press(zone.journal_button)
        await _settle()
        _check(zone.journal.visible, "journal button did not open the quest")
        zone.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not zone.journal.visible and not zone.return_dialog.visible, "Back did not close the journal first")
        _press(zone.logs_button)
        await _settle()
        _check(zone.diagnostics_panel.popup != null and zone.diagnostics_panel.popup.visible,
            "native world LOGS button did not open the installed diagnostics window")
        var zip_button: Button = null
        var copy_button: Button = null
        for button in zone.diagnostics_panel.popup.find_children("*", "Button", true, false):
            if button.text == "СОЗДАТЬ ZIP":
                zip_button = button
            elif button.text == "КОПИРОВАТЬ":
                copy_button = button
        _check(zip_button != null and copy_button != null, "world diagnostics export controls are missing")
        if zip_button != null:
            _press(zip_button)
            await _settle()
            _check(zone.diagnostics_panel.popup.dialog_text.contains("ZIP сохранён")
                and FileAccess.file_exists(RTSDiagnostics.REPORT_DIR + "/report-0.zip"), "native diagnostics ZIP export failed")
        if copy_button != null and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
            _press(copy_button)
            await _settle()
            _check(DisplayServer.clipboard_get().contains("version="), "native diagnostics clipboard action failed")
        zone.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not zone.diagnostics_panel.popup.visible and not zone.return_dialog.visible,
            "Back did not close diagnostics before asking to leave the zone")
        _press(zone.goal_button)
        _check(zone.focus == zone.NPC_AT and not zone.following and zone.route.is_empty(), "goal camera button issued movement")
        _press(zone.follow_button)
        _check(zone.following, "hero-follow button did not resume tracking")
        zone.zoom = 20
        zone.rendered_zoom = 20
        zone.focus = zone.hero.position
        zone.rendered_focus = zone.hero.position
        zone._update_camera(0)
        var destination: Vector2 = zone.camera.unproject_position(Vector3(-10, 0, 18))
        _check(not zone._over_ui(destination), "native ground-tap fixture is under UI")
        _touch(0, destination, true)
        _touch(0, destination, false)
        _check(not zone.route.is_empty(), "native ground tap failed to issue a route")
        var route: Array = zone.route.duplicate()
        zone.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        await _settle()
        _check(zone.return_dialog.visible, "Back did not request a return")
        _press(zone.return_dialog.get_cancel_button())
        await _settle()
        _check(not zone.return_dialog.visible and zone.route == route,
            "canceling return failed: dialog=%s route_preserved=%s" % [zone.return_dialog.visible, zone.route == route])
        _press(zone.stop_button)
        await _settle()
        _check(zone.route.is_empty() and not zone.target_marker.visible, "Stop left an active route or marker")
        for frame in range(30):
            zone._change_zoom(0.5)
        _check(zone.zoom == 8, "near zoom limit failed")
        for frame in range(30):
            zone._change_zoom(2)
        _check(zone.zoom == 30, "far zoom limit failed")
        zone.notification(NOTIFICATION_APPLICATION_PAUSED)
        _check(zone.contacts.is_empty(), "pause retained gesture state")
    # No automatic overwrite or trapped return when both copies are unreadable.
    for suffix in ["", ".bak"]:
        var file := FileAccess.open(PATH + suffix, FileAccess.WRITE)
        file.store_string("[]"); file.close()
    get_tree().change_scene_to_file("res://scenes/world_zone.tscn")
    await get_tree().scene_changed
    zone = get_tree().current_scene
    zone.set_physics_process(false)
    await _settle()
    _check(not zone.progress.writable and zone.notice.visible, "unreadable saves did not show a clear error")
    zone.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
    zone._return_to_ship()
    await get_tree().scene_changed
    _check(get_tree().current_scene.has_method("_enter_world") and FileAccess.get_file_as_string(PATH) == "[]",
        "invalid saves were overwritten or prevented return to the ship")
    _clean()
    GameState.world_progress_path = "user://world/progress-v1.json"
    if failures == 0:
        print("WORLD_INPUT_TEST_PASS sizes=3 tap=ok pan=ok pinch=ok cancel=ok ui=ok logs=native zip=ok back=ok limits=ok corrupt_exit=ok")
    get_tree().quit(0 if failures == 0 else 1)
