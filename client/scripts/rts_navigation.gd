extends RefCounted
## Small flat-map RTS navigation. Uses AStarGrid2D and inflated obstacle footprints.
## Prototype implementation for deterministic path requests, not final MMO-scale navigation.

const DEFAULT_STEP := 1.0
var grid: AStarGrid2D
var cell_step: float = DEFAULT_STEP
var world_limit: float = 24.0

func configure(limit: float = 24.0, step: float = DEFAULT_STEP) -> void:
    world_limit = limit
    cell_step = step
    var radius := ceili(world_limit / cell_step)
    grid = AStarGrid2D.new()
    grid.region = Rect2i(-radius, -radius, radius * 2 + 1, radius * 2 + 1)
    grid.cell_size = Vector2.ONE * cell_step
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
    grid.update()

func world_to_cell(point: Vector3) -> Vector2i:
    return Vector2i(roundi(point.x / cell_step), roundi(point.z / cell_step))

func cell_to_world(cell: Vector2i) -> Vector3:
    return Vector3(float(cell.x) * cell_step, 0.0, float(cell.y) * cell_step)

func set_blocked_box(center: Vector3, box_size: Vector3, clearance: float = 0.75) -> void:
    assert(grid != null)
    var min_x := ceili((center.x - box_size.x * 0.5 - clearance) / cell_step)
    var max_x := floori((center.x + box_size.x * 0.5 + clearance) / cell_step)
    var min_y := ceili((center.z - box_size.z * 0.5 - clearance) / cell_step)
    var max_y := floori((center.z + box_size.z * 0.5 + clearance) / cell_step)
    for x in range(min_x, max_x + 1):
        for y in range(min_y, max_y + 1):
            var cell := Vector2i(x, y)
            if grid.is_in_boundsv(cell):
                grid.set_point_solid(cell, true)

func is_walkable(cell: Vector2i) -> bool:
    return grid != null and grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)

func _nearest_free(cell: Vector2i, radius: int = 7) -> Vector2i:
    if is_walkable(cell):
        return cell
    var best := Vector2i(100000, 100000)
    var best_dist := 999999
    for r in range(1, radius + 1):
        for x in range(cell.x - r, cell.x + r + 1):
            for y in range(cell.y - r, cell.y + r + 1):
                var candidate := Vector2i(x, y)
                var d := abs(x - cell.x) + abs(y - cell.y)
                if max(abs(x - cell.x), abs(y - cell.y)) != r:
                    continue
                if is_walkable(candidate) and d < best_dist:
                    best = candidate
                    best_dist = d
        if best_dist < 999999:
            return best
    return best

func get_path(start: Vector3, requested_goal: Vector3) -> Array[Vector3]:
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
    var to_id := _nearest_free(world_to_cell(target))
    if not is_walkable(to_id):
        return result
    var cells: Array[Vector2i] = grid.get_id_path(from_id, to_id)
    if cells.is_empty():
        return result
    for cell in cells:
        if cell != from_id:
            result.append(cell_to_world(cell))
    if to_id == world_to_cell(target) and (result.is_empty() or result.back().distance_to(target) > 0.05):
        result.append(target)
    return result
