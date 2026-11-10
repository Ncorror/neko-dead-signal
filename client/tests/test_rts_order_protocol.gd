extends SceneTree
## Headless regression: standalone wire DTO only, not a simulated online match.

const PROTOCOL := preload("res://scripts/rts_order_protocol.gd")
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_ORDER_PROTOCOL_TEST_FAIL: " + message)

func _accepted(raw: Variant) -> bool:
    return bool(PROTOCOL.decode(raw, 96.0).get("ok", false))

func _run() -> void:
    var move := PROTOCOL.make_move("match-1", "unit-17", 7, true, Vector3(8.5, 0.0, -12.0))
    var json: String = JSON.stringify(move)
    var round_trip: Variant = JSON.parse_string(json)
    _check(round_trip is Dictionary and _accepted(round_trip), "move must survive JSON round trip")
    var parsed: Dictionary = PROTOCOL.decode(round_trip, 96.0).get("command", {})
    _check(parsed.get("kind") == "move" and parsed.get("queue") == true, "move fields lost")
    _check(parsed.get("target_position", {}).get("x") == 8.5, "move x lost")
    _check(parsed.get("target_position", {}).get("z") == -12.0, "move z lost")
    _check(not json.contains("Vector3") and not json.contains("Combatant"), "wire payload cannot contain Godot objects")

    var attack := PROTOCOL.make_attack("match-1", "unit-17", 8, true, "enemy-3")
    _check(_accepted(attack), "target-id attack must be serializable")
    _check(PROTOCOL.decode(attack, 96.0).get("command", {}).get("target_actor_id") == "enemy-3",
        "attack target must retain stable ID")
    var stop := PROTOCOL.make_stop("match-1", "unit-17", 9)
    _check(_accepted(stop) and not stop["queue"], "stop must be immediate")
    _check(PROTOCOL.is_new_sequence(8, 7), "newer sequence rejected")
    _check(not PROTOCOL.is_new_sequence(7, 7) and not PROTOCOL.is_new_sequence(6, 7),
        "replayed or older sequence accepted")
    _check(not PROTOCOL.is_new_sequence(0, 0), "sequence zero accepted")

    var changed: Dictionary = move.duplicate(true)
    changed["version"] = 2
    _check(not _accepted(changed), "unsupported version accepted")
    changed = move.duplicate(true)
    changed["kind"] = "teleport"
    _check(not _accepted(changed), "unknown command accepted")
    changed = move.duplicate(true)
    changed["match_id"] = "match/../../../1"
    _check(not _accepted(changed), "unsafe ID accepted")
    changed = move.duplicate(true)
    changed["sequence"] = 0
    _check(not _accepted(changed), "invalid sequence accepted")
    changed = move.duplicate(true)
    changed["queue"] = "yes"
    _check(not _accepted(changed), "string used as queue flag")
    changed = move.duplicate(true)
    changed["speed"] = 100000
    _check(not _accepted(changed), "untrusted speed accepted")
    changed = move.duplicate(true)
    changed["target_position"]["x"] = 9999
    _check(not _accepted(changed), "out-of-map position accepted")
    changed = move.duplicate(true)
    changed["target_position"]["x"] = INF
    _check(not _accepted(changed), "infinite coordinate accepted")
    changed = move.duplicate(true)
    changed["target_position"]["z"] = true
    _check(not _accepted(changed), "boolean coordinate accepted")
    changed = move.duplicate(true)
    changed["target_position"].erase("x")
    _check(not _accepted(changed), "missing x coordinate accepted")
    changed = attack.duplicate(true)
    changed["target_actor_id"] = ""
    _check(not _accepted(changed), "empty target ID accepted")
    changed = stop.duplicate(true)
    changed["queue"] = true
    _check(not _accepted(changed), "queued stop accepted")
    changed = stop.duplicate(true)
    changed["target_position"] = {"x": 0, "z": 0}
    _check(not _accepted(changed), "irrelevant payload fields accepted")
    _check(not _accepted([]), "array accepted instead of command object")
    _check(not PROTOCOL.decode(move, 0.0).get("ok", false), "invalid map limit accepted")

    if failures == 0:
        print("RTS_ORDER_PROTOCOL_TEST_PASS: roundtrip, strict payload, bounds, sequence")
    quit(0 if failures == 0 else 1)
