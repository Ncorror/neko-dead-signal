extends RefCounted
## Wire-only RTS order format. No gameplay state, Node references or network socket.
## Server-side ownership, visibility, authority and sequence tracking belong elsewhere.

const VERSION := 1
const MAX_ID_LENGTH := 64

static func make_move(match_id: String, actor_id: String, sequence: int, queue: bool, target: Vector3) -> Dictionary:
    var result := _base(match_id, actor_id, sequence, "move", queue)
    result["target_position"] = {"x": target.x, "z": target.z}
    return result

static func make_attack(match_id: String, actor_id: String, sequence: int, queue: bool, target_actor_id: String) -> Dictionary:
    var result := _base(match_id, actor_id, sequence, "attack", queue)
    result["target_actor_id"] = target_actor_id
    return result

static func make_stop(match_id: String, actor_id: String, sequence: int) -> Dictionary:
    return _base(match_id, actor_id, sequence, "stop", false)

static func _base(match_id: String, actor_id: String, sequence: int, kind: String, queue: bool) -> Dictionary:
    return {
        "version": VERSION, "match_id": match_id, "actor_id": actor_id,
        "sequence": sequence, "kind": kind, "queue": queue
    }

static func _error(reason: String) -> Dictionary:
    return {"ok": false, "error": reason}

static func _valid_id(value: Variant) -> bool:
    if typeof(value) != TYPE_STRING:
        return false
    var identifier: String = value
    if identifier.is_empty() or identifier.length() > MAX_ID_LENGTH:
        return false
    for i in range(identifier.length()):
        var codepoint: int = identifier.unicode_at(i)
        if (codepoint >= 48 and codepoint <= 57) or (codepoint >= 65 and codepoint <= 90) \
            or (codepoint >= 97 and codepoint <= 122) or codepoint == 45 or codepoint == 95:
            continue
        return false
    return true

static func is_new_sequence(sequence: int, previously_accepted: int) -> bool:
    ## Caller owns independent counters per actor/connection; this function is stateless.
    return sequence > 0 and sequence > previously_accepted

static func decode(value: Variant, map_limit: float) -> Dictionary:
    ## Produces a canonical, JSON-safe command; does not authorize or execute it.
    if typeof(value) != TYPE_DICTIONARY:
        return _error("not_object")
    var raw: Dictionary = value
    if typeof(raw.get("version")) != TYPE_INT or raw["version"] != VERSION:
        return _error("version")
    if not _valid_id(raw.get("match_id")) or not _valid_id(raw.get("actor_id")):
        return _error("id")
    if typeof(raw.get("sequence")) != TYPE_INT or raw["sequence"] <= 0:
        return _error("sequence")
    if typeof(raw.get("kind")) != TYPE_STRING:
        return _error("kind")
    var kind: String = raw["kind"]
    if not ["move", "attack", "stop"].has(kind):
        return _error("kind")
    if typeof(raw.get("queue")) != TYPE_BOOL:
        return _error("queue")
    if kind == "stop" and raw["queue"]:
        return _error("queued_stop")
    var allowed := ["version", "match_id", "actor_id", "sequence", "kind", "queue"]
    if kind == "move":
        allowed.append("target_position")
    elif kind == "attack":
        allowed.append("target_actor_id")
    for key in raw.keys():
        if typeof(key) != TYPE_STRING or not allowed.has(key):
            return _error("unknown_field")
    var command := _base(raw["match_id"], raw["actor_id"], raw["sequence"], kind, raw["queue"])
    if kind == "move":
        if map_limit <= 0.0 or not Vector2(map_limit, 0.0).is_finite():
            return _error("map_limit")
        if typeof(raw.get("target_position")) != TYPE_DICTIONARY:
            return _error("target_position")
        var point: Dictionary = raw["target_position"]
        if point.size() != 2 or not point.has("x") or not point.has("z"):
            return _error("target_position")
        if typeof(point["x"]) not in [TYPE_INT, TYPE_FLOAT] or typeof(point["z"]) not in [TYPE_INT, TYPE_FLOAT]:
            return _error("target_position")
        var x: float = float(point["x"])
        var z: float = float(point["z"])
        if not Vector2(x, z).is_finite() or absf(x) > map_limit or absf(z) > map_limit:
            return _error("target_bounds")
        command["target_position"] = {"x": x, "z": z}
    elif kind == "attack":
        if not _valid_id(raw.get("target_actor_id")):
            return _error("target_actor_id")
        command["target_actor_id"] = raw["target_actor_id"]
    return {"ok": true, "command": command}
