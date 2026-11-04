extends RefCounted
## Two additional combat/capture objectives; original landing goals remain required.

const Combatant := preload("res://scripts/combatant.gd")
const POSITIONS := [Vector3(-30, 0, -24), Vector3(34, 0, 24)]
const CAPTURE_SECONDS := 6.0
const CAPTURE_REWARD := 150

var expanded := true
var relays: Array[Dictionary] = []

func install(op) -> void:
    for i in range(POSITIONS.size()):
        var relay := Node3D.new()
        relay.name = "SignalRelay_%d" % (i + 1)
        relay.position = POSITIONS[i]
        op.add_child(relay)
        op._make_box(Vector3.ZERO, Vector3(1.7, 0.5, 1.7), Color("#73599c"), relay)
        var lamp = op._make_box(Vector3(0, 0.5, 0), Vector3(0.35, 2.3, 0.35), Color("#c495ff"), relay)
        var label := Label3D.new()
        label.position.y = 3.5
        label.pixel_size = 0.013
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        relay.add_child(label)
        var enemy := Combatant.new()
        enemy.name = "RelayGuardian_%d" % (i + 1)
        enemy.position = POSITIONS[i] + Vector3(0, 0, 4)
        enemy.hull = 120
        enemy.damage = 10
        enemy.reload_time = 1.2
        enemy.weapon_range = 6.5
        op.add_child(enemy)
        op._make_box(Vector3.ZERO, Vector3(1.4, 1.2, 1.4), Color("#a54a47"), enemy)
        op._make_box(Vector3(0, 1.2, 0), Vector3(0.6, 0.7, 0.6), Color("#ff9257"), enemy).name = "Beacon"
        op._make_box(Vector3(0, 1.3, 0.5), Vector3(0.2, 0.2, 1.1), Color("#ffbc86"), enemy)
        var enemy_label := Label3D.new()
        enemy_label.position.y = 2.7
        enemy_label.pixel_size = 0.01
        enemy_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        enemy.add_child(enemy_label)
        relays.append({"node": relay, "lamp": lamp, "label": label, "enemy": enemy,
            "enemy_label": enemy_label, "progress": 0.0, "captured": false})

func enemies() -> Array[Combatant]:
    var result: Array[Combatant] = []
    if expanded:
        for relay in relays:
            result.append(relay["enemy"])
    return result

func positions() -> Array[Vector3]:
    var result: Array[Vector3] = []
    if expanded:
        result.assign(POSITIONS)
    return result

func tick_defences(delta: float, op) -> void:
    if not expanded:
        return
    for relay in relays:
        var enemy: Combatant = relay["enemy"]
        if enemy.hull <= 0:
            continue
        enemy.tick(delta)
        var nearest: Combatant = null
        var best := INF
        for unit in op.units:
            var distance: float = unit.position.distance_squared_to(enemy.position)
            if distance < best and op._in_firing_position(enemy, unit):
                nearest = unit
                best = distance
        if nearest != null:
            op._face_direction(enemy, nearest.position - enemy.position)
            op._shoot(enemy, nearest, &"enemy")
        op._turn_unit(enemy, delta)

func tick(delta: float, op) -> bool:
    if not expanded or op.outcome != op.Outcome.ACTIVE or op.units.is_empty():
        return false
    var changed := false
    for i in range(relays.size()):
        var relay: Dictionary = relays[i]
        if relay["captured"]:
            continue
        var occupied := false
        if relay["enemy"].hull <= 0:
            for unit in op.units:
                if unit.hull > 0 and unit.position.distance_to(relay["node"].position) <= 2.2:
                    occupied = true
                    break
        relay["progress"] = minf(CAPTURE_SECONDS, relay["progress"] + maxf(delta, 0.0)) if occupied else 0.0
        if relay["progress"] >= CAPTURE_SECONDS:
            relay["captured"] = true
            relay["lamp"].material_override.albedo_color = Color("#62ecf0")
            op.production.credit(CAPTURE_REWARD)
            changed = true
            if RTSDiagnostics.enabled:
                RTSDiagnostics.event("objective", "relay_captured", {"relay": i + 1, "reward": CAPTURE_REWARD})
    return changed

func captured() -> int:
    var count := 0
    for relay in relays:
        count += 1 if relay["captured"] else 0
    return count

func complete(op) -> bool:
    if op.sentry.hull > 0 or not op.crates.is_empty():
        return false
    return not expanded or (captured() == relays.size() and op.economy.generators(op) > 0
        and op.economy.powered_extractors(op) > 0)

func summary(op) -> String:
    var guards := 0
    for enemy in op._active_enemies():
        guards += 1 if enemy.hull <= 0 else 0
    return "ЦЕЛИ · Припасы %d/3 · Охрана %d/%d · Узлы %d/2 · База %d/2" % [
        3 - op.crates.size(), guards, op._active_enemies().size(), captured(),
        (1 if op.economy.generators(op) > 0 else 0) + (1 if op.economy.powered_extractors(op) > 0 else 0)]

func details(op) -> String:
    return "1. Собери три золотых контейнера: %d/3.\n2. Уничтожь стража и охрану двух узлов сигнала.\n3. Займи оба узла бойцом на 6 секунд: %d/2.\n   Узлы: северо-запад (−30, −24), юго-восток (34, 24).\n4. Построй электростанцию и запитай добытчик.\n\nСнабжение: +2 ресурса / 5 с. Добытчик: +10 / 5 с.\nЗахват узла даёт 150 ресурсов один раз.\n%s" % [3 - op.crates.size(), captured(), op.economy.summary()]

func apply_visibility(op) -> void:
    for i in range(relays.size()):
        var relay: Dictionary = relays[i]
        var enemy: Combatant = relay["enemy"]
        var visible_now: bool = expanded and op.visibility.is_visible(enemy.position)
        enemy.visible = expanded and (visible_now or (enemy.hull <= 0 and op.visibility.was_explored(enemy.position)))
        relay["enemy_label"].visible = visible_now
        relay["enemy_label"].text = "ОХРАНА %d · %d" % [i + 1, enemy.hull]
        relay["node"].visible = expanded and (op.visibility.is_visible(relay["node"].position)
            or (relay["captured"] and op.visibility.was_explored(relay["node"].position)))
        relay["label"].text = "УЗЕЛ %d · %s" % [i + 1, "ЗАХВАЧЕН" if relay["captured"]
            else ("%d%%" % int(relay["progress"] / CAPTURE_SECONDS * 100) if relay["progress"] > 0 else "ЗАЙМИ ПОСЛЕ БОЯ")]
