extends Node
## Deterministic boss mechanics and real save migrations, including shared hero vitals.

const HUNT := preload("res://scripts/world_hunt.gd")
const COMBAT := preload("res://scripts/world_combat.gd")
const NAV := preload("res://scripts/rts_navigation.gd")
const STORE := preload("res://scripts/world_progress.gd")
const PATH := "user://world-hunt-regression/progress.json"
var failures := 0

class FailedWrite:
    extends "res://scripts/world_progress.gd"
    func _write_temp(_path: String, _value: Dictionary) -> bool:
        return false

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD_HUNT_TEST_FAIL " + message)

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        if FileAccess.file_exists(PATH + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

func _model():
    var nav = NAV.new()
    nav.configure(30)
    var saved := COMBAT.fresh_profile()
    saved["accepted"] = true
    saved["respawns"] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
    var model = HUNT.new()
    model.configure(nav, saved)
    return model

func _blast(model, hero_at: Vector3, step: float = 0.1) -> Dictionary:
    for frame in range(200):
        model.tick(step, hero_at)
        for event in model.take_events():
            if event["type"] == "boss_blast":
                return event
    return {}

func _ready() -> void:
    var standing := Vector3(18, 0, -13)
    var model = _model()
    _check(model.enabled and model.enemies.size() == 9 and model.alive(HUNT.BOSS), "free area is empty before NPC acceptance")
    var boss: Dictionary = model.enemies[HUNT.BOSS]
    boss["blast_cd"] = 0.0
    model.tick(0.1, standing)
    _check(boss["windup"] == 1.4 and boss["blast_at"] == standing and model.hp == 100,
        "boss did not pin a harmless 1.4 second warning to the original ground position")
    _check(model.cast(4, standing, boss["at"])["ok"] and boss["stun"] == 0
        and boss["slow"] == 2 and boss["windup"] > 0, "EMP hard-stunned a boss or canceled its warning")
    var dodged := _blast(model, standing + Vector3(-3.4, 0, 0))
    _check(not dodged.is_empty() and not dodged["hit"] and model.hp == 100, "moving out of the fixed warning still took blast damage")
    for fps in [30, 60, 120]:
        model = _model()
        model.enemies[HUNT.BOSS]["blast_cd"] = 0.0
        var step: float = 1.0 / fps
        model.tick(step, standing)
        var hit := _blast(model, standing, step)
        _check(not hit.is_empty() and hit["hit"] and model.hp == 82,
            "standing in the boss warning did not take one 18 HP hit at " + str(fps))
    model = _model()
    boss = model.enemies[HUNT.BOSS]
    boss["blast_cd"] = 0.0
    model.tick(0.1, standing)
    model.navigation.set_blocked_box(Vector3(18, 0, -16), Vector3(2, 3, 1))
    var blocked := _blast(model, standing)
    _check(not blocked.is_empty() and not blocked["hit"] and model.hp == 100, "boss blast ignored solid cover")
    model = _model()
    boss = model.enemies[HUNT.BOSS]
    boss["blast_cd"] = 0
    model.tick(0.1, standing)
    model.tick(0.1, COMBAT.SAFE_AT)
    _check(boss["windup"] == 0 and not boss["aggro"] and model.hp == 100, "boss warning survived retreat into the safe area")
    boss["at"] = boss["home"]
    boss["returning"] = false
    boss["aggro"] = true
    boss["hp"] = 119
    model.tick(0.1, standing)
    _check(boss["enraged"] and boss["interval"] == 1.5, "low health did not trigger the boss second phase")
    model = _model()
    model._hit(model.enemies[0], 999, "test")
    _check(not model.alive(0) and model.respawns[0] == 45, "ordinary enemy death did not start its timer")
    for frame in range(451):
        model.tick(0.1, Vector3(-11, 0, 14))
    _check(not model.alive(0) and model.respawns[0] == 0, "camp reappeared within ten units of the hero")
    model.tick(0.1, COMBAT.SAFE_AT)
    _check(model.alive(0) and model.enemies[0]["hp"] == model.enemies[0]["max_hp"], "ordinary camp never repopulated after leaving")
    model._hit(model.enemies[HUNT.BOSS], 999, "test")
    _check(model.respawns[HUNT.BOSS] == 120 and model.snapshot()["defeated"] == [HUNT.BOSS], "boss respawn state is wrong")
    _save_roundtrip(model)
    _clean()
    if failures == 0:
        print("WORLD_HUNT_TEST_PASS tells=dodge,hit,cover,safe emp=boss_resist enrage=ok respawn=away_only save=shared,reward_once,legacy,failed_write")
    get_tree().quit(0 if failures == 0 else 1)

func _save_roundtrip(model) -> void:
    _clean()
    var store = STORE.new()
    store.open_profile(PATH, 0, 0)
    # A 0.0.23 hero keeps all old story flags while the new area starts independently.
    store.begin_quest()
    for i in range(3):
        store.activate(i)
    store.claim_reward()
    store.begin_combat()
    var original := COMBAT.fresh_profile()
    original["defeated"] = [0, 1, 2]
    original["hp"] = 61
    original["cooldowns"][0] = 22.5
    store.checkpoint(Vector3(-4, 0, 15), 13, original)
    store.claim_combat_reward()
    var legacy: Dictionary = store.data.duplicate(true)
    legacy["characters"]["amina"].erase("hunt")
    var file := FileAccess.open(PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(legacy))
    file.close()
    _check(store.open_profile(PATH, 0, 0) and store.credits() == 175
        and store.state()["hunt"]["defeated"].is_empty() and store.hunt_combat_state()["hp"] == 61,
        "legacy story or shared vitals changed on migration")
    var snapshot: Dictionary = model.snapshot()
    snapshot["hp"] = 43.0
    snapshot["cooldowns"][0] = 19.0
    _check(store.checkpoint_sector(Vector3(17, 0, -16), 18, snapshot), "boss checkpoint failed")
    var loaded = STORE.new()
    loaded.open_profile(PATH, 0, 0)
    _check(loaded.state()["position"] == [-4.0, 15.0] and loaded.state()["zoom"] == 13
        and loaded.state()["hunt"]["position"] == [17.0, -16.0] and loaded.state()["hunt"]["zoom"] == 18,
        "travel confused the two zone positions or zooms: " + str(loaded.state()))
    _check(loaded.state()["combat"]["defeated"] == [0, 1, 2] and loaded.state()["combat"]["hp"] == 43
        and loaded.state()["combat"]["cooldowns"][0] == 19 and loaded.state()["hunt"]["defeated"] == [HUNT.BOSS]
        and loaded.state()["hunt"]["respawns"][HUNT.BOSS] == 120, "reentry lost kills, frozen spawn timers, shared vitals or old quest")
    for i in range(3):
        loaded.checkpoint_sector(Vector3(17, 0, -16), 18, snapshot)
    _check(loaded.experience() == 450 and loaded.credits() == 325, "boss reward was duplicated or old rewards lost")
    snapshot["defeated"] = []
    snapshot["respawns"][HUNT.BOSS] = 0.0
    loaded.checkpoint_sector(Vector3(17, 0, -16), 18, snapshot)
    _check(loaded.credits() == 325, "boss respawn erased its one-time reward")
    var before := FileAccess.get_file_as_string(PATH)
    var failed := FailedWrite.new()
    failed.open_profile(PATH, 0, 0)
    snapshot["hp"] = 5.0
    _check(not failed.checkpoint_sector(Vector3.ZERO, 16, snapshot) and FileAccess.get_file_as_string(PATH) == before
        and failed.state()["combat"]["hp"] == 43, "failed sector save overwrote committed HP or rewards")
    snapshot["defeated"] = [HUNT.BOSS, HUNT.BOSS]
    _check(not loaded.checkpoint_sector(Vector3.ZERO, 16, snapshot) and FileAccess.get_file_as_string(PATH) == before,
        "invalid duplicate sector IDs overwrote the valid save")
    var other = STORE.new()
    other.open_profile(PATH, 0, 2)
    _check(other.credits() == 0 and not other.hunt_combat_state()["accepted"], "another class inherited the Assault area reward or kit")
