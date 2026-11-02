extends RefCounted
## Destination layout and assignment for a single RTS group movement order.

static func destinations(navigation, starts: Array[Vector3], goal: Vector3, occupied: Array[Vector3]) -> Array[Vector3]:
    var slots: Array[Vector3] = []
    if starts.is_empty():
        return slots
    var center := Vector3.ZERO
    for start in starts:
        center += start
    center /= starts.size()
    var direction := goal - center
    direction.y = 0.0
    var lateral := Vector3.RIGHT
    if direction.length_squared() > 0.001:
        lateral = Vector3(direction.z, 0.0, -direction.x).normalized()
    for i in range(starts.size()):
        var offset := (float(i) - float(starts.size() - 1) * 0.5) * 2.2
        var avoid := occupied.duplicate()
        avoid.append_array(slots)
        var route: Array[Vector3] = navigation.get_path(starts[i], goal + lateral * offset, avoid)
        if route.is_empty():
            return []
        var destination: Vector3 = route.back()
        for slot in slots:
            if slot.distance_to(destination) < navigation.UNIT_SEPARATION:
                return []
        slots.append(destination)
    # Pairwise swaps reduce total squared travel distance. For the current
    # two-actor landing, this considers both possible assignments exactly.
    var improved := true
    while improved:
        improved = false
        for i in range(starts.size()):
            for j in range(i + 1, starts.size()):
                var before := starts[i].distance_squared_to(slots[i]) + starts[j].distance_squared_to(slots[j])
                var after := starts[i].distance_squared_to(slots[j]) + starts[j].distance_squared_to(slots[i])
                if after + 0.0001 < before:
                    var previous := slots[i]
                    slots[i] = slots[j]
                    slots[j] = previous
                    improved = true
    return slots
