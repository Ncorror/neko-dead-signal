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
    var forward := direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
    var columns := mini(4, ceili(sqrt(float(starts.size()))))
    var rows := ceili(float(starts.size()) / float(columns))
    # A point route needs a usable gap between already-arrived allies, not
    # just two touching personal-space circles at the final formation.
    var spacing := 2.2 if starts.size() <= 2 else 3.2
    for i in range(starts.size()):
        var row := floori(float(i) / float(columns))
        var count_in_row := mini(columns, starts.size() - row * columns)
        var offset := (float(i % columns) - float(count_in_row - 1) * 0.5) * spacing
        var depth := (float(row) - float(rows - 1) * 0.5) * spacing
        var avoid := occupied.duplicate()
        avoid.append_array(slots)
        var route: Array[Vector3] = navigation.get_path(starts[i], goal + lateral * offset - forward * depth, avoid)
        if route.is_empty():
            return []
        var destination: Vector3 = route.back()
        for slot in slots:
            if slot.distance_to(destination) < navigation.UNIT_SEPARATION:
                return []
        slots.append(destination)
    # Pairwise swaps reduce total squared travel distance. Two-actor orders
    # retain their original line; larger groups use compact rows.
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
