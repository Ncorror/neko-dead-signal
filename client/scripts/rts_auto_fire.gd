extends RefCounted
## Return fire is separate from player orders. Manual routes always have priority.

const MEMORY_SECONDS := 6.0
const DEFENCE_RADIUS := 8.0
const REPATH_SECONDS := 0.4

var enabled := true
var memory: Dictionary = {}
var moving: Dictionary = {}
var repath_age: Dictionary = {}

func has_player_order(unit, op) -> bool:
    return op.attackers.has(unit) or op.unit_orders.has(unit) \
        or (op.unit_paths.has(unit) and not moving.has(unit))

func cancel(unit, op) -> void:
    if moving.has(unit):
        op._clear_path(unit)
    moving.erase(unit)
    memory.erase(unit)
    repath_age.erase(unit)

func stop(op) -> void:
    for unit in memory.keys():
        cancel(unit, op)
    for unit in moving.keys():
        cancel(unit, op)

func set_enabled(value: bool, op) -> void:
    enabled = value
    if not enabled:
        stop(op)

func record_hit(unit, aggressor, op) -> void:
    if not enabled or unit.hull <= 0 or has_player_order(unit, op) \
        or not op.visibility.is_visible(aggressor.position):
        return
    if not memory.has(unit):
        memory[unit] = {"target": aggressor, "anchor": unit.position, "remaining": MEMORY_SECONDS}
        repath_age[unit] = REPATH_SECONDS
        if RTSDiagnostics.enabled:
            RTSDiagnostics.event("combat", "return_fire", {"unit": unit.name, "target": aggressor.name})
    else:
        # Repeated hits renew contact, but cannot drag the defence anchor along.
        memory[unit]["remaining"] = MEMORY_SECONDS
        memory[unit]["target"] = aggressor

func update_motion(unit, delta: float, op) -> void:
    if not memory.has(unit):
        return
    if not enabled or has_player_order(unit, op):
        cancel(unit, op)
        return
    var contact: Dictionary = memory[unit]
    contact["remaining"] -= delta
    var enemy = contact["target"]
    var anchor: Vector3 = contact["anchor"]
    if not is_instance_valid(enemy) or enemy.hull <= 0 or contact["remaining"] <= 0.0 \
        or not op.visibility.is_visible(enemy.position):
        cancel(unit, op)
        return
    if unit.position.distance_to(anchor) > DEFENCE_RADIUS or enemy.position.distance_to(anchor) > DEFENCE_RADIUS:
        if moving.has(unit):
            op._clear_path(unit)
            moving.erase(unit)
        # Keep the original anchor while the same engagement keeps hitting us.
        return
    if op._in_firing_position(unit, enemy):
        if moving.has(unit):
            op._clear_path(unit)
            moving.erase(unit)
        return
    # A lost firing lane is not permission to chase an unseen target around cover.
    if not op.navigation.has_clear_sight(unit.position, enemy.position):
        cancel(unit, op)
        return
    repath_age[unit] = repath_age.get(unit, 0.0) + delta
    if repath_age[unit] < REPATH_SECONDS:
        return
    repath_age[unit] = 0.0
    var route: Array[Vector3] = op.navigation.get_path(unit.position, enemy.position, op._other_unit_positions(unit))
    if route.is_empty():
        cancel(unit, op)
        return
    for point in route:
        if point.distance_to(anchor) > DEFENCE_RADIUS:
            cancel(unit, op)
            return
    op.unit_paths[unit] = route
    op.unit_waypoint_index[unit] = 0
    op.unit_move_speeds[unit] = op.OFFICER_SPEED if unit == op.hero else op.ESCORT_SPEED
    moving[unit] = true
    op.orders_ui_dirty = true

func try_fire(unit, op) -> bool:
    var enemy = op.sentry
    if not enabled or op.outcome != op.Outcome.ACTIVE or unit.hull <= 0 or enemy.hull <= 0 \
        or not op.visibility.is_visible(enemy.position) or not op._in_firing_position(unit, enemy):
        return false
    op._face_direction(unit, enemy.position - unit.position)
    op._shoot(unit, enemy, &"automatic")
    return true
