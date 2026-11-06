extends Node
## Real JSON round trips, independent heroes, one-time rewards and recovery.

const STORE := preload("res://scripts/world_progress.gd")
const COMBAT := preload("res://scripts/world_combat.gd")
const TEST_PATH := "user://world-profile-regression/progress.json"
var failures := 0

class FailedWrite:
    extends "res://scripts/world_progress.gd"
    func _write_temp(_path: String, _value: Dictionary) -> bool:
        return false

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD_PROGRESS_TEST_FAIL " + message)

func _clear() -> void:
    for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
        var path := ProjectSettings.globalize_path(TEST_PATH + suffix)
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)

func _combat_roundtrip() -> void:
    _clear()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_PATH).get_base_dir())
    var legacy := {"version": 1, "characters": {"amina": {"accepted": true, "claimed": true,
        "relays": [0, 1, 2], "position": [-18, 13.5], "zoom": 15.8, "camera_preset": 2}}}
    var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(legacy)); file.close()
    var profile = STORE.new()
    _check(profile.open_profile(TEST_PATH, 0, 0) and not profile.state()["combat"]["accepted"]
        and profile.experience() == 100 and profile.credits() == 75, "0.0.22 legacy migration lost the signal quest")
    _check(profile.begin_combat() and not profile.claim_combat_reward(), "combat acceptance or incomplete reward gate failed")
    var snapshot := COMBAT.fresh_profile()
    snapshot["defeated"] = [0]
    snapshot["hp"] = 63.0
    snapshot["cooldowns"] = [33.0, 12.0, 0.0, 7.0, 0.0]
    snapshot["launcher"] = 1.2
    snapshot["protocol"] = 3.0
    snapshot["weapon"] = 0.7
    _check(profile.checkpoint(Vector3(4, 0, -8), 14.5, snapshot), "combat checkpoint failed")
    var reload = STORE.new()
    _check(reload.open_profile(TEST_PATH, 0, 0) and reload.state()["combat"]["defeated"] == [0]
        and reload.state()["combat"]["hp"] == 63 and reload.state()["combat"]["cooldowns"] == snapshot["cooldowns"]
        and reload.state()["combat"]["launcher"] == 1.2 and reload.credits() == 75,
        "reload reset health, cooldowns, launcher delay or one-time targets")
    var before := FileAccess.get_file_as_string(TEST_PATH)
    var failing := FailedWrite.new()
    failing.open_profile(TEST_PATH, 0, 0)
    snapshot["hp"] = 20.0
    _check(not failing.checkpoint(Vector3(4, 0, -8), 14.5, snapshot)
        and failing.state()["combat"]["hp"] == 63 and FileAccess.get_file_as_string(TEST_PATH) == before,
        "failed combat write changed the committed state")
    snapshot["defeated"] = [0, 0]
    _check(not reload.checkpoint(Vector3.ZERO, 16, snapshot) and FileAccess.get_file_as_string(TEST_PATH) == before,
        "invalid duplicate kill checkpoint overwrote the save")
    snapshot["defeated"] = [0, 1, 2]
    snapshot["hp"] = 0.0
    _check(reload.checkpoint(Vector3(4, 0, -8), 14.5, snapshot), "death checkpoint did not persist")
    for repeat in range(4):
        _check(reload.claim_combat_reward(), "idempotent combat reward failed")
    _check(reload.experience() == 250 and reload.credits() == 175, "combat reward duplicated or erased the first reward")
    var other = STORE.new()
    _check(other.open_profile(TEST_PATH, 0, 2) and not other.begin_combat()
        and not other.state()["combat"]["accepted"] and other.credits() == 0, "another hero inherited Amina's class/progress")
    var dead = STORE.new()
    dead.open_profile(TEST_PATH, 0, 0)
    _check(dead.state()["combat"]["hp"] == 0 and dead.state()["combat"]["cooldowns"][0] == 33
        and dead.credits() == 175, "reopening a dead profile healed it or cleared cooldowns")
    _clear()

func _ready() -> void:
    _clear()
    var profile = STORE.new()
    _check(profile.open_profile(TEST_PATH, 0, 0) and not profile.state()["accepted"], "fresh profile failed")
    _check(not profile.activate(0) and not profile.claim_reward(), "unaccepted quest granted progress or a reward")
    _check(profile.begin_quest(), "quest could not be accepted")
    _check(profile.activate(0) and profile.activate(0) and profile.state()["relays"].size() == 1, "duplicate activation changed the count")
    _check(not profile.claim_reward() and not profile.activate(9), "incomplete quest or invalid relay was accepted")
    var position := Vector3(-5.25, 0, 17.75)
    _check(profile.checkpoint(position, 12.5), "position checkpoint failed")
    var reloaded = STORE.new()
    _check(reloaded.open_profile(TEST_PATH, 0, 0) and reloaded.state()["relays"] == [0]
        and reloaded.state()["position"] == [-5.25, 17.75] and reloaded.state()["zoom"] == 12.5,
        "app-style reload lost quest, exact position or zoom: " + str(reloaded.state()))
    _check(reloaded.activate(0) and reloaded.state()["relays"] == [0], "reload made an activated relay collectible twice")
    _check(reloaded.activate(1) and reloaded.activate(2) and reloaded.claim_reward(), "quest could not be completed")
    for attempt in range(4):
        _check(reloaded.claim_reward(), "idempotent reward claim was rejected")
    _check(reloaded.experience() == 100 and reloaded.credits() == 75, "reward was duplicated")
    var other = STORE.new()
    _check(other.open_profile(TEST_PATH, 0, 2) and other.character_id == "mira_kade"
        and not other.state()["accepted"] and other.experience() == 0, "another hero inherited the first hero's quest")
    _check(other.begin_quest(), "second character could not save")
    var saari = STORE.new()
    _check(saari.open_profile(TEST_PATH, 1, 0) and saari.character_id == "saira_nel" and saari.credits() == 0,
        "Saari identity or reward isolation failed")
    _check(reloaded.open_profile(TEST_PATH, 0, 0) and reloaded.state()["claimed"] and reloaded.credits() == 75,
        "saving another hero erased the first hero")
    var copy: Dictionary = reloaded.state()
    copy["relays"].clear()
    _check(reloaded.state()["relays"].size() == 3, "caller mutated live profile state")
    var before := FileAccess.get_file_as_string(TEST_PATH)
    var failing := FailedWrite.new()
    failing.open_profile(TEST_PATH, 0, 0)
    _check(not failing.checkpoint(Vector3(4, 0, 7), 20) and FileAccess.get_file_as_string(TEST_PATH) == before
        and failing.state()["position"] == [-5.25, 17.75] and not failing.error_text.is_empty(),
        "failed write changed the on-disk or in-memory checkpoint")
    _check(not reloaded.checkpoint(Vector3(300, 0, 0), 20), "out-of-zone save was accepted")
    # The last valid snapshot remains usable if the newest JSON is damaged.
    var damaged := FileAccess.open(TEST_PATH, FileAccess.WRITE)
    damaged.store_string("{broken"); damaged.close()
    var recovered = STORE.new()
    _check(recovered.open_profile(TEST_PATH, 0, 0) and recovered.recovered and recovered.state()["claimed"],
        "valid backup was not recovered")
    _check(recovered.checkpoint(Vector3(2, 0, 3), 18), "recovered profile could not resume saving")
    var again = STORE.new()
    _check(again.open_profile(TEST_PATH, 0, 0) and not again.recovered and again.credits() == 75,
        "recovered state was not written as a valid primary file")
    for suffix in ["", ".bak"]:
        var file := FileAccess.open(TEST_PATH + suffix, FileAccess.WRITE)
        file.store_string("[]"); file.close()
    var invalid = STORE.new()
    _check(not invalid.open_profile(TEST_PATH, 0, 0) and not invalid.begin_quest()
        and FileAccess.get_file_as_string(TEST_PATH) == "[]" and not invalid.error_text.is_empty(),
        "two invalid saves were silently replaced")
    _clear()
    _combat_roundtrip()
    if failures == 0:
        print("WORLD_PROGRESS_TEST_PASS disk=real reload=ok heroes=isolated reward=once failed_write=preserved backup=ok corrupt=preserved combat=migrated,hp,cooldowns,death,reward_once")
    get_tree().quit(0 if failures == 0 else 1)
