extends RefCounted
## Local PvE slice. No scene nodes, wallet, wall clock or multiplayer authority.

const MAX_HP := 100.0
const DAMAGE := 12.0
const SHOT_INTERVAL := 0.9
const RANGE := 7.0
const GRENADE_RANGE := 8.0
const DASH_DISTANCE := 3.5
const SAFE_AT := Vector3(-18, 0, 15)
const SAFE_RADIUS := 8.0
const SKILL_NAMES := ["ШТУРМОВОЙ\nПРОТОКОЛ", "ОСКОЛОЧНАЯ\nГРАНАТА", "КУМУЛЯТИВНАЯ\nГРАНАТА", "ТАКТИЧЕСКИЙ\nРЫВОК", "ИМПУЛЬСНАЯ\nГРАНАТА"]
const COOLDOWNS := [50.0, 16.0, 24.0, 18.0, 28.0]
const HOMES := [Vector3(5, 0, -14), Vector3(9, 0, -15), Vector3(7, 0, -18)]
const ENEMY_NAMES := ["МАРОДЁР 1", "МАРОДЁР 2", "БОЕВОЙ АВТОМАТ"]

var navigation
var profile_id := "amina"
var weapon_range := RANGE
var enabled := false
var hp := MAX_HP
var cooldowns: Array = [0.0, 0.0, 0.0, 0.0, 0.0]
var launcher := 0.0
var protocol := 0.0
var weapon := 0.0
var quiet := 0.0
var attack_target := -1
var last_attacker := -1
var enemies: Array[Dictionary] = []
var events: Array[Dictionary] = []

static func fresh_profile() -> Dictionary:
    return {"accepted": false, "claimed": false, "defeated": [], "hp": MAX_HP,
        "cooldowns": [0.0, 0.0, 0.0, 0.0, 0.0], "launcher": 0.0, "protocol": 0.0, "weapon": 0.0}

func set_profile(character_id: String) -> void:
    profile_id = character_id
    weapon_range = 16.0 if profile_id == "lyra_voss" else RANGE


static func valid_profile(value: Variant) -> bool:
    if not value is Dictionary or not value.get("accepted") is bool or not value.get("claimed") is bool:
        return false
    if not value.get("defeated") is Array or not value.get("cooldowns") is Array or value["cooldowns"].size() != 5:
        return false
    var ids: Array = []
    for id in value["defeated"]:
        if not (id is int or id is float) or id != int(id) or int(id) not in [0, 1, 2] or ids.has(int(id)):
            return false
        ids.append(int(id))
    if (not value["accepted"] and not ids.is_empty()) or (value["claimed"] and (not value["accepted"] or ids.size() != 3)):
        return false
    for key in ["hp", "launcher", "protocol", "weapon"]:
        var number: Variant = value.get(key)
        var upper: float = {"hp": MAX_HP, "launcher": 1.2, "protocol": 10.0, "weapon": SHOT_INTERVAL}[key]
        if not (number is int or number is float) or not is_finite(float(number)) or number < 0 or number > upper + 0.001:
            return false
    for i in range(5):
        var number: Variant = value["cooldowns"][i]
        if not (number is int or number is float) or not is_finite(float(number)) or number < 0 or number > COOLDOWNS[i] + 0.001:
            return false
    return true

func configure(nav, saved: Dictionary) -> void:
    navigation = nav
    enabled = saved["accepted"]
    hp = float(saved["hp"])
    cooldowns = saved["cooldowns"].duplicate()
    launcher = float(saved["launcher"])
    protocol = float(saved["protocol"])
    weapon = float(saved["weapon"])
    attack_target = -1
    last_attacker = -1
    quiet = 0
    events.clear()
    enemies.clear()
    for spec in enemy_specs():
        var i: int = enemies.size()
        var maximum: float = spec["max_hp"]
        var enemy := spec.duplicate(true)
        enemy.merge({"id": i, "at": spec["home"], "hp": 0.0 if saved["defeated"].has(i) else maximum,
            "aggro": false, "returning": false, "shot": 0.0, "stun": 0.0, "slow": 0.0, "weak": 0.0,
            "path": [], "path_index": 0, "repath": 0.0}, true)
        enemies.append(enemy)

func enemy_specs() -> Array[Dictionary]:
    var specs: Array[Dictionary] = []
    for i in range(3):
        specs.append({"home": HOMES[i], "name": ENEMY_NAMES[i], "max_hp": 120.0 if i == 2 else 65.0,
            "vehicle": i == 2, "armor": 0.3 if i == 2 else 0.1,
            "damage": 4.0 if i == 2 else 3.0, "interval": 1.8})
    return specs

func _special_attack(_enemy: Dictionary, _delta: float, _hero_at: Vector3) -> bool:
    return false

func snapshot() -> Dictionary:
    var defeated: Array = []
    for enemy in enemies:
        if enemy["hp"] <= 0:
            defeated.append(enemy["id"])
    return {"defeated": defeated, "hp": hp, "cooldowns": cooldowns.duplicate(),
        "launcher": launcher, "protocol": protocol, "weapon": weapon}

func take_events() -> Array[Dictionary]:
    var result := events.duplicate()
    events.clear()
    return result

func alive(id: int) -> bool:
    return id >= 0 and id < enemies.size() and enemies[id]["hp"] > 0

func in_safe(point: Vector3) -> bool:
    return point.distance_to(SAFE_AT) <= SAFE_RADIUS

func select_target(id: int) -> bool:
    if not enabled or hp <= 0 or not alive(id) or enemies[id]["returning"]:
        return false
    attack_target = id
    return true

func _can_shoot(from: Vector3, to: Vector3, distance: float) -> bool:
    return from.distance_to(to) <= distance and navigation.has_clear_shot(from, to)

func _move_enemy(enemy: Dictionary, target: Vector3, delta: float, speed: float) -> void:
    enemy["repath"] -= delta
    if enemy["repath"] <= 0:
        var avoid: Array[Vector3] = []
        for other in enemies:
            if other["id"] != enemy["id"] and other["hp"] > 0:
                avoid.append(other["at"])
        enemy["path"] = navigation.get_path(enemy["at"], target, avoid)
        enemy["path_index"] = 0
        enemy["repath"] = 0.4
    var travel := delta * speed
    var path: Array = enemy["path"]
    while enemy["path_index"] < path.size() and travel > 0:
        var at: Vector3 = enemy["at"]
        var next: Vector3 = path[enemy["path_index"]]
        var distance := at.distance_to(next)
        var step := minf(distance, travel)
        enemy["at"] = at.move_toward(next, step)
        travel -= step
        if step >= distance - 0.0001:
            enemy["path_index"] += 1

func _retreat(enemy: Dictionary, delta: float) -> void:
    enemy["aggro"] = false
    enemy["returning"] = true
    _move_enemy(enemy, enemy["home"], delta, 3.2)
    if enemy["at"].distance_to(enemy["home"]) <= 0.1:
        enemy["at"] = enemy["home"]
        enemy["hp"] = enemy["max_hp"]
        enemy["returning"] = false
        enemy["weak"] = 0.0
        enemy["stun"] = 0.0
        enemy["slow"] = 0.0

func tick(seconds: float, hero_at: Vector3, hero_can_fire: bool = true) -> void:
    if not enabled:
        return
    var delta := clampf(seconds, 0, 0.1)
    for i in range(5):
        cooldowns[i] = maxf(0, float(cooldowns[i]) - delta)
    launcher = maxf(0, launcher - delta)
    protocol = maxf(0, protocol - delta)
    weapon = maxf(0, weapon - delta)
    quiet += delta
    for enemy in enemies:
        if enemy["hp"] <= 0:
            continue
        for timer in ["shot", "stun", "slow", "weak"]:
            var rate := 0.9 if timer == "shot" and enemy.get("boss", false) and enemy["slow"] > 0 else 1.0
            enemy[timer] = maxf(0, enemy[timer] - delta * rate)
        if enemy["returning"] or hp <= 0 or in_safe(hero_at) or hero_at.distance_to(enemy["home"]) > 12.0:
            if enemy["aggro"] or enemy["returning"] or enemy["at"] != enemy["home"]:
                _retreat(enemy, delta)
            continue
        if not enemy["aggro"] and _can_shoot(enemy["at"], hero_at, 8.0):
            enemy["aggro"] = true
            events.append({"type": "enemy_aggro", "enemy": enemy["id"]})
        if not enemy["aggro"] or enemy["stun"] > 0:
            continue
        if _special_attack(enemy, delta, hero_at):
            continue
        if not _can_shoot(enemy["at"], hero_at, 5.0):
            _move_enemy(enemy, hero_at, delta, 2.6 * (0.8 if enemy["slow"] > 0 and not enemy.get("boss", false) else 1.0))
        elif enemy["shot"] <= 0:
            var amount: float = enemy["damage"]
            hp = maxf(0, hp - amount)
            quiet = 0
            last_attacker = enemy["id"]
            enemy["shot"] = enemy["interval"]
            events.append({"type": "enemy_shot", "enemy": enemy["id"], "from": enemy["at"], "to": hero_at, "damage": amount})
            if hp <= 0:
                protocol = 0
                attack_target = -1
                events.append({"type": "hero_defeated"})
    if hp <= 0:
        return
    if in_safe(hero_at) and quiet >= 5.0:
        hp = minf(MAX_HP, hp + delta * 8)
    var target := attack_target if alive(attack_target) else last_attacker
    if hero_can_fire and alive(target) and not in_safe(hero_at) and not enemies[target]["returning"] and weapon <= 0:
        var enemy: Dictionary = enemies[target]
        if _can_shoot(hero_at, enemy["at"], weapon_range):
            _hit(enemy, DAMAGE * (1.12 if protocol > 0 else 1.0), "weapon")
            weapon = SHOT_INTERVAL
            quiet = 0
            events.append({"type": "hero_shot", "enemy": target, "from": hero_at, "to": enemy["at"], "distance": hero_at.distance_to(enemy["at"]), "hp_after": enemy["hp"]})
    if not alive(attack_target):
        attack_target = -1

func _hit(enemy: Dictionary, raw: float, source: String) -> void:
    # Armour weakening affects later hits, never the grenade that first applies it.
    var armour: float = enemy["armor"] * (0.9 if enemy["weak"] > 0 else 1.0)
    var amount := raw * (1.0 - armour)
    enemy["hp"] = maxf(0, enemy["hp"] - amount)
    enemy["aggro"] = true
    events.append({"type": "enemy_damaged", "enemy": enemy["id"], "damage": amount, "source": source})
    if enemy["hp"] <= 0:
        events.append({"type": "enemy_defeated", "enemy": enemy["id"]})

func enemy_near(point: Vector3, radius: float = 1.5) -> int:
    var nearest := -1
    var distance := radius
    for enemy in enemies:
        var current: float = enemy["at"].distance_to(point)
        if enemy["hp"] > 0 and not enemy["returning"] and current <= distance:
            nearest = enemy["id"]
            distance = current
    return nearest

func dash_end(hero_at: Vector3, point: Vector3) -> Vector3:
    var direction := point - hero_at
    direction.y = 0
    return hero_at + direction.limit_length(DASH_DISTANCE)

func cast_error(skill: int, hero_at: Vector3, point: Vector3) -> String:
    if not enabled or hp <= 0:
        return "Бой недоступен. Прими поручение у Веги; после гибели вернись на площадку."
    if skill < 0 or skill >= 5:
        return "Неизвестный навык."
    if cooldowns[skill] > 0:
        return "Навык ещё восстанавливается."
    if skill == 0:
        return ""
    if not point.is_finite():
        return "Выбери площадку на земле."
    if skill == 3:
        var end := dash_end(hero_at, point)
        if end.distance_to(hero_at) < 0.25 or not navigation.has_walkable_segment(hero_at, end):
            return "Путь рывка перекрыт. Выбери свободное направление."
        return ""
    if launcher > 0:
        return "Подствольный ствол готовится: общая задержка 1,2 с."
    if in_safe(hero_at) or in_safe(point):
        return "На посадочной площадке оружие заблокировано."
    if not _can_shoot(hero_at, point, GRENADE_RANGE):
        return "Цель вне дальности 8 или закрыта укрытием. Подойди ближе."
    if skill == 2 and enemy_near(point) < 0:
        return "Для кумулятивной гранаты коснись живого противника."
    return ""

func cast(skill: int, hero_at: Vector3, point: Vector3) -> Dictionary:
    var error := cast_error(skill, hero_at, point)
    if not error.is_empty():
        return {"ok": false, "error": error}
    cooldowns[skill] = COOLDOWNS[skill]
    quiet = 0
    var result := {"ok": true, "at": point}
    if skill == 0:
        protocol = 10.0
    elif skill == 3:
        result["at"] = dash_end(hero_at, point)
    else:
        launcher = 1.2
        var chosen := enemy_near(point)
        var radius := 3.0 if skill == 4 else 2.5
        for enemy in enemies:
            if enemy["hp"] <= 0 or enemy["returning"]:
                continue
            var distance: float = enemy["at"].distance_to(point)
            if skill == 2 and enemy["id"] != chosen:
                continue
            if skill != 2 and (distance > radius or not navigation.has_clear_shot(point, enemy["at"])):
                continue
            var multiplier := 0.85
            if skill == 1:
                multiplier = 1.4 * lerpf(1.0, 0.5, clampf(distance / radius, 0, 1))
            elif skill == 2:
                multiplier = 3.0 if enemy["vehicle"] else 1.0
            _hit(enemy, DAMAGE * multiplier, "grenade")
            enemy["weak"] = 4.0
            if skill == 4:
                enemy["stun"] = 0.0 if enemy.get("boss", false) else 0.7
                enemy["slow"] = 2.0
    events.append({"type": "skill_cast", "skill": skill, "from": hero_at, "to": result["at"]})
    return result

func respawn() -> bool:
    if hp > 0:
        return false
    hp = MAX_HP
    attack_target = -1
    last_attacker = -1
    protocol = 0
    quiet = 0
    for enemy in enemies:
        if enemy["hp"] > 0:
            enemy["at"] = enemy["home"]
            enemy["hp"] = enemy["max_hp"]
            enemy["aggro"] = false
            enemy["returning"] = false
            enemy["path"] = []
            for timer in ["stun", "slow", "weak", "shot", "repath"]:
                enemy[timer] = 0.0
    events.append({"type": "hero_respawned"})
    return true
