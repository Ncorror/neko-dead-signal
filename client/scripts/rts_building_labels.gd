extends RefCounted
## Keep world-space building captions readable without moving their structures.

const PADDING := 3.0
const GAP := 4.0
var _last_key: Array = []

func layout(camera: Camera3D, buildings: Array[Dictionary]) -> void:
    var viewport := camera.get_viewport().get_visible_rect()
    var key: Array = [camera.global_transform, camera.get_camera_projection(), viewport]
    for entry in buildings:
        var label: Label3D = entry.get("map_label")
        if is_instance_valid(label):
            key.append([entry["node"].global_transform, label.text, label.is_visible_in_tree(), label.get_aabb()])
    if key == _last_key:
        return
    _last_key = key
    var occupied: Array[Rect2] = []
    for entry in buildings:
        var label: Label3D = entry.get("map_label")
        if not is_instance_valid(label):
            continue
        label.position = label.get_meta("map_anchor")
        if not label.is_visible_in_tree() or camera.is_position_behind(label.global_position):
            continue
        var anchor := camera.unproject_position(label.global_position)
        if not viewport.has_point(anchor):
            continue
        var rect := _screen_rect(camera, label).grow(PADDING)
        if rect.size.x <= PADDING * 2 or rect.size.y <= PADDING * 2:
            continue # The text mesh is populated after its first frame.
        var slot := _nearest_slot(rect, occupied, viewport.grow(-GAP))
        var offset := slot.position - rect.position
        if not offset.is_zero_approx():
            var depth := -camera.to_local(label.global_position).z
            label.global_position = camera.project_position(anchor + offset, depth)
        occupied.append(slot)

func _screen_rect(camera: Camera3D, label: Label3D) -> Rect2:
    var box := label.get_aabb()
    var right := camera.global_basis.x
    var up := camera.global_basis.y
    var first := true
    var rect := Rect2()
    for x in [box.position.x, box.end.x]:
        for y in [box.position.y, box.end.y]:
            var point := camera.unproject_position(label.global_position + right * x + up * y)
            if first:
                rect = Rect2(point, Vector2.ZERO)
                first = false
            else:
                rect = rect.expand(point)
    return rect

func _nearest_slot(rect: Rect2, occupied: Array[Rect2], bounds: Rect2) -> Rect2:
    # Candidate edges give the nearest available vertical slot. Stable building
    # order and a cached camera/text key avoid per-frame reshuffling at rest.
    var base := rect
    base.position.x = clampf(base.position.x, bounds.position.x, maxf(bounds.position.x, bounds.end.x - base.size.x))
    base.position.y = clampf(base.position.y, bounds.position.y, maxf(bounds.position.y, bounds.end.y - base.size.y))
    var candidates: Array[float] = [base.position.y]
    for other in occupied:
        candidates.append(other.position.y - GAP - base.size.y)
        candidates.append(other.end.y + GAP)
    var best := base
    var distance := INF
    for y in candidates:
        var candidate := Rect2(Vector2(base.position.x, y), base.size)
        if not bounds.encloses(candidate):
            continue
        var clear := true
        for other in occupied:
            if candidate.intersects(other.grow(GAP * 0.5)):
                clear = false
                break
        if clear and absf(y - rect.position.y) < distance:
            distance = absf(y - rect.position.y)
            best = candidate
    return best
