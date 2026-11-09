extends Node
## Godot smoke test: real imported static GLB, tabs, independent profile, back navigation.
const PROFILE_STORE := preload("res://scripts/character_profile_store.gd")
var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(condition: bool, detail: String) -> void:
    if not condition:
        failures += 1
        push_error("AVATAR_EDITOR_TEST_FAIL " + detail)

func _run() -> void:
    var tree := get_tree()
    # Keep the test runner alive while replacing the current editor/menu scenes.
    tree.current_scene = null
    var previous_commander: String = ""
    if FileAccess.file_exists("user://commander_selection.cfg"):
        previous_commander = FileAccess.get_file_as_string("user://commander_selection.cfg")
    var previous_world: String = ""
    if FileAccess.file_exists("user://world/progress-v1.json"):
        previous_world = FileAccess.get_file_as_string("user://world/progress-v1.json")

    tree.change_scene_to_file("res://scenes/character_creator.tscn")
    await tree.scene_changed
    await tree.process_frame
    var editor = tree.current_scene
    _check(editor != null, "editor scene failed")
    if editor == null:
        tree.quit(1)
        return
    _check(editor.avatar_preview.active_model != null, "approved relaxed GLB not imported")
    _check(editor.current_mode == 0, "editor must open in editor tab")
    editor._set_mode(1)
    _check(editor.inventory_panel.visible, "inventory tab not visible")
    _check(editor.avatar_preview.active_model != null, "switching inventory lost GLB")
    editor._set_mode(0)
    _check(editor.editor_panel.visible, "editor tab not restored")

    var temp_file: String = "user://characters/ci-avatar-%d.json" % Time.get_ticks_usec()
    _check(PROFILE_STORE.save_profile("Neko Test", temp_file), "isolated avatar save failed")
    var loaded: Dictionary = PROFILE_STORE.load_profile(temp_file)
    _check(String(loaded.get("name", "")) == "Neko Test", "profile roundtrip failed")
    _check(String(loaded.get("body_base_id", "")) == PROFILE_STORE.BASE_ID, "base asset id changed")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_file))
    if FileAccess.file_exists("user://commander_selection.cfg"):
        _check(previous_commander == FileAccess.get_file_as_string("user://commander_selection.cfg"), "commander selection was changed")
    if FileAccess.file_exists("user://world/progress-v1.json"):
        _check(previous_world == FileAccess.get_file_as_string("user://world/progress-v1.json"), "world progress was changed")

    editor._back_to_menu()
    await tree.scene_changed
    await tree.process_frame
    _check(tree.current_scene != null and tree.current_scene.avatar_button != null, "back navigation lacks main menu link")
    if failures == 0:
        print("NEKO_AVATAR_EDITOR_TEST_PASS")
    tree.quit(0 if failures == 0 else 1)
