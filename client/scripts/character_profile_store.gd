extends RefCounted
## Independent MMO avatar preview profile: never writes RTS commander/world saves.
const PROFILE_PATH := "user://characters/profiles-v1.json"
const BASE_ID := "female_base_v3"

static func load_profile(path: String = PROFILE_PATH) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    if not (data is Dictionary):
        return {}
    var profile: Dictionary = data
    if int(profile.get("schema", -1)) != 1:
        return {}
    if String(profile.get("body_base_id", "")) != BASE_ID:
        return {}
    if not (profile.get("name", "") is String):
        return {}
    return profile

static func save_profile(name: String, path: String = PROFILE_PATH) -> bool:
    var cleaned: String = name.strip_edges()
    if cleaned.is_empty():
        return false
    var directory: String = ProjectSettings.globalize_path(path.get_base_dir())
    if DirAccess.make_dir_recursive_absolute(directory) != OK:
        return false
    var temp_path := path + ".partial"
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify({
        "schema": 1,
        "name": cleaned,
        "race_id": "human",
        "body_base_id": BASE_ID,
        "appearance": {"base_model_id": "female_base_v3_editor_relaxed"}
    }, "  "))
    var error: Error = file.get_error()
    file.close()
    if error != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
        return false
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path)) != OK:
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
        return false
    return true
