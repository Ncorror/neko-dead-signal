extends RefCounted
## Local vertical-slice progress. Never reads or credits the RTS operation wallet.

const DEFAULT_PATH := "user://world/progress-v1.json"
const SCHEMA := 1
const CAMERA_PRESET := 2
const DEFAULT_ZOOM := 16.0
const REWARD_XP := 100
const REWARD_CREDITS := 75
const SPAWN := Vector3(-18, 0, 18)
const CHARACTER_IDS := [["amina", "reina", "mira_kade", "lyra_voss"], ["saira_nel", "oralin"]]
const COMBAT := preload("res://scripts/world_combat.gd")
const HUNT := preload("res://scripts/world_hunt.gd")
const COMBAT_XP := 150
const COMBAT_CREDITS := 100
const BOSS_XP := 200
const BOSS_CREDITS := 150

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
            error_text = "Не удалось прочитать прогресс. Файлы сохранены; вернись на базу."
    data = loaded if loaded != null else {"version": SCHEMA, "characters": {}}
    _committed = data.duplicate(true)
    return writable

func state() -> Dictionary:
    var result: Dictionary = data["characters"].get(character_id, {
        "accepted": false, "relays": [], "claimed": false,
        "position": [SPAWN.x, SPAWN.z], "zoom": DEFAULT_ZOOM, "camera_preset": CAMERA_PRESET}).duplicate(true)
    if not result.has("combat"):
        result["combat"] = COMBAT.fresh_profile()
    if not result.has("hunt"):
        result["hunt"] = {"defeated": [], "respawns": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
            "claimed": false, "position": [SPAWN.x, SPAWN.z], "zoom": DEFAULT_ZOOM}
    return result

func hunt_combat_state() -> Dictionary:
    var saved := state()
    var result: Dictionary = saved["combat"].duplicate(true)
    result["accepted"] = character_id in ["amina", "lyra_voss"]
    result["defeated"] = saved["hunt"]["defeated"].duplicate()
    result["respawns"] = saved["hunt"]["respawns"].duplicate()
    return result

func _valid_hunt(value: Variant) -> bool:
    if not value is Dictionary or not value.get("claimed") is bool or not value.get("defeated") is Array:
        return false
    if not value.get("respawns") is Array or value["respawns"].size() != HUNT.COUNT:
        return false
    if not value.get("position") is Array or value["position"].size() != 2:
        return false
    var ids: Array = []
    for id in value["defeated"]:
        if not (id is int or id is float) or id != int(id) or id < 0 or id >= HUNT.COUNT or ids.has(int(id)):
            return false
        ids.append(int(id))
    for i in range(HUNT.COUNT):
        var timer: Variant = value["respawns"][i]
        var maximum: float = HUNT.BOSS_RESPAWN_SECONDS if i == HUNT.BOSS else HUNT.RESPAWN_SECONDS
        if not (timer is int or timer is float) or not is_finite(float(timer)) or timer < 0 or timer > maximum + 0.001:
            return false
        if not ids.has(i) and timer > 0:
            return false
    for coordinate in value["position"]:
        if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or absf(coordinate) > 30:
            return false
    var scale: Variant = value.get("zoom")
    return (scale is int or scale is float) and is_finite(float(scale)) and scale >= 8 and scale <= 30

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
        var preset: Variant = item.get("camera_preset", 1)
        if not (preset is int or preset is float) or preset != int(preset) or int(preset) not in [1, CAMERA_PRESET]:
            return false
        if item.has("combat"):
            if not COMBAT.valid_profile(item["combat"]) or (item["combat"]["accepted"] and (key != "amina" or not item["claimed"])):
                return false
        if item.has("hunt") and not _valid_hunt(item["hunt"]):
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
        item["camera_preset"] = int(item.get("camera_preset", 1))
        if item.has("combat"):
            var defeated: Array = []
            for id in item["combat"]["defeated"]:
                defeated.append(int(id))
            item["combat"]["defeated"] = defeated
        if item.has("hunt"):
            var hunt_ids: Array = []
            for id in item["hunt"]["defeated"]:
                hunt_ids.append(int(id))
            item["hunt"]["defeated"] = hunt_ids
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

func begin_combat() -> bool:
    var next := state()
    if character_id != "amina" or not next["claimed"]:
        return false
    if next["combat"]["accepted"]:
        return true
    next["combat"]["accepted"] = true
    return _commit(next)

func claim_combat_reward() -> bool:
    var next := state()
    if not next["combat"]["accepted"] or next["combat"]["defeated"].size() != 3:
        return false
    if next["combat"]["claimed"]:
        return true
    next["combat"]["claimed"] = true
    return _commit(next)

func checkpoint(point: Vector3, zoom: float, combat: Dictionary = {}) -> bool:
    var next := state()
    var coordinates := [point.x, point.z]
    next["position"] = coordinates
    next["zoom"] = zoom
    next["camera_preset"] = CAMERA_PRESET
    if not combat.is_empty():
        for key in ["defeated", "hp", "cooldowns", "launcher", "protocol", "weapon"]:
            if not combat.has(key):
                return false
            next["combat"][key] = combat[key]
    if data["characters"].get(character_id, {}) == next:
        return true
    return _commit(next)

func experience() -> int:
    return (REWARD_XP if state()["claimed"] else 0) + (COMBAT_XP if state()["combat"]["claimed"] else 0) + (BOSS_XP if state()["hunt"]["claimed"] else 0)

func credits() -> int:
    return (REWARD_CREDITS if state()["claimed"] else 0) + (COMBAT_CREDITS if state()["combat"]["claimed"] else 0) + (BOSS_CREDITS if state()["hunt"]["claimed"] else 0)

func checkpoint_sector(point: Vector3, scale: float, combat: Dictionary) -> bool:
    if character_id not in ["amina", "lyra_voss"]:
        return false
    var next := state()
    for key in ["hp", "cooldowns", "launcher", "protocol", "weapon"]:
        if not combat.has(key):
            return false
        next["combat"][key] = combat[key]
    for key in ["defeated", "respawns"]:
        if not combat.has(key):
            return false
        next["hunt"][key] = combat[key]
    next["hunt"]["position"] = [point.x, point.z]
    next["hunt"]["zoom"] = scale
    next["hunt"]["claimed"] = next["hunt"]["claimed"] or combat["defeated"].has(HUNT.BOSS)
    if data["characters"].get(character_id, {}) == next:
        return true
    return _commit(next)
