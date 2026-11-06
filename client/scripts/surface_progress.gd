extends RefCounted
## Separate prototype profile: no migration, import or writes to the existing world save.

const TERRAIN := preload("res://scripts/surface_terrain.gd")
const IDS := ["amina", "reina", "mira_kade", "lyra_voss", "saira_nel", "oralin"]
const DEFAULT_PATH := "user://surface/sector01-v1.json"
var path := DEFAULT_PATH
var character := "amina"
var data: Dictionary = {"schema": "surface128-v1", "characters": {}}
var writable := true
var recovered := false
var error_text := ""

func state() -> Dictionary:
    return data["characters"].get(character, {"position": [TERRAIN.SPAWN.x, TERRAIN.SPAWN.z],
        "zoom": 16.0, "visited": []}).duplicate(true)

func valid(root: Variant) -> bool:
    if not root is Dictionary or root.get("schema") != "surface128-v1" or not root.get("characters") is Dictionary:
        return false
    for id in root["characters"]:
        if id not in IDS:
            return false
        var item: Variant = root["characters"][id]
        if not item is Dictionary or not item.get("position") is Array or item["position"].size() != 2 or not item.get("visited") is Array:
            return false
        for coordinate in item["position"]:
            if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or absf(coordinate) > TERRAIN.PLAY_LIMIT:
                return false
        var zoom: Variant = item.get("zoom")
        if not (zoom is int or zoom is float) or not is_finite(float(zoom)) or zoom < 8 or zoom > 30:
            return false
        var seen: Array = []
        for site in item["visited"]:
            if not (site is int or site is float) or site != int(site) or site < 0 or site >= TERRAIN.SITES.size() or seen.has(int(site)):
                return false
            seen.append(int(site))
    return true

func _read(file_path: String) -> Variant:
    if not FileAccess.file_exists(file_path):
        return null
    var file := FileAccess.open(file_path, FileAccess.READ)
    if file == null or file.get_length() > 32768:
        return null
    var json := JSON.new()
    if json.parse(file.get_as_text()) != OK or not valid(json.data):
        return null
    for item in json.data["characters"].values():
        var ids: Array = []
        for site in item["visited"]:
            ids.append(int(site))
        item["visited"] = ids
    return json.data

func open_profile(file_path: String, id: String) -> bool:
    path = file_path
    character = id if id in IDS else IDS[0]
    writable = true
    recovered = false
    error_text = ""
    var loaded: Variant = _read(path)
    if loaded == null and (FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")):
        loaded = _read(path + ".bak")
        recovered = loaded != null
        if loaded == null:
            writable = false
            error_text = "Прогресс новой локации повреждён. Файлы сохранены; запись отключена."
    data = loaded if loaded != null else {"schema": "surface128-v1", "characters": {}}
    return writable

func _write(file_path: String, value: Dictionary) -> bool:
    var file := FileAccess.open(file_path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(value, "", true, true))
    file.flush()
    var ok := file.get_error() == OK
    file.close()
    return ok and _read(file_path) != null

func checkpoint(at: Vector3, zoom: float, visited: Array) -> bool:
    if not writable:
        return false
    var next := data.duplicate(true)
    next["characters"][character] = {"position": [at.x, at.z], "zoom": zoom, "visited": visited.duplicate()}
    if next == data:
        return true
    var ok := valid(next) and DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir()) == OK
    if ok:
        ok = _write(path + ".tmp", next) and _write(path + ".bak.tmp", data)
    if ok:
        ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".bak.tmp"), ProjectSettings.globalize_path(path + ".bak")) == OK
    if ok:
        ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK
    if not ok:
        error_text = "Не удалось сохранить новую локацию. Проверь свободное место."
        return false
    data = next
    error_text = ""
    return true
