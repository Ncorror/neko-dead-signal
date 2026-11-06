extends Node
## Real scene/UI: optional NPC quest, all skills, an unboosted fight and save/revive.

const STORE := preload("res://scripts/world_progress.gd")
const COMBAT := preload("res://scripts/world_combat.gd")
const PATH := "user://world-battle-regression/progress.json"
var zone
var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD_BATTLE_TEST_FAIL " + message)

func _clean() -> void:
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
        if FileAccess.file_exists(PATH + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

func _profile():
    _clean()
    var store = STORE.new()
    store.open_profile(PATH, 0, 0)
    store.begin_quest()
    for id in range(3):
        store.activate(id)
    store.claim_reward()
    return store

func _touch(at: Vector2, pressed: bool, canceled: bool = false, index: int = 0) -> void:
    var touch := InputEventScreenTouch.new()
    touch.position = at
    touch.pressed = pressed
    touch.canceled = canceled
    touch.index = index
    zone.get_viewport().push_input(touch, true)

func _press(button: Button) -> void:
    _check(button.visible and button.get_viewport().get_visible_rect().encloses(button.get_global_rect()), "button clipped: " + button.text)
    _touch(button.get_global_rect().get_center(), true)
    _touch(button.get_global_rect().get_center(), false)

func _tap_world(at: Vector3) -> void:
    var point: Vector2 = zone.camera.unproject_position(at + Vector3.UP)
    _check(not zone._over_ui(point), "enemy / ground fixture is behind a HUD panel")
    _touch(point, true)
    _touch(point, false)

func _settle() -> void:
    for frame in range(8):
        await get_tree().process_frame
        zone._process(0)

func _load() -> void:
    get_tree().change_scene_to_file("res://scenes/world_zone.tscn")
    await get_tree().scene_changed
    zone = get_tree().current_scene
    zone.set_physics_process(false)
    zone.set_process(false)
    await _settle()

func _advance(seconds: float) -> void:
    for frame in range(ceili(seconds * 60)):
        var before: Vector3 = zone.hero.position
        zone._physics_process(1.0 / 60)
        zone._process(1.0 / 60)
        _check(zone.navigation.has_walkable_segment(before, zone.hero.position), "normal walking crossed a footprint")
        _check(zone.combat_view.effects.size() <= 48, "combat effects grew without a bound")

func _native_cast(skill: int, enemy: int) -> void:
    _press(zone.combat_view.skill_buttons[skill])
    _tap_world(zone.combat_view.model.enemies[enemy]["at"])

func _run() -> void:
    get_tree().current_scene = null
    GameState.world_progress_path = PATH
    GameState.set_selection(0, 0, "Люди", "Амина")
    for size in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        _profile()
        get_tree().root.size = size
        await _load()
        _check(not zone.combat_view.model.enabled and not zone.combat_view.actors[0].visible,
            "combat started before accepting its optional quest")
        zone._approach(-1)
        _advance(5)
        await _settle()
        _check(zone.notice.visible and zone.combat_offer_button.visible, "NPC did not offer the follow-up after the signal reward")
        _press(zone.combat_offer_button)
        await _settle()
        _press(zone.conversation.get_ok_button())
        await _settle()
        _check(zone.combat_view.model.enabled and zone.progress.state()["combat"]["accepted"]
            and zone.combat_view.skill_buttons.size() == 5, "native NPC acceptance did not enable the Assault kit")
        var bounds: Rect2 = zone.get_viewport().get_visible_rect()
        for button in zone.combat_view.skill_buttons:
            _check(bounds.encloses(button.get_global_rect()) and button.is_visible_in_tree(), "active skill clipped at " + str(size))
        _check(zone.bottom_panel.position.y - zone.top_panel.get_global_rect().end.y > 200,
            "combat HUD left too little usable playfield at " + str(size))
        _press(zone.combat_view.skill_buttons[1])
        var centre := Vector2(bounds.size.x * 0.6,
            (zone.top_panel.get_global_rect().end.y + zone.bottom_panel.get_global_rect().position.y) * 0.5)
        _touch(centre, true)
        _touch(centre, false, true)
        _check(zone.combat_view.model.cooldowns[1] == 0 and zone.route.is_empty(), "canceled aim cast a grenade or walked")
        _touch(centre, true)
        _touch(centre + Vector2(70, 0), true, false, 1)
        var drag := InputEventScreenDrag.new()
        drag.index = 1
        drag.position = centre + Vector2(110, 0)
        drag.relative = Vector2(40, 0)
        zone.get_viewport().push_input(drag, true)
        _touch(drag.position, false, false, 1)
        _touch(centre, false)
        _check(zone.combat_view.model.cooldowns[1] == 0 and zone.route.is_empty(), "pinch cast a skill or moved the hero")
        zone.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        _check(zone.combat_view.aim_skill == -1 and not zone.return_dialog.visible, "Back left instead of canceling aim")
        _press(zone.combat_view.skill_buttons[3])
        _press(zone.follow_button)
        _check(zone.combat_view.model.cooldowns[3] == 0 and zone.route.is_empty(), "HUD press leaked through to a dash")
        zone.notification(NOTIFICATION_WM_GO_BACK_REQUEST)
        zone.zoom = 16
        zone.rendered_zoom = 16
        zone._update_camera(0)

    # Full fight at the smallest tested landscape; no HP/damage/cooldown boosts.
    _check(zone._move_to(Vector3(7, 0, -10)), "could not route to the combat encounter")
    _advance(9)
    await _settle()
    _check(zone.combat_view.model.hp > 0 and zone.hero.position.distance_to(Vector3(7, 0, -10)) < 0.2,
        "normal approach did not reach the encounter alive")
    _press(zone.combat_view.skill_buttons[0])
    _check(zone.combat_view.model.protocol > 9, "native protocol button failed")
    _native_cast(1, 0)
    _check(zone.combat_view.model.cooldowns[1] > 15, "native fragmentation aim failed")
    _native_cast(2, 2)
    _check(zone.combat_view.model.cooldowns[2] == 0, "native grenade chain skipped launcher delay")
    _advance(1.3)
    _tap_world(zone.combat_view.model.enemies[2]["at"])
    _check(zone.combat_view.model.cooldowns[2] > 23, "HEAT did not fire after the shared delay")
    _advance(1.3)
    _native_cast(4, 2)
    _check(zone.combat_view.model.cooldowns[4] > 27, "native pulse aim failed")
    _press(zone.combat_view.skill_buttons[3])
    var before: Vector3 = zone.hero.position
    _tap_world(before + Vector3(-3.5, -1, 0))
    _check(zone.hero.position.distance_to(before) > 3.3 and zone.hero.position.distance_to(before) <= 3.501
        and zone.navigation.has_walkable_segment(before, zone.hero.position), "native dash failed or crossed cover")
    for turn in range(100):
        if zone.combat_view.model.snapshot()["defeated"].size() == 3 or zone.combat_view.model.hp <= 0:
            break
        if zone.combat_view.model.attack_target < 0:
            for id in range(3):
                if zone.combat_view.model.alive(id):
                    zone.combat_view.target_enemy(id)
                    break
        _advance(0.3)
    _check(zone.combat_view.model.hp > 0 and zone.progress.state()["combat"]["defeated"].size() == 3,
        "unboosted Assault kit could not finish the three-target PvE quest")
    zone._approach(-1)
    _advance(20)
    await _settle()
    _check(zone.conversation.visible and zone.conversation_kind == "combat_claim", "NPC did not offer the combat reward")
    _press(zone.conversation.get_ok_button())
    await _settle()
    _check(zone.progress.experience() == 250 and zone.progress.credits() == 175, "combat reward totals are wrong")
    zone._interact(-1)
    _check(zone.notice.visible and not zone.combat_offer_button.visible and zone.progress.credits() == 175,
        "repeat interaction duplicated or reoffered the completed quest")
    zone.notice.hide()
    var saved_cooldowns: Array = zone.combat_view.model.cooldowns.duplicate()
    zone._checkpoint()
    await _load()
    _check(zone.progress.credits() == 175 and zone.combat_view.model.snapshot()["defeated"] == [0, 1, 2]
        and zone.combat_view.model.cooldowns == saved_cooldowns, "reentry reset targets, reward or cooldowns")
    _press(zone.logs_button)
    await _settle()
    _check(zone.diagnostics_panel.popup.visible, "logs stopped working with combat HUD active")
    zone.notification(NOTIFICATION_WM_GO_BACK_REQUEST)

    # Real incoming hit from a wounded, saved character; death survives reentry.
    var profile = _profile()
    profile.begin_combat()
    var wounded := COMBAT.fresh_profile()
    wounded["hp"] = 1.0
    wounded["cooldowns"][0] = 33.0
    profile.checkpoint(Vector3(7, 0, -10), 16, wounded)
    await _load()
    _advance(0.1)
    await _settle()
    _check(zone.combat_view.model.hp == 0 and zone.combat_view.death_dialog.visible
        and not zone._move_to(Vector3.ZERO), "incoming damage did not stop and visibly defeat the hero")
    zone.combat_view.death_dialog.hide()
    zone._checkpoint()
    await _load()
    _check(zone.combat_view.model.hp == 0 and zone.combat_view.death_dialog.visible,
        "reopening a dead save silently healed the hero")
    var remaining: float = zone.combat_view.model.cooldowns[0]
    _press(zone.combat_view.death_dialog.get_ok_button())
    await _settle()
    _check(zone.combat_view.model.hp == 100 and zone.hero.position == STORE.SPAWN
        and zone.combat_view.model.cooldowns[0] == remaining and zone.progress.credits() == 75,
        "native respawn lost the first quest, changed position incorrectly, or reset cooldowns")
    zone._return_to_ship()
    await get_tree().scene_changed
    var menu = get_tree().current_scene
    menu.cta.pressed.emit()
    await get_tree().scene_changed
    var operation = get_tree().current_scene
    operation.set_physics_process(false)
    _check(operation.units.size() == 2 and operation.production.balance == 0, "world combat changed the RTS opening squad/wallet")
    _clean()
    GameState.world_progress_path = STORE.DEFAULT_PATH
    if failures == 0:
        print("WORLD_BATTLE_TEST_PASS sizes=3 npc=native skills=5 gestures=isolated quest=unboosted reward=once reload=ok death=native cooldowns=preserved logs=ok rts=preserved effects=bounded")
    get_tree().quit(0 if failures == 0 else 1)
