extends RefCounted
## Local guardian perception and movement. It only pursues observed positions.

const Combatant := preload("res://scripts/combatant.gd")
enum State { PATROL, CHASE, ATTACK, SEARCH, RETURN, DEAD, STOPPED }
const THINK_INTERVAL := 0.2
const REPATH_INTERVAL := 0.65
const SEARCH_SECONDS := 3.0
const MOVE_SPEED := 3.2
const LEASH_RADIUS := 24.0

var enabled := true
var movement_enabled := true
var detection_range := 8.0
var state := State.PATROL
var target: Combatant
var home := Vector3.ZERO
var patrol: Array[Vector3] = []
var patrol_index := 0
var last_seen := Vector3.ZERO
var path: Array[Vector3] = []
var path_index := 0
var path_goal := Vector3.ZERO
var path_requests := 0
var _think_age := THINK_INTERVAL
var _path_age := REPATH_INTERVAL
var _unseen_age := SEARCH_SECONDS

func configure(origin: Vector3, points: Array[Vector3]) -> void:
    home = origin
    patrol = points.duplicate()
    patrol_index = 1 if patrol.size() > 1 else 0
    last_seen = home

func state_text() -> String:
    return ["ПАТРУЛЬ", "ПРЕСЛЕДОВАНИЕ", "АТАКА", "ПОИСК", "ВОЗВРАТ", "УНИЧТОЖЕН", "ОСТАНОВЛЕН"][state]

func _set_state(next: State, op) -> void:
    if state == next:
        return
    var previous := state
    state = next
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("enemy", "state", {"from": State.keys()[previous], "to": State.keys()[state],
            "target": str(target.name) if is_instance_valid(target) else "", "at": str(op.sentry.position)})
    op._update_status()

func _can_see(unit, op) -> bool:
    return (is_instance_valid(unit) and unit.hull > 0 and op.units.has(unit)
        and unit.position.distance_to(home) <= LEASH_RADIUS
        and unit.position.distance_to(op.sentry.position) <= detection_range
        and op.navigation.has_clear_sight(op.sentry.position, unit.position))

func _find_target(op) -> Combatant:
    if _can_see(target, op):
        return target
    var nearest: Combatant = null
    var distance := INF
    for unit in op.units:
        if not _can_see(unit, op):
            continue
        var candidate: float = unit.position.distance_squared_to(op.sentry.position)
        if candidate < distance:
            distance = candidate
            nearest = unit
    return nearest

func _known_positions(op) -> Array[Vector3]:
    var result: Array[Vector3] = []
    for unit in op.units:
        if _can_see(unit, op):
            result.append(unit.position)
    return result

func _think(op) -> void:
    if state == State.RETURN:
        target = null
        if op.sentry.position.distance_to(home) <= 2.5:
            path.clear()
            _set_state(State.PATROL, op)
        else:
            return
    if op.sentry.position.distance_to(home) > LEASH_RADIUS:
        target = null
        path.clear()
        _set_state(State.RETURN, op)
        return
    var found := _find_target(op)
    if found != null:
        target = found
        last_seen = target.position
        _unseen_age = 0.0
        _set_state(State.ATTACK if op._in_firing_position(op.sentry, target) else State.CHASE, op)
    else:
        target = null
        if state in [State.CHASE, State.ATTACK, State.SEARCH]:
            if _unseen_age >= SEARCH_SECONDS or op.sentry.position.distance_to(last_seen) <= 1.5:
                path.clear()
                _set_state(State.RETURN, op)
            else:
                _set_state(State.SEARCH, op)

func _goal(op) -> Vector3:
    if state in [State.CHASE, State.SEARCH]:
        return last_seen
    if state == State.RETURN:
        return home
    if patrol.is_empty():
        return home
    if op.sentry.position.distance_to(patrol[patrol_index]) <= 0.35:
        patrol_index = (patrol_index + 1) % patrol.size()
        path.clear()
    return patrol[patrol_index]

func _move(delta: float, op) -> void:
    var goal := _goal(op)
    if op.sentry.position.distance_to(goal) <= 0.25:
        path.clear()
        return
    if _path_age >= REPATH_INTERVAL and (path.is_empty() or path_goal.distance_to(goal) > 0.75):
        _path_age = 0.0
        path_requests += 1
        path = op.navigation.get_path(op.sentry.position, goal, _known_positions(op))
        path_index = 0
        path_goal = goal
    var budget := MOVE_SPEED * delta
    while path_index < path.size() and budget > 0.0:
        var next: Vector3 = op.sentry.position.move_toward(path[path_index], budget)
        if not op._can_step(op.sentry, next):
            var passing: Variant = op._passing_step(op.sentry, path[path_index], minf(budget, op.sentry.position.distance_to(path[path_index])))
            if passing != null:
                op._face_direction(op.sentry, passing - op.sentry.position)
                op.sentry.position = passing
            if _path_age >= REPATH_INTERVAL:
                path.clear()
            return
        var travelled: float = op.sentry.position.distance_to(next)
        op._face_direction(op.sentry, next - op.sentry.position)
        op.sentry.position = next
        budget -= travelled
        if next.distance_to(path[path_index]) > 0.00001:
            break
        path_index += 1
    if path_index >= path.size():
        path.clear()
        path_index = 0

func tick(delta: float, op) -> void:
    if not enabled:
        return
    if op.sentry.hull <= 0:
        target = null
        path.clear()
        _set_state(State.DEAD, op)
        return
    _think_age += delta
    _path_age += delta
    _unseen_age += delta
    if is_instance_valid(target) and target.hull <= 0:
        target = null
        _unseen_age = SEARCH_SECONDS
        _think_age = THINK_INTERVAL
    if _think_age >= THINK_INTERVAL:
        _think_age = 0.0
        _think(op)
    if state == State.ATTACK:
        path.clear()
        if _can_see(target, op) and op._in_firing_position(op.sentry, target):
            op._face_direction(op.sentry, target.position - op.sentry.position)
            op._shoot(op.sentry, target, &"enemy")
    elif movement_enabled:
        _move(delta, op)
    op._turn_unit(op.sentry, delta)

func stop(dead: bool = false) -> void:
    enabled = false
    target = null
    path.clear()
    state = State.DEAD if dead else State.STOPPED
