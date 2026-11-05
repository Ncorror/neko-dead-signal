extends RefCounted
## Local vertical-slice progress. Never reads or credits the RTS operation wallet.

const DEFAULT_PATH := "user://world/progress-v1.json"
const SCHEMA := 1
const REWARD_XP := 100
const REWARD_CREDITS := 75
const SPAWN := Vector3(-18, 0, 18)
const CHARACTER_IDS := [["amina", "reina", "mira_kade", "lyra_voss"], ["saira_nel", "oralin"]]

var file_path := DEFAULT_PATH
var character_id := "amina"
var data: Dictionary = {"version": SCHEMA, "characters": {}}
var _committed: Dictionary = {}
var writable := true
var recovered := false
var error_text := ""

func open_profile(path: String, faction: int, officer: int) -> bool:
    file_path = path
    character_id = CHARACTER_IDS[clampi(faction, 0, 1)][clampi(officer, 0, 3 if faction == 0 else 1)]
    writable = true
    recovered = false
    error_text = ""
    var loaded: Variant = _read(file_path)
    if loaded == null and (FileAccess.file_exists(file_path) or FileAccess.file_exists(file_path + ".bak")):
        loaded = _read(file_path + ".bak")
        recovered = loaded != null
        if loaded == null:
            writable = false
            error_text = "Не удалось прочитать прогресс. Файлы сохранены; вернись на корабль."
    data = loaded if loaded != null else {"version": SCHEMA, "characters": {}}
    _committed = data.duplicate(true)
    return writable

func state() -> Dictionary:
    return data["characters"].get(character_id, {
        "accepted": false, "relays": [], "claimed": false,
        "position": [SPAWN.x, SPAWN.z], "zoom": 20.0}).duplicate(true)

func _valid(root: Variant) -> bool:
    if not root is Dictionary or root.get("version") != SCHEMA or not root.get("characters") is Dictionary:
        return false
    for key in root["characters"]:
        if not CHARACTER_IDS[0].has(key) and not CHARACTER_IDS[1].has(key):
            return false
        var item: Variant = root["characters"][key]
        if not item is Dictionary:
            return false
        for flag in ["accepted", "claimed"]:
            if not item.get(flag) is bool:
                return false
        if not item.get("relays") is Array or not item.get("position") is Array or item["position"].size() != 2:
            return false
        var seen: Array = []
        for relay in item["relays"]:
            if not (relay is int or relay is float) or relay != int(relay) or relay < 0 or relay > 2 or seen.has(int(relay)):
                return false
            seen.append(int(relay))
        if (not item["accepted"] and not seen.is_empty()) or (item["claimed"] and (not item["accepted"] or seen.size() != 3)):
            return false
        for coordinate in item["position"]:
            if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or absf(float(coordinate)) > 30.0:
                return false
        var zoom: Variant = item.get("zoom")
        if not (zoom is float or zoom is int) or not is_finite(float(zoom)) or zoom < 8 or zoom > 30:
            return false
    return true

func _read(path: String) -> Variant:
    if not FileAccess.file_exists(path):
        return null
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null or file.get_length() > 65536:
        return null
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK or not _valid(parser.data):
        return null
    # JSON numbers load as floats. Canonical integer IDs keep Array.has and
    # duplicate checks identical before and after a process restart.
    parser.data["version"] = SCHEMA
    for item in parser.data["characters"].values():
        var ids: Array = []
        for relay in item["relays"]:
            ids.append(int(relay))
        item["relays"] = ids
    return parser.data

func _write_temp(path: String, value: Dictionary) -> bool:
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(value))
    file.flush()
    var ok := file.get_error() == OK
    file.close()
    return ok and _read(path) != null

func _commit(next: Dictionary) -> bool:
    if not writable:
        return false
    var replacement := data.duplicate(true)
    replacement["characters"][character_id] = next
    var folder := ProjectSettings.globalize_path(file_path).get_base_dir()
    var ok := _valid(replacement) and DirAccess.make_dir_recursive_absolute(folder) == OK
    if ok:
        ok = _write_temp(file_path + ".tmp", replacement)
    if ok:
        ok = _write_temp(file_path + ".bak.tmp", _committed)
    if ok:
        ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(file_path + ".bak.tmp"), ProjectSettings.globalize_path(file_path + ".bak")) == OK
    if ok:
        ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(file_path + ".tmp"), ProjectSettings.globalize_path(file_path)) == OK
    if not ok:
        error_text = "Не удалось сохранить прогресс. Проверь свободное место и попробуй снова."
        return false
    data = replacement
    _committed = data.duplicate(true)
    error_text = ""
    return true

func begin_quest() -> bool:
    var next := state()
    if next["accepted"]:
        return true
    next["accepted"] = true
    return _commit(next)

func activate(relay: int) -> bool:
    var next := state()
    if not next["accepted"] or relay < 0 or relay > 2:
        return false
    if next["relays"].has(relay):
        return true
    next["relays"].append(relay)
    return _commit(next)

func claim_reward() -> bool:
    var next := state()
    if not next["accepted"] or next["relays"].size() != 3:
        return false
    if next["claimed"]:
        return true
    next["claimed"] = true
    return _commit(next)

func checkpoint(point: Vector3, zoom: float) -> bool:
    var next := state()
    var coordinates := [point.x, point.z]
    if next["position"] == coordinates and is_equal_approx(float(next["zoom"]), zoom):
        return true
    next["position"] = coordinates
    next["zoom"] = zoom
    return _commit(next)

func experience() -> int:
    return REWARD_XP if state()["claimed"] else 0

func credits() -> int:
    return REWARD_CREDITS if state()["claimed"] else 0
