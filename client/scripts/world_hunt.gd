extends "res://scripts/world_combat.gd"
## Rust Road encounters. Cooldowns/HP are shared with the hero; spawn timers are local.

const BOSS := 8
const COUNT := 9
const RESPAWN_SECONDS := 45.0
const BOSS_RESPAWN_SECONDS := 120.0
const BLAST_RADIUS := 2.8
const BLAST_DAMAGE := 18.0
var respawns: Array = []

func enemy_specs() -> Array[Dictionary]:
    var specs: Array[Dictionary] = []
    var positions := [Vector3(-11, 0, 5), Vector3(-7, 0, 4), Vector3(-10, 0, 1),
        Vector3(10, 0, 3), Vector3(13, 0, 2), Vector3(11, 0, -1),
        Vector3(0, 0, -12), Vector3(3, 0, -13), Vector3(18, 0, -19)]
    for i in range(COUNT):
        var machine := i >= 6
        var boss := i == BOSS
        specs.append({"home": positions[i], "name": "СТРАЖ УЗЛА" if boss else ("ДРОН %d" % (i - 5) if machine else "МАРОДЁР %d" % (i + 1)),
            "max_hp": 300.0 if boss else (85.0 if machine else (50.0 if i < 3 else 65.0)),
            "vehicle": machine, "armor": 0.25 if machine else 0.1,
            "damage": 5.0 if boss else (3.0 if i >= 3 else 2.5), "interval": 2.2 if boss else 1.8,
            "boss": boss, "windup": 0.0, "blast_at": Vector3.ZERO, "blast_cd": 3.0, "enraged": false})
    return specs

func configure(nav, saved: Dictionary) -> void:
    super.configure(nav, saved)
    respawns = saved["respawns"].duplicate()

func snapshot() -> Dictionary:
    var result := super.snapshot()
    result["respawns"] = respawns.duplicate()
    return result

func _hit(enemy: Dictionary, raw: float, source: String) -> void:
    super._hit(enemy, raw, source)
    if enemy["hp"] <= 0:
        respawns[enemy["id"]] = BOSS_RESPAWN_SECONDS if enemy["boss"] else RESPAWN_SECONDS
        enemy["windup"] = 0.0

func _retreat(enemy: Dictionary, delta: float) -> void:
    enemy["windup"] = 0.0
    enemy["blast_cd"] = 3.0
    enemy["enraged"] = false
    enemy["interval"] = 2.2 if enemy["boss"] else 1.8
    super._retreat(enemy, delta)

func _special_attack(enemy: Dictionary, delta: float, hero_at: Vector3) -> bool:
    if not enemy["boss"]:
        return false
    if not enemy["enraged"] and enemy["hp"] <= enemy["max_hp"] * 0.4:
        enemy["enraged"] = true
        enemy["interval"] = 1.5
        events.append({"type": "boss_enraged", "enemy": BOSS})
    if enemy["windup"] > 0:
        enemy["windup"] = maxf(0, enemy["windup"] - delta)
        if enemy["windup"] == 0:
            var point: Vector3 = enemy["blast_at"]
            var hit: bool = hero_at.distance_to(point) <= BLAST_RADIUS and not in_safe(hero_at) and navigation.has_clear_shot(enemy["at"], hero_at)
            events.append({"type": "boss_blast", "enemy": BOSS, "from": enemy["at"], "to": point, "hit": hit})
            if hit:
                hp = maxf(0, hp - BLAST_DAMAGE)
                quiet = 0
                last_attacker = BOSS
                if hp <= 0:
                    protocol = 0
                    attack_target = -1
                    events.append({"type": "hero_defeated"})
            enemy["blast_cd"] = 5.0 if enemy["enraged"] else 7.0
        return true
    enemy["blast_cd"] = maxf(0, enemy["blast_cd"] - delta * (0.9 if enemy["slow"] > 0 else 1.0))
    if enemy["blast_cd"] <= 0 and _can_shoot(enemy["at"], hero_at, 8.0):
        enemy["blast_at"] = hero_at
        enemy["windup"] = 1.4
        events.append({"type": "boss_warning", "enemy": BOSS, "to": hero_at, "seconds": 1.4})
        return true
    return false

func tick(seconds: float, hero_at: Vector3, hero_can_fire: bool = true, aimed_target: int = -2) -> void:
    super.tick(seconds, hero_at, hero_can_fire, aimed_target)
    if not enabled:
        return
    var delta := clampf(seconds, 0, 0.1)
    for enemy in enemies:
        var id: int = enemy["id"]
        if enemy["hp"] > 0:
            continue
        respawns[id] = maxf(0, float(respawns[id]) - delta)
        # A cleared camp cannot materialize under the player. Offline time is frozen.
        if respawns[id] > 0 or hero_at.distance_to(enemy["home"]) < 10.0 or hp <= 0:
            continue
        enemy["at"] = enemy["home"]
        enemy["hp"] = enemy["max_hp"]
        enemy["aggro"] = false
        enemy["returning"] = false
        enemy["path"] = []
        enemy["enraged"] = false
        enemy["interval"] = 2.2 if enemy["boss"] else 1.8
        enemy["blast_cd"] = 3.0
        for timer in ["shot", "stun", "slow", "weak", "repath", "windup"]:
            enemy[timer] = 0.0
        events.append({"type": "enemy_respawned", "enemy": id})

func respawn() -> bool:
    if not super.respawn():
        return false
    for enemy in enemies:
        enemy["windup"] = 0.0
        enemy["blast_cd"] = 3.0
        enemy["enraged"] = false
        enemy["interval"] = 2.2 if enemy["boss"] else 1.8
    return true
