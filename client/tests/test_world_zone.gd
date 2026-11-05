extends Node
## Play the exploration quest by normal routes and native UI, then reload scenes.

const TEST_PATH := "user://world-zone-regression/progress.json"
var failures := 0
var zone

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD_ZONE_TEST_FAIL " + message)

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
        if FileAccess.file_exists(TEST_PATH + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH + suffix))

func _settle() -> void:
    for frame in range(6):
        await get_tree().process_frame

func _press(button: Button) -> void:
    _check(button.get_viewport().get_visible_rect().encloses(button.get_global_rect()), "button clipped: " + button.text)
    for down in [true, false]:
        var touch := InputEventScreenTouch.new()
        touch.pressed = down
        touch.position = button.get_global_rect().get_center()
        button.get_viewport().push_input(touch, true)

func _advance(seconds: float) -> void:
    for frame in range(ceili(seconds * 60)):
        var before: Vector3 = zone.hero.position
        zone._physics_process(1.0 / 60.0)
        _check(zone.navigation.has_walkable_segment(before, zone.hero.position), "hero crossed a solid footprint")
        _check(before.distance_to(zone.hero.position) <= zone.SPEED / 60.0 + 0.002, "hero teleported between path cells")

func _load_zone() -> void:
    get_tree().change_scene_to_file("res://scenes/world_zone.tscn")
    await get_tree().scene_changed
    zone = get_tree().current_scene
    zone.set_physics_process(false)
    await _settle()

func _run() -> void:
    get_tree().current_scene = null
    _clean()
    GameState.world_progress_path = TEST_PATH
    for faction in [0, 1]:
        _clean()
        GameState.set_selection(faction, 0, "Люди" if faction == 0 else "Саари", "Амина" if faction == 0 else "Сэйра")
        get_tree().change_scene_to_file("res://scenes/main.tscn")
        await get_tree().scene_changed
        await _settle()
        var menu = get_tree().current_scene
        _press(menu.world_button)
        await get_tree().scene_changed
        zone = get_tree().current_scene
        zone.set_physics_process(false)
        await _settle()
        _check(zone.name == "WorldZone" and zone.find_children("WorldHero", "Node3D").size() == 1
            and zone.get_node_or_null("FieldFactory") == null, "world did not open with exactly one personal hero")
        _check(not zone.progress.state()["accepted"], "fresh world retained an old quest")
        # NPC is approached by the same tap handler used by the phone.
        zone._tap(zone.camera.unproject_position(zone.npc.position + Vector3.UP))
        _advance(5)
        _check(zone.conversation.visible and zone.hero.position.distance_to(zone.NPC_AT) <= 3,
            "tap did not approach and open the NPC dialogue")
        await _settle()
        _press(zone.conversation.get_ok_button())
        await _settle()
        _check(zone.progress.state()["accepted"], "native dialogue did not accept the quest")
        for relay in range(3):
            zone._approach(relay)
            _advance(20)
            _check(zone.progress.state()["relays"].has(relay) and zone.relay_labels[relay].text.ends_with("В СЕТИ"),
                "normal movement did not activate relay " + str(relay))
            if relay == 0:
                var at: Vector3 = zone.hero.position
                zone.notification(NOTIFICATION_APPLICATION_PAUSED)
                await _load_zone()
                _check(zone.hero.position.is_equal_approx(at) and zone.progress.state()["relays"] == [0],
                    "pause and scene reload lost the first checkpoint")
        _check(zone.progress.experience() == 0, "relay activation granted the NPC reward early")
        zone._approach(-1)
        _advance(20)
        _check(zone.conversation.visible, "return to NPC did not offer the reward")
        await _settle()
        _press(zone.conversation.get_ok_button())
        await _settle()
        _check(zone.progress.experience() == 100 and zone.progress.credits() == 75, "quest reward was not persisted")
        zone._interact(-1)
        _check(zone.notice.visible and zone.progress.credits() == 75, "NPC repeat duplicated the reward")
        zone.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(not zone.notice.visible and not zone.return_dialog.visible, "Back failed to close the current layer first")
        zone.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        await _settle()
        _press(zone.return_dialog.get_ok_button())
        await get_tree().scene_changed
        await _settle()
        menu = get_tree().current_scene
        _check(menu.has_method("_deploy"), "world return did not reach the ship")
        _press(menu.world_button)
        await get_tree().scene_changed
        zone = get_tree().current_scene
        zone.set_physics_process(false)
        await _settle()
        _check(zone.progress.state()["claimed"] and zone.progress.credits() == 75, "ship/world return lost the completed quest")
        # Existing RTS entry remains a separate working scene with two troops.
        zone._return_to_ship()
        await get_tree().scene_changed
        await _settle()
        menu = get_tree().current_scene
        _press(menu.cta)
        await get_tree().scene_changed
        var operation = get_tree().current_scene
        operation.set_physics_process(false)
        _check(operation.units.size() == 2 and operation.production.balance == 0,
            "world reward leaked into the RTS wallet or changed its starting squad")
    _clean()
    GameState.world_progress_path = "user://world/progress-v1.json"
    if failures == 0:
        print("WORLD_ZONE_TEST_PASS factions=2 hero=1 quest=normal_routes npc=native checkpoint=pause,reload reward=once rts=preserved")
    get_tree().quit(0 if failures == 0 else 1)
