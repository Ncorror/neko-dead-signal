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
        _check(LYRA.hold_ready_pose(p), "Cannot hold ready stance")
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
        lab._hold()
    lab._back()
    await tree.scene_changed
    var again = tree.current_scene
    _check(again.officer_index == 3, "Back navigation changed officer")
    again._deploy()
    await tree.scene_changed
    var battle = tree.current_scene
    _check(battle.hero.get_node_or_null("LyraRig") != null, "Lyra not attached to hero")
    _check(battle.animation_players.has(battle.hero), "RTS rig not animated")
    if battle.animation_players.has(battle.hero):
        var player: AnimationPlayer = battle.animation_players[battle.hero]
        battle._set_unit_animation(battle.hero, true)
        _check(str(player.get_meta("neko_lyra_motion", "")) == "run", "RTS run missing")
        battle._set_unit_animation(battle.hero, false)
        _check(str(player.get_meta("neko_lyra_motion", "")) == "idle", "RTS idle missing")
    _check(battle.hero.hull == 100 and battle.escort.hull == 80, "Combat stats changed")
    if failures == 0:
        print("LYRA_RIG_TEST_PASS clips=20 menu=ok lab=ok battlefield=ok")
    tree.quit(0 if failures == 0 else 1)
