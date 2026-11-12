extends Node
## Real Godot import test: Lyra is human officer 3, never Amina officer 0.
const LYRA := preload("res://scripts/lyra_voss_animations.gd")
var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, note: String) -> void:
    if not ok:
        failures += 1
        push_error("LYRA_RIG_TEST_FAIL " + note)

func _run() -> void:
    var tree := get_tree()
    tree.current_scene = null
    tree.root.size = Vector2i(1280, 720)
    GameState.set_selection(0, 3, "NEKO — свободные бригады", "Лира Восс — снайпер")
    tree.change_scene_to_file("res://scenes/main.tscn")
    await tree.scene_changed
    for i in range(8):
        await tree.process_frame
    var menu = tree.current_scene
    _check(menu.officer_index == 3 and menu.lyra_lab_button.visible, "wrong officer or lab missing")
    _check(not menu.pve_button.disabled, "Lyra Rust Road PvE entry is unavailable")
    var model: Node3D = menu.hero_preview_3d.active_model
    _check(model != null, "Lyra menu model not imported")
    if model == null:
        tree.quit(1)
        return
    var p: AnimationPlayer = LYRA.find_player(model)
    _check(p != null, "No imported AnimationPlayer")
    if p != null:
        _check(LYRA.loaded_count(p) == 20, "Expected exactly 20 original clips")
        _check(LYRA.has_authored_rifle(p), "Authored Rifle Ready/Aim/Fire preview clips missing")
        for rifle_clip in LYRA.RIFLE_CLIP_NAMES:
            _check(not LYRA.resolve_clip(p, str(rifle_clip)).is_empty(), "Missing authored clip: " + str(rifle_clip))
        _check(LYRA.resolve_clip(p, "Idle").is_empty(), "Idle was not exported")
        var skeleton: Skeleton3D = LYRA.find_skeleton(p)
        _check(skeleton != null, "Missing Lyra Skeleton3D")
        if skeleton != null:
            var hips := LYRA.bone_index(skeleton, "Hips")
            var left_hand := LYRA.bone_index(skeleton, "LeftHand")
            var right_hand := LYRA.bone_index(skeleton, "RightHand")
            skeleton.reset_bone_poses()
            skeleton.force_update_all_bone_transforms()
            _check(LYRA.hold_ready_pose(p), "Cannot hold natural ready stance")
            if hips >= 0 and left_hand >= 0 and right_hand >= 0:
                var hx2: float = skeleton.get_bone_global_pose(hips).origin.x
                var relaxed_spread := absf(skeleton.get_bone_global_pose(left_hand).origin.x - hx2) + absf(skeleton.get_bone_global_pose(right_hand).origin.x - hx2)
                _check(relaxed_spread < 0.58, "Ready pose still has A-pose arm spread")
        _check(LYRA.has_weapon(model), "Lyra menu is missing sniper rifle")
        var rifle_node := model.find_child("LyraSniperRifle", true, false) as Node3D
        var rifle_mount := model.find_child("LyraRifleBackMount", true, false) as BoneAttachment3D
        _check(rifle_node != null and rifle_mount != null, "Rifle visual or mount node missing")
        if rifle_node != null:
            _check(rifle_node.visible, "Rifle preview visual is hidden")
        if rifle_mount != null:
            _check(str(rifle_mount.bone_name).to_lower().ends_with("righthand"), "Authored ready pose did not start with rifle in right hand")
            var attack_time := LYRA.play_attack(p)
            _check(attack_time > 0.1 and str(rifle_mount.bone_name).to_lower().ends_with("righthand")
                and str(p.get_meta("neko_lyra_motion", "")) == "attack", "Authored Rifle_Fire did not start")
            _check(LYRA.restore_ready(p) and str(rifle_mount.bone_name).to_lower().ends_with("righthand"),
                "Attack did not restore authored Rifle_Ready")
            var death_time := LYRA.play_death(p)
            _check(death_time >= 0.8 and str(p.get_meta("neko_lyra_motion", "")) == "death", "Death animation was not started")
            _check(is_equal_approx(death_time, p.get_animation(p.current_animation).length), "Death was truncated")
            _check(LYRA.play_movement(p, true, 6.0) == "death", "Movement interrupted death")
            _check(is_zero_approx(LYRA.play_attack(p)), "Attack interrupted death")
            p.advance(0.4)
            var death_position := p.current_animation_position
            var remaining := LYRA.play_death(p)
            _check(is_equal_approx(p.current_animation_position, death_position)
                and is_equal_approx(remaining, death_time - death_position), "Repeated death restarted the fall")
            _check(LYRA.restore_ready(p), "Death pose could not return to ready state")
            _check(LYRA.ready_weapon(p), "Cannot prepare held rifle death regression")
            LYRA.play_death(p)
            _check(str(rifle_mount.bone_name).to_lower().ends_with("righthand"), "Death teleported held rifle to back")
            LYRA.restore_ready(p)
        skeleton = LYRA.find_skeleton(p)
        _check(skeleton != null, "Missing Lyra Skeleton3D")
        if skeleton != null:
            var left_foot: int = LYRA.bone_index(skeleton, "LeftFoot")
            var right_foot: int = LYRA.bone_index(skeleton, "RightFoot")
            if left_foot < 0 or right_foot < 0:
                var names: Array[String] = []
                for bi in range(skeleton.get_bone_count()):
                    names.append(str(skeleton.get_bone_name(bi)))
                print("LYRA_IMPORTED_BONE_NAMES ", names)
            _check(left_foot >= 0 and right_foot >= 0, "Missing rig foot bones")
            if left_foot >= 0 and right_foot >= 0:
                var lf: Vector3 = skeleton.get_bone_global_pose(left_foot).origin
                var rf: Vector3 = skeleton.get_bone_global_pose(right_foot).origin
                _check(absf(lf.z - rf.z) < 0.15, "Neutral stance frozen in a walking stride")
                _check(absf(lf.y - rf.y) < 0.065, "Neutral stance leaves one foot raised")
        _check(LYRA.play_movement(p, true, 4.0) == "walk", "Walk failed")
        _check(LYRA.play_movement(p, true, 5.8) == "run", "Run failed")
        _check(LYRA.play_movement(p, false, 0.0) == "idle", "Stop failed")
        # Two instances of the same PackedScene must not share mutable flags.
        var other := (load(LYRA.MODEL_PATH) as PackedScene).instantiate() as Node3D
        add_child(other)
        var other_player := LYRA.find_player(other)
        var walk := LYRA.resolve_clip(other_player, "Walking")
        var original_walk := other_player.get_animation(walk)
        var original_loop := original_walk.loop_mode
        LYRA.play_movement(p, true, 4.0)
        _check(p.get_animation(LYRA.resolve_clip(p, "Walking")) != original_walk,
            "Live actors still share mutable animation resources")
        _check(original_walk.loop_mode == original_loop, "Actor changed source loop flag")
        LYRA.play_preview(other_player, "Dead")
        _check(LYRA.play_movement(p, false, 0.0) == "idle", "Other actor playback leaked state")
        other.queue_free()
    tree.change_scene_to_file("res://scenes/lyra_animation_lab.tscn")
    await tree.scene_changed
    for i in range(10):
        await tree.process_frame
    var lab = tree.current_scene
    _check(lab.player != null and lab.entries.get_child_count() == 23, "Lab did not expose 20 source + 3 authored rifle clips")
    if lab.player != null:
        lab._play("Standing_Reload")
        _check(lab.status.text.contains("Standing_Reload"), "Play clip failed")
        lab._set_speed(0)
        _check(is_equal_approx(lab.player.speed_scale, 0.25), "Lab slow motion failed")
        lab._scrub(0.5)
        _check(not lab.player.is_playing() and is_equal_approx(lab.player.current_animation_position, 0.5), "Lab scrub did not pause at requested time")
        lab._step(1)
        _check(is_equal_approx(lab.player.current_animation_position, 0.5 + 1.0 / 30.0), "Lab frame step failed")
        lab._step(-1)
        _check(is_equal_approx(lab.player.current_animation_position, 0.5), "Lab reverse step failed")
        lab._toggle_pause()
        _check(lab.player.is_playing(), "Lab resume failed")
        lab._scrub(100.0)
        _check(is_equal_approx(lab.player.current_animation_position, lab.player.current_animation_length), "Lab scrub exceeded clip end")
        lab._toggle_pause()
        _check(lab.player.is_playing() and is_zero_approx(lab.player.current_animation_position), "Lab replay from end failed")
        lab.player.advance(20.0)
        lab._process(0.0)
        _check(not lab.player.is_playing() and lab.pause_button.text == "ПУСК", "Lab transport did not detect clip completion")
        lab._step(-1)
        _check(lab.player.current_animation_position < lab.player.current_animation_length, "Lab could not inspect completed clip")
        var lab_mount := lab.model_view.active_model.find_child("LyraRifleBackMount", true, false) as BoneAttachment3D
        _check(str(lab_mount.bone_name).to_lower().ends_with("righthand") and lab.weapon_in_hand,
            "Lab did not start in authored Rifle_Ready")
        lab._toggle_weapon()
        _check(str(lab_mount.bone_name).to_lower().ends_with("spine2") and not lab.weapon_in_hand,
            "Lab could not stow authored preview rifle")
        lab._toggle_weapon()
        _check(str(lab_mount.bone_name).to_lower().ends_with("righthand") and lab.weapon_in_hand,
            "Lab could not restore authored preview rifle")
        lab._play("Roll_Dodge_1")
        lab.player.seek(0.5, true)
        var root_offset: Vector3 = LYRA.root_motion_offset(lab.player)
        lab._process(0.0)
        if Vector2(root_offset.x, root_offset.z).length() > 0.05:
            _check(lab.model_view.active_model.position.distance_to(lab.preview_origin) > 0.001,
                "Animation lab did not cancel horizontal root travel")
        lab._hold()
        _check(str(lab_mount.bone_name).to_lower().ends_with("righthand") and lab.weapon_in_hand and not lab.timeline.editable,
            "Lab stance failed to restore authored Rifle_Ready and transport")
        _check(lab.model_view.active_model.position.distance_to(lab.preview_origin) < 0.001,
            "Animation lab failed to recenter neutral stance")
        for resolution in [Vector2i(1024, 600), Vector2i(2048, 945)]:
            tree.root.size = resolution
            for frame in range(4):
                await tree.process_frame
            var screen: Rect2 = lab.get_viewport().get_visible_rect()
            for control in [lab.pause_button, lab.weapon_button, lab.time_label, lab.timeline, lab.model_view]:
                _check(screen.encloses(control.get_global_rect()), "Lab transport clipped at " + str(resolution) + ": " + str(control.get_global_rect()) + " in " + str(screen))
        tree.root.size = Vector2i(1280, 720)
    lab._back()
    await tree.scene_changed
    var again = tree.current_scene
    _check(again.officer_index == 3, "Back navigation changed officer")
    again._deploy()
    await tree.scene_changed
    var battle = tree.current_scene
    _check(battle.hero.get_node_or_null("LyraRig") != null, "Lyra not attached to hero")
    _check(absf(battle.hero.weapon_range - 16.0) < 0.001, "Lyra RTS base range must be 16")
    battle._update_visibility(0.0, true)
    _check(battle.visibility._observer_radii.has(16.0), "Lyra sniper sight source missing")
    battle.unit_paths[battle.hero] = [battle.hero.position + Vector3(1, 0, 0)]
    _check(not battle._auto_fire_allowed(battle.hero), "Lyra must not auto-fire while moving")
    battle.unit_paths.erase(battle.hero)
    _check(battle._auto_fire_allowed(battle.hero), "Stationary Lyra auto-fire remained blocked")
    _check(LYRA.has_weapon(battle.hero.get_node_or_null("LyraRig")), "RTS rifle missing")
    _check(battle.animation_players.has(battle.hero), "RTS rig not animated")
    if battle.animation_players.has(battle.hero):
        var player: AnimationPlayer = battle.animation_players[battle.hero]
        battle._set_unit_animation(battle.hero, true)
        _check(str(player.get_meta("neko_lyra_motion", "")) == "run", "RTS run missing")
        battle._set_unit_animation(battle.hero, false)
        _check(str(player.get_meta("neko_lyra_motion", "")) == "idle", "RTS idle missing")
    _check(battle.hero.hull == 100 and battle.escort.hull == 80, "Combat stats changed")
    _check(battle.escort.get_node_or_null("EscortLabel") != null, "Separate escort must be identifiable")
    var rts_capsule := false
    for child in battle.hero.get_children():
        if child is MeshInstance3D and child.mesh is CapsuleMesh and child.visible:
            rts_capsule = true
    _check(not rts_capsule, "RTS hero capsule visible together with LyraRig")
    # A visible corpse must never remain an observer, selected unit or obstacle.
    battle.set_physics_process(false)
    battle.sentry.position = battle.hero.position + Vector3(0, 0, -3)
    battle.hero.rotation.y = 0.0
    battle.hero.cooldown = 0.0
    var sentry_hp: int = battle.sentry.hull
    battle._shoot(battle.hero, battle.sentry)
    _check(battle.sentry.hull == sentry_hp and is_zero_approx(battle.hero.cooldown), "RTS Lyra fired before facing target")
    battle.hero.rotation.y = PI
    battle._shoot(battle.hero, battle.sentry)
    _check(battle.sentry.hull < sentry_hp, "RTS Lyra failed to shoot after turning")
    battle._select_unit(battle.hero)
    battle.unit_paths[battle.hero] = [battle.hero.position + Vector3(1, 0, 0)]
    battle.sentry.position = battle.hero.position + Vector3(1, 0, 0)
    battle.sentry.cooldown = 0
    battle.sentry.damage = 200
    battle._shoot(battle.sentry, battle.hero)
    _check(battle.hero.hull == 0 and battle.hero.visible, "RTS Lyra vanished before death playback")
    _check(not battle.units.has(battle.hero) and not battle.selected_units.has(battle.hero)
        and not battle.unit_paths.has(battle.hero) and not battle.unit_orders.has(battle.hero),
        "RTS corpse retained combat membership or orders")
    battle._update_visibility(0.0, true)
    _check(not battle.visibility._observer_radii.has(16.0), "RTS corpse retained sniper sight")
    var corpse_player: AnimationPlayer = battle.animation_players[battle.hero]
    _check(str(corpse_player.get_meta("neko_lyra_motion", "")) == "death", "RTS path cleanup interrupted death")
    var corpse_length := corpse_player.current_animation_length
    corpse_player.advance(corpse_length + 0.1)
    _check(not corpse_player.is_playing() and battle.hero.visible, "RTS corpse did not hold final frame")
    _check(LYRA.play_movement(corpse_player, true, 6.0) == "death", "RTS corpse resumed movement")
    # Regression for both Earth sector scenes. Their Amina-only loaders used to
    # leave Lyra as a featureless capsule despite a valid 3D rig.
    var original_world: String = GameState.world_progress_path
    var original_surface: String = GameState.surface_progress_path
    GameState.world_progress_path = "user://lyra-visual-regression/world.json"
    GameState.surface_progress_path = "user://lyra-visual-regression/surface.json"
    tree.change_scene_to_file("res://scenes/world_zone.tscn")
    await tree.scene_changed
    for i in range(4):
        await tree.process_frame
    var zone = tree.current_scene
    _check(zone.hero.get_node_or_null("LyraRig") != null, "WorldZone is missing 3D Lyra")
    _check(LYRA.has_weapon(zone.hero.get_node_or_null("LyraRig")), "WorldZone rifle missing")
    _check(not zone.hero.get_node("Placeholder").visible, "WorldZone Lyra capsule remained visible")
    _check(not zone.hero.get_node("PlaceholderFacingBar").visible, "WorldZone Lyra facing bar remained visible")
    _check(zone.hero_motion != null, "WorldZone animation player missing")
    _check(zone.speed_button != null and zone.speed_button.text == "ХОДЬБА" and is_equal_approx(zone.current_move_speed(), zone.SPEED),
        "WorldZone did not start in walking mode")
    zone._toggle_move_mode()
    _check(zone.speed_button.text == "БЕГ" and is_equal_approx(zone.current_move_speed(), zone.RUN_SPEED),
        "WorldZone run toggle failed")
    zone._toggle_move_mode()
    if zone.hero_motion != null:
        zone.route.append(zone.hero.position + Vector3(1, 0, 0))
        zone._physics_process(0.01)
        _check(str(zone.hero_motion.get_meta("neko_lyra_motion", "")) == "walk", "WorldZone failed to animate movement")
        zone.route.clear()
        zone._physics_process(0.01)
        _check(str(zone.hero_motion.get_meta("neko_lyra_motion", "")) == "idle", "WorldZone stop did not reset stance")
    tree.change_scene_to_file("res://scenes/surface_sector_01_prototype.tscn")
    await tree.scene_changed
    for i in range(4):
        await tree.process_frame
    var sector = tree.current_scene
    _check(sector.hero.get_node_or_null("LyraRig") != null, "Surface128 is missing 3D Lyra")
    _check(LYRA.has_weapon(sector.hero.get_node_or_null("LyraRig")), "Surface128 rifle missing")
    _check(sector.hero_motion != null, "Surface128 animation player missing")
    var surface_capsule := false
    for child in sector.hero.get_children():
        if child is MeshInstance3D and child.mesh is CapsuleMesh and child.visible:
            surface_capsule = true
    _check(not surface_capsule, "Surface128 still displays the capsule")
    _check(sector.pve_button != null and sector.pve_button.visible, "Surface128 lost MOBS AND BOSS access for Lyra")
    _check("МОБЫ И БОСС" in sector.pve_button.text, "Surface128 PvE entry has wrong label")
    _check(sector.speed_button != null and sector.speed_button.text == "ХОДЬБА", "Surface128 walking mode button missing")
    sector._toggle_move_mode()
    _check(sector.speed_button.text == "БЕГ" and is_equal_approx(sector.current_move_speed(), sector.RUN_SPEED),
        "Surface128 run toggle failed")
    sector._toggle_move_mode()
    if sector.hero_motion != null:
        sector.route.append(sector.hero.position + Vector3(1, 0, 0))
        sector._physics_process(0.01)
        _check(str(sector.hero_motion.get_meta("neko_lyra_motion", "")) == "walk", "Surface128 failed to animate movement")
        sector._stop()
        _check(str(sector.hero_motion.get_meta("neko_lyra_motion", "")) == "idle", "Surface128 failed to stop walking")
    tree.change_scene_to_file("res://scenes/world_sector.tscn")
    await tree.scene_changed
    for i in range(5):
        await tree.process_frame
    var hunt = tree.current_scene
    _check(hunt.combat_view.model.enabled, "Lyra Rust Road combat stayed disabled")
    _check(hunt.combat_view.model.profile_id == "lyra_voss", "Rust Road did not select Lyra combat profile")
    _check(absf(hunt.combat_view.model.weapon_range - 16.0) < 0.001, "Lyra Rust Road range must be 16")
    _check(hunt.combat_view.actors.size() == 9 and hunt.combat_view.actors[8].visible, "Lyra Rust Road mobs or boss missing")
    for skill_button in hunt.combat_view.skill_buttons:
        _check(not skill_button.visible, "Amina skill leaked into Lyra PvE UI")
    _check_combat_facing(hunt)
    hunt.combat_view.model.hp = 0
    var death_delay: float = hunt.combat_view._begin_death()
    _check(death_delay >= 0.8 and not hunt.combat_view.death_dialog.visible and not hunt.combat_view.death_ready,
        "Respawn dialog appeared before Lyra death animation")
    await get_tree().create_timer(death_delay + 0.08).timeout
    _check(hunt.combat_view.death_dialog.visible and hunt.combat_view.death_ready,
        "Respawn dialog did not appear after Lyra death animation")
    hunt.combat_view._respawn()
    _check(hunt.combat_view.model.hp == 100 and not hunt.combat_view.death_dialog.visible,
        "Lyra respawn did not restore the combat state cleanly")
    GameState.world_progress_path = original_world
    GameState.surface_progress_path = original_surface
    if failures == 0:
        print("LYRA_RIG_TEST_PASS clips=23 rifle_fire=authored ready=authored death=full_length movement=walk,run menu=ok lab=ok battlefield=ok surface128=ok world=ok")
    tree.quit(0 if failures == 0 else 1)

func _check_combat_facing(zone) -> void:
    zone.set_physics_process(false)
    var view = zone.combat_view
    var model = view.model
    var nav = preload("res://scripts/rts_navigation.gd").new()
    nav.configure(70)
    model.navigation = nav
    zone.hero.position = Vector3(5, 0, -9)
    zone.route.clear()
    for enemy in model.enemies:
        enemy["hp"] = 0.0
    for i in range(2):
        model.enemies[i]["hp"] = 65.0
        model.enemies[i]["stun"] = 10.0
        model.enemies[i]["returning"] = false
    model.enemies[0]["at"] = zone.hero.position + Vector3(0, 0, -3)
    model.enemies[1]["at"] = zone.hero.position + Vector3(3, 0, 0)
    for i in range(2):
        model.enemies[i]["home"] = model.enemies[i]["at"]
    model.attack_target = 0
    model.last_attacker = -1
    model.weapon = 0.0
    zone.hero.rotation.y = 0.0
    view.update_hero_facing()
    _check(absf(angle_difference(zone.heading, PI)) < 0.001, "Stationary Lyra did not face target behind her")
    view.tick(0.01)
    _check(model.enemies[0]["hp"] == 65.0 and is_zero_approx(model.weapon), "Lyra shot backwards before turning")
    model.select_target(1)
    view.update_hero_facing()
    _check(absf(angle_difference(zone.heading, PI / 2)) < 0.001, "Target switch kept stale heading")
    zone.hero.rotation.y = zone.heading
    view.tick(0.01)
    _check(model.enemies[1]["hp"] < 65.0 and model.enemies[0]["hp"] == 65.0, "Turn completion damaged stale target")
    zone.route.append(zone.hero.position + Vector3(0, 0, 2))
    zone.heading = 0.0
    model.weapon = 0.0
    var hp: float = model.enemies[1]["hp"]
    view.update_hero_facing()
    view.tick(0.01)
    _check(is_zero_approx(zone.heading) and model.enemies[1]["hp"] == hp, "Combat facing overrode movement priority")
    zone.route.clear()
    model.attack_target = -1
    model.last_attacker = 0
    view.update_hero_facing()
    _check(absf(angle_difference(zone.heading, PI)) < 0.001, "Return fire did not face aggressor")
    model.enemies[0]["returning"] = true
    zone.heading = 0.4
    view.update_hero_facing()
    _check(is_equal_approx(zone.heading, 0.4), "Retreating target kept driving aim")
    model.hp = 0
    model.enemies[0]["returning"] = false
    view.update_hero_facing()
    _check(is_equal_approx(zone.heading, 0.4), "Dead hero kept tracking target")
