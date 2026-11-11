extends Node
## Numerical PvE contracts, obstruction, response fire, control, death and clocks.

const COMBAT := preload("res://scripts/world_combat.gd")
const NAV := preload("res://scripts/rts_navigation.gd")
var failures := 0

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("WORLD_COMBAT_TEST_FAIL " + message)

func _fresh():
    var nav = NAV.new()
    nav.configure(30)
    var saved := COMBAT.fresh_profile()
    saved["accepted"] = true
    var model = COMBAT.new()
    model.configure(nav, saved)
    return model

func _advance(model, seconds: float, at: Vector3, fps: int = 60) -> void:
    for frame in range(ceili(seconds * fps)):
        model.tick(1.0 / fps, at)

func _ready() -> void:
    var at := Vector3(5, 0, -9)
    var model = _fresh()
    model.enemies[1]["hp"] = 0
    model.enemies[2]["hp"] = 0
    model.tick(1.0 / 60, at)
    _check(model.hp == 97 and model.enemies[0]["hp"] < 65 and model.attack_target == -1,
        "first incoming hit did not trigger automatic response fire")
    var hp: float = model.enemies[0]["hp"]
    for frame in range(90):
        model.tick(1.0 / 60, at + Vector3(frame * 0.002, 0, 0))
    _check(model.enemies[0]["hp"] < hp, "response fire stopped while the hero moved")

    # Lyra is a planted sniper: movement blocks the shot entirely.
    model = _fresh()
    model.set_profile("lyra_voss")
    model.enemies[1]["hp"] = 0
    model.enemies[2]["hp"] = 0
    model.select_target(0)
    hp = model.enemies[0]["hp"]
    model.tick(1.0 / 60, at, false)
    _check(model.enemies[0]["hp"] == hp, "Lyra fired while movement gate was closed")
    model.tick(1.0 / 60, at, true)
    _check(model.enemies[0]["hp"] < hp, "Stationary Lyra failed to fire inside sniper range")
    var shot_events := model.take_events().filter(func(e): return e["type"] == "hero_shot")
    _check(shot_events.size() == 1 and float(shot_events[0]["distance"]) <= 16.0 and float(shot_events[0]["hp_after"]) < hp,
        "Lyra shot event is not tied to a real in-range damage result")

    # Retaliation can change targets during enemy simulation, after the view
    # checked facing. Do not reuse that authorization for a different enemy.
    model = _fresh()
    model.set_profile("lyra_voss")
    model.enemies[2]["hp"] = 0
    model.last_attacker = 0
    model.enemies[0]["shot"] = 5.0
    model.enemies[1]["at"] = at + Vector3(2, 0, 0)
    model.enemies[1]["home"] = model.enemies[1]["at"]
    model.tick(0.01, at, true, 0)
    _check(model.last_attacker == 1 and is_zero_approx(model.weapon)
        and not model.take_events().any(func(e): return e["type"] == "hero_shot"),
        "Facing authorization leaked to a new aggressor in the same tick")

    model = _fresh()
    model.set_profile("lyra_voss")
    model.enemies[0]["at"] = Vector3(25, 0, -14)
    model.select_target(0)
    hp = model.enemies[0]["hp"]
    model.tick(1.0 / 60, at, true)
    var far_events := model.take_events()
    _check(model.enemies[0]["hp"] == hp and not far_events.any(func(e): return e["type"] == "hero_shot"),
        "Lyra emitted a shot outside 16-unit range")

    model = _fresh()
    model.navigation.set_blocked_box(Vector3(5, 0, -11.5), Vector3(4, 3, 1), 0.5)
    model.select_target(0)
    model.tick(1.0 / 60, at)
    _check(model.hp == 100 and model.enemies[0]["hp"] == 65, "weapon fired through cover")
    var blocked: Dictionary = model.cast(1, at, model.enemies[0]["at"])
    _check(not blocked["ok"] and model.cooldowns[1] == 0 and model.launcher == 0, "obstructed grenade consumed an action")
    _check(not model.cast(1, Vector3(20, 0, 20), Vector3.ZERO)["ok"], "out-of-range grenade was accepted")

    model = _fresh()
    var centre: Vector3 = model.enemies[0]["at"]
    model.enemies[1]["at"] = centre + Vector3(2.5, 0, 0)
    model.enemies[2]["at"] = centre + Vector3(6, 0, 0)
    _check(model.cast(0, at, at)["ok"] and model.protocol == 10, "assault protocol failed")
    _check(model.cast(1, at, centre)["ok"], "fragmentation grenade failed")
    _check(is_equal_approx(model.enemies[0]["hp"], 65 - 12 * 1.4 * 0.9)
        and is_equal_approx(model.enemies[1]["hp"], 65 - 12 * 1.4 * 0.5 * 0.9),
        "fragmentation falloff, no same-hit weakening, or no double protocol bonus failed")
    _check(model.enemies[2]["hp"] == 120 and model.enemies[0]["weak"] == 4,
        "grenade range or armour-weakening duration failed")
    _check(not model.cast(2, at, centre)["ok"] and model.cooldowns[2] == 0, "shared launcher delay was bypassed")
    hp = model.enemies[0]["hp"]
    model.select_target(0)
    model.tick(1.0 / 60, at)
    _check(is_equal_approx(hp - model.enemies[0]["hp"], 12 * 1.12 * 0.91),
        "later weapon hit did not use the 12% protocol and 10% armour weakening")

    model = _fresh()
    at = Vector3(7, 0, -11)
    _check(model.cast(0, at, at)["ok"] and model.cast(2, at, model.enemies[2]["at"])["ok"], "anti-vehicle grenade failed")
    _check(is_equal_approx(model.enemies[2]["hp"], 120 - 12 * 3 * 0.7)
        and model.enemies[0]["hp"] == 65 and model.enemies[1]["hp"] == 65, "HEAT damage or single-target scope failed")
    model = _fresh()
    _check(model.cast(2, Vector3(5, 0, -9), model.enemies[0]["at"])["ok"]
        and is_equal_approx(model.enemies[0]["hp"], 65 - 12 * 0.9), "HEAT incorrectly tripled damage against people")

    model = _fresh()
    centre = Vector3(7, 0, -15)
    _check(model.cast(4, Vector3(7, 0, -8), centre)["ok"], "pulse grenade failed")
    for i in range(3):
        var enemy: Dictionary = model.enemies[i]
        _check(enemy["hp"] < enemy["max_hp"] and enemy["stun"] == 0.7 and enemy["slow"] == 2,
            "pulse did not damage/control an ordinary target type: " + str(i))
    _check(not model.cast(1, at, centre)["ok"] and model.cooldowns[1] == 0, "pulse skipped shared launcher lock")
    _advance(model, 1.3, Vector3(25, 0, 25))
    _check(model.launcher == 0 and model.cooldowns[4] > 26 and model.cooldowns[1] == 0,
        "grenades incorrectly share a long cooldown")

    model = _fresh()
    var dash: Dictionary = model.cast(3, Vector3.ZERO, Vector3(20, 0, 0))
    _check(dash["ok"] and is_equal_approx(dash["at"].length(), 3.5), "dash distance was not clamped")
    model = _fresh()
    model.navigation.set_blocked_box(Vector3(2, 0, 0), Vector3(1, 3, 4), 0.3)
    _check(not model.cast(3, Vector3.ZERO, Vector3(20, 0, 0))["ok"] and model.cooldowns[3] == 0,
        "dash crossed a footprint or charged cooldown for a rejected move")
    _check(not model.cast(3, Vector3.ZERO, Vector3(NAN, 0, 0))["ok"], "non-finite skill coordinates accepted")

    model = _fresh()
    _advance(model, 20, COMBAT.SAFE_AT)
    _check(model.hp == 100 and not model.enemies[0]["aggro"], "safe area aggroed enemies")
    _check(not model.cast(1, COMBAT.SAFE_AT, model.enemies[0]["at"])["ok"], "safe-area firing was allowed")
    model.enemies[0]["aggro"] = true
    model.enemies[0]["at"] += Vector3(3, 0, 0)
    model.enemies[0]["hp"] = 10
    model.enemies[1]["hp"] = 0
    _advance(model, 4, COMBAT.SAFE_AT)
    _check(model.enemies[0]["at"].is_equal_approx(model.enemies[0]["home"])
        and model.enemies[0]["hp"] == 65 and not model.enemies[0]["aggro"] and model.enemies[1]["hp"] == 0,
        "leash failed, or dead enemies were resurrected")

    model = _fresh()
    model.hp = 1
    model.cooldowns[0] = 40
    model.tick(1.0 / 60, Vector3(5, 0, -9))
    var before: float = model.cooldowns[0]
    _check(model.hp == 0 and not model.cast(3, at, Vector3.ZERO)["ok"], "dead hero could use a skill")
    _check(model.respawn() and model.hp == 100 and model.cooldowns[0] == before and not model.respawn(),
        "respawn reset cooldowns or was repeatable while alive")
    for fps in [30, 60, 120]:
        model = _fresh()
        model.cast(0, COMBAT.SAFE_AT, COMBAT.SAFE_AT)
        _advance(model, 10, COMBAT.SAFE_AT, fps)
        _check(absf(model.cooldowns[0] - 40) < 0.001 and model.protocol < 0.001,
            "skill timer changed with simulation frame rate: " + str(fps))
    var invalid := COMBAT.fresh_profile()
    invalid["hp"] = NAN
    _check(not COMBAT.valid_profile(invalid), "save validator accepted NaN health")
    invalid = COMBAT.fresh_profile()
    invalid["accepted"] = true
    invalid["defeated"] = [0, 0]
    _check(not COMBAT.valid_profile(invalid), "duplicate defeated IDs were accepted")
    if failures == 0:
        print("WORLD_COMBAT_TEST_PASS auto_reply=moving lyra=planted,range16 los=ok skills=5 passive=1 damage=PvE launcher=shared dash=blocked leash=safe death=ok fps=30,60,120")
    get_tree().quit(0 if failures == 0 else 1)
