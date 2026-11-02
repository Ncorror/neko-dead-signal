extends RefCounted
## Small flat-map RTS navigation. Uses AStarGrid2D and inflated obstacle footprints.
## Prototype implementation for deterministic path requests, not final MMO-scale navigation.

const DEFAULT_STEP := 1.0
const UNIT_SEPARATION := 1.1
var cover: Array[AABB] = []
var grid: AStarGrid2D
var cell_step: float = DEFAULT_STEP
var world_limit: float = 24.0

func configure(limit: float = 24.0, step: float = DEFAULT_STEP) -> void:
    cover.clear()
    world_limit = limit
    cell_step = step
    var radius := ceili(world_limit / cell_step)
    grid = AStarGrid2D.new()
    grid.region = Rect2i(-radius, -radius, radius * 2 + 1, radius * 2 + 1)
    grid.cell_size = Vector2.ONE * cell_step
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()

func world_to_cell(point: Vector3) -> Vector2i:
    return Vector2i(roundi(point.x / cell_step), roundi(point.z / cell_step))

func cell_to_world(cell: Vector2i) -> Vector3:
    return Vector3(float(cell.x) * cell_step, 0.0, float(cell.y) * cell_step)

func set_blocked_box(center: Vector3, box_size: Vector3, clearance: float = 0.75, blocks_fire: bool = true) -> void:
    assert(grid != null)
    if blocks_fire:
        var corner := center - Vector3(box_size.x, 0.0, box_size.z) * 0.5
        cover.append(AABB(corner, box_size))
    var min_x := ceili((center.x - box_size.x * 0.5 - clearance) / cell_step)
    var max_x := floori((center.x + box_size.x * 0.5 + clearance) / cell_step)
    var min_y := ceili((center.z - box_size.z * 0.5 - clearance) / cell_step)
    var max_y := floori((center.z + box_size.z * 0.5 + clearance) / cell_step)
    for x in range(min_x, max_x + 1):
        for y in range(min_y, max_y + 1):
            var cell := Vector2i(x, y)
            if grid.is_in_boundsv(cell):
                grid.set_point_solid(cell, true)

func has_clear_shot(start: Vector3, target: Vector3) -> bool:
    for box in cover:
        if box.intersects_segment(start + Vector3.UP, target + Vector3.UP) != null:
            return false
    return true

func has_clear_sight(start: Vector3, target: Vector3) -> bool:
    # The obstacle itself can be discovered. Cells behind it remain hidden.
    var eye := start + Vector3.UP
    var destination := target + Vector3.UP
    for box in cover:
        if box.intersects_segment(eye, destination) != null and not box.has_point(destination):
            return false
    return true

func is_walkable(cell: Vector2i) -> bool:
    return grid != null and grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)

func _destination_clear(cell: Vector2i, avoid: Array[Vector3]) -> bool:
    if not is_walkable(cell):
        return false
    var point := cell_to_world(cell)
    for position in avoid:
        if point.distance_to(position) < UNIT_SEPARATION:
            return false
    return true

func _nearest_free(cell: Vector2i, radius: int = 7, avoid: Array[Vector3] = []) -> Vector2i:
    if _destination_clear(cell, avoid):
        return cell
    var best := Vector2i(100000, 100000)
    var best_dist := 999999
    for r in range(1, radius + 1):
        for x in range(cell.x - r, cell.x + r + 1):
            for y in range(cell.y - r, cell.y + r + 1):
                var candidate := Vector2i(x, y)
                var d: int = absi(x - cell.x) + absi(y - cell.y)
                if max(abs(x - cell.x), abs(y - cell.y)) != r:
                    continue
                if _destination_clear(candidate, avoid) and d < best_dist:
                    best = candidate
                    best_dist = d
        if best_dist < 999999:
            return best
    return best

func get_path(start: Vector3, requested_goal: Vector3, avoid: Array[Vector3] = []) -> Array[Vector3]:
    if grid == null:
        return []
    var temporary_blocks: Array[Vector2i] = []
    var start_cell := world_to_cell(start)
    for position in avoid:
        var center := world_to_cell(position)
        var radius := ceili(UNIT_SEPARATION / cell_step) + 1
        for x in range(center.x - radius, center.x + radius + 1):
            for y in range(center.y - radius, center.y + radius + 1):
                var cell := Vector2i(x, y)
                if cell == start_cell or not is_walkable(cell):
                    continue
                if cell_to_world(cell).distance_to(position) < UNIT_SEPARATION:
                    grid.set_point_solid(cell, true)
                    temporary_blocks.append(cell)
    var route := _get_static_path(start, requested_goal, avoid)
    for cell in temporary_blocks:
        grid.set_point_solid(cell, false)
    return route

func _get_static_path(start: Vector3, requested_goal: Vector3, avoid: Array[Vector3] = []) -> Array[Vector3]:
    var result: Array[Vector3] = []
    if grid == null:
        return result
    var from_id := world_to_cell(start)
    if not is_walkable(from_id):
        return result
    var target := Vector3(
        clampf(requested_goal.x, -world_limit, world_limit),
        0.0,
        clampf(requested_goal.z, -world_limit, world_limit)
    )
    var to_id := _nearest_free(world_to_cell(target), 7, avoid)
    if not is_walkable(to_id):
        return result
    var cells: Array[Vector2i] = grid.get_id_path(from_id, to_id)
    if cells.is_empty():
        return result
    for cell in cells:
        var point := cell_to_world(cell)
        if not point.is_equal_approx(start):
            result.append(point)
    var exact_target_clear := true
    for position in avoid:
        if target.distance_to(position) < UNIT_SEPARATION:
            exact_target_clear = false
            break
    if exact_target_clear and to_id == world_to_cell(target) and (result.is_empty() or result.back().distance_to(target) > 0.05):
        result.append(target)
    elif result.is_empty():
        result.append(cell_to_world(to_id))
    return _smooth_path(start, result)

func has_walkable_segment(start: Vector3, finish: Vector3) -> bool:
    var cell := world_to_cell(start)
    var end_cell := world_to_cell(finish)
    if not is_walkable(cell) or not is_walkable(end_cell):
        return false
    var from := Vector2(start.x, start.z) / cell_step
    var delta := Vector2(finish.x - start.x, finish.z - start.z) / cell_step
    var step := Vector2i(signi(end_cell.x - cell.x), signi(end_cell.y - cell.y))
    var cross_x := INF
    var cross_y := INF
    var advance_x := INF
    var advance_y := INF
    if step.x != 0:
        cross_x = (float(cell.x) + float(step.x) * 0.5 - from.x) / delta.x
        advance_x = absf(1.0 / delta.x)
    if step.y != 0:
        cross_y = (float(cell.y) + float(step.y) * 0.5 - from.y) / delta.y
        advance_y = absf(1.0 / delta.y)
    while cell != end_cell:
        if is_equal_approx(cross_x, cross_y):
            if not is_walkable(cell + Vector2i(step.x, 0)) or not is_walkable(cell + Vector2i(0, step.y)):
                return false
            cell += step
            cross_x += advance_x
            cross_y += advance_y
        elif cross_x < cross_y:
            cell.x += step.x
            cross_x += advance_x
        else:
            cell.y += step.y
            cross_y += advance_y
        if not is_walkable(cell):
            return false
    return true

func _smooth_path(start: Vector3, route: Array[Vector3]) -> Array[Vector3]:
    var result: Array[Vector3] = []
    var anchor := start
    var index := 0
    while index < route.size():
        var farthest := route.size() - 1
        while farthest > index and not has_walkable_segment(anchor, route[farthest]):
            farthest -= 1
        result.append(route[farthest])
        anchor = route[farthest]
        index = farthest + 1
    return result
