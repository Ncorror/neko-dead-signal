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
    GameState.set_selection(0, 3, "Люди — флот «Рэйна»", "Лира Восс — снайпер")
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
            var rifle_at: Vector3 = model.to_local(rifle_node.global_position)
            _check(absf(rifle_at.x) < 0.30 and rifle_at.y > 0.55 and rifle_at.y < 1.40 and rifle_at.z < -0.02 and rifle_at.z > -0.20,
                "Rifle is not close to Lyra back: " + str(rifle_at))
        if rifle_mount != null:
            _check(str(rifle_mount.bone_name).to_lower().ends_with("spine2"), "Rifle did not start stowed on Spine2")
            var attack_time := LYRA.play_attack(p)
            _check(attack_time > 0 and str(rifle_mount.bone_name).to_lower().ends_with("righthand")
                and str(p.get_meta("neko_lyra_motion", "")) == "attack", "Attack did not move rifle into Lyra hand")
            _check(LYRA.restore_ready(p) and str(rifle_mount.bone_name).to_lower().ends_with("spine2"),
                "Attack did not restore rifle to Lyra back")
            var death_time := LYRA.play_death(p)
            _check(death_time >= 0.8 and str(p.get_meta("neko_lyra_motion", "")) == "death", "Death animation was not started")
            _check(LYRA.restore_ready(p), "Death pose could not return to ready state")
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
    tree.change_scene_to_file("res://scenes/lyra_animation_lab.tscn")
    await tree.scene_changed
    for i in range(10):
        await tree.process_frame
    var lab = tree.current_scene
    _check(lab.player != null and lab.entries.get_child_count() == 20, "Lab not ready")
    if lab.player != null:
        lab._play("Standing_Reload")
        _check(lab.status.text.contains("Standing_Reload"), "Play clip failed")
        lab._play("Roll_Dodge_1")
        lab.player.seek(0.5, true)
        var root_offset: Vector3 = LYRA.root_motion_offset(lab.player)
        lab._process(0.0)
        if Vector2(root_offset.x, root_offset.z).length() > 0.05:
            _check(lab.model_view.active_model.position.distance_to(lab.preview_origin) > 0.001,
                "Animation lab did not cancel horizontal root travel")
        lab._hold()
        _check(lab.model_view.active_model.position.distance_to(lab.preview_origin) < 0.001,
            "Animation lab failed to recenter neutral stance")
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
        print("LYRA_RIG_TEST_PASS clips=20 stable_stance=ok rifle=hand,back death=animated movement=walk,run menu=ok lab=ok battlefield=ok surface128=ok world=ok")
    tree.quit(0 if failures == 0 else 1)
