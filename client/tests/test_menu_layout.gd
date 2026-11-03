extends Node
## Reproduce the tall exit hitbox after containers have finished sorting.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_MENU_TEST_FAIL " + message)

func _settle() -> void:
    for frame in range(20):
        await get_tree().process_frame

func _touch(view: Viewport, at: Vector2) -> void:
    _check(view.get_visible_rect().has_point(at), "tap must be inside the visible viewport")
    for down in [true, false]:
        var tap := InputEventScreenTouch.new()
        tap.position = at
        tap.pressed = down
        view.push_input(tap, true)

func _tap(button: Button) -> void:
    _touch(button.get_viewport(), button.get_global_rect().get_center())

func _run() -> void:
    var tree := get_tree()
    tree.current_scene = null
    for resolution in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(2400, 1080), Vector2i(1024, 600)]:
        tree.root.size = resolution
        tree.change_scene_to_file("res://scenes/main.tscn")
        await tree.scene_changed
        await _settle()
        var menu = tree.current_scene
        _check(not bool(ProjectSettings.get_setting("application/config/quit_on_go_back")), "Android Back must use scene confirmation")
        var bounds := get_viewport().get_visible_rect()
        _check(menu.close_button.size.y <= 60, "exit button expanded vertically at " + str(resolution))
        for button in [menu.close_button, menu.cta, menu.faction_buttons[0], menu.faction_buttons[1]]:
            _check(bounds.encloses(button.get_global_rect()), "button off-screen: " + button.text)
        _check(bounds.encloses(menu.hero_call.get_global_rect()), "officer info off-screen")
        for label in menu.find_children("*", "Label", true, false):
            if label.text == "REINA: DEAD SIGNAL":
                _check(label.size.y < 60 and label.size.x > 320, "title wraps into a vertical column")
        for ratio in [0.25, 0.5, 0.7]:
            _touch(get_viewport(), Vector2(bounds.end.x - 60, bounds.size.y * ratio))
            await tree.process_frame
            _check(not menu.exit_dialog.visible and tree.current_scene == menu, "side tap opened exit or left menu")
        _tap(menu.close_button)
        await tree.process_frame
        _check(menu.exit_dialog.visible, "exit needs confirmation")
        _tap(menu.exit_dialog.get_cancel_button())
        await tree.process_frame
        _check(not menu.exit_dialog.visible and tree.current_scene == menu, "cancel must keep the game open")
        menu.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        await tree.process_frame
        _check(menu.exit_dialog.visible, "system Back bypassed exit confirmation")
        menu.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not menu.exit_dialog.visible and tree.current_scene == menu, "second Back must cancel exit")
        _tap(menu.faction_buttons[1])
        await _settle()
        _check(menu.faction_index == 1, "visible fleet button must work")
        _check(bounds.encloses(menu.cta.get_global_rect()), "Saari deploy button off-screen")
        # The selected officer must stay reachable on mobile even if drag-scroll fails.
        menu._select_faction(0)
        menu._select_officer(3)
        await _settle()
        _check(menu.officer_index == 3 and GameState.officer_index == 3,
            "Lyra must be selectable and saved")
        _check(menu.hero_role.text.contains("СНАЙПЕР"), "Lyra profile differs from approved sniper design")
        menu._change_officer(1)
        _check(menu.officer_index == 0, "next commander wraps to Amina")
        menu._change_officer(-1)
        _check(menu.officer_index == 3, "previous commander wraps to Lyra")
        print("RTS_PORTRAIT_DEBUG faction=", menu.faction_index, " officer=", menu.officer_index,
            " 2dvisible=", menu.hero_portrait.visible, " texture=", menu.hero_portrait.texture != null,
            " preview3dvisible=", menu.hero_preview_3d.visible,
            " cache=", menu.portrait_cache.keys())
        _check(menu.hero_portrait.visible or menu.hero_preview_3d.visible,
            "selected human commander has an active 2D/3D portrait")
        print("RTS_MENU_LAYOUT resolution=", resolution, " exit=", menu.close_button.get_global_rect(), " deploy=", menu.cta.get_global_rect())
    if failures == 0:
        print("RTS_MENU_TEST_PASS")
    tree.quit(0 if failures == 0 else 1)
