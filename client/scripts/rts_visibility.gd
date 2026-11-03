extends RefCounted
## Shared local sight. A complete snapshot is published only after its ray budget is processed.

var bounds := Rect2(-25, -25, 50, 50)
var cell_step := 1.0
var sight_radius := 8.0
var dimensions := Vector2i.ZERO
var visible := PackedByteArray()
var explored := PackedByteArray()
var revision := 0
var last_step_checks := 0
var scanning := false
var _observers: Array[Vector3] = []
var _jobs: Array[Vector3i] = []
var _job_index := 0
var _next_visible := PackedByteArray()

func configure(area: Rect2, step: float = 1.0, radius: float = 8.0) -> void:
    bounds = area
    cell_step = step
    sight_radius = radius
    dimensions = Vector2i(ceili(bounds.size.x / step), ceili(bounds.size.y / step))
    visible.resize(dimensions.x * dimensions.y)
    visible.fill(0)
    explored = visible.duplicate()
    _observers.clear()
    _jobs.clear()
    _job_index = 0
    scanning = false
    revision = 0

func world_to_cell(point: Vector3) -> Vector2i:
    return Vector2i(floori((point.x - bounds.position.x) / cell_step),
        floori((point.z - bounds.position.y) / cell_step))

func cell_to_world(cell: Vector2i) -> Vector3:
    return Vector3(bounds.position.x + (float(cell.x) + 0.5) * cell_step, 0.0,
        bounds.position.y + (float(cell.y) + 0.5) * cell_step)

func _contains(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < dimensions.x and cell.y < dimensions.y

func is_visible(point: Vector3) -> bool:
    var cell := world_to_cell(point)
    return _contains(cell) and visible[cell.y * dimensions.x + cell.x] != 0

func was_explored(point: Vector3) -> bool:
    var cell := world_to_cell(point)
    return _contains(cell) and explored[cell.y * dimensions.x + cell.x] != 0

func request_snapshot(observers: Array[Vector3], force: bool = false) -> bool:
    if scanning:
        return false
    var positions: Array[Vector3] = []
    for point in observers:
        positions.append(Vector3(snappedf(point.x, 0.25), 0.0, snappedf(point.z, 0.25)))
    if not force and positions == _observers:
        return false
    _observers = positions
    _next_visible = PackedByteArray()
    _next_visible.resize(visible.size())
    _next_visible.fill(0)
    _jobs.clear()
    _job_index = 0
    var radius_cells := ceili(sight_radius / cell_step) + 1
    for observer in range(_observers.size()):
        var origin := world_to_cell(_observers[observer])
        for y in range(maxi(0, origin.y - radius_cells), mini(dimensions.y, origin.y + radius_cells + 1)):
            for x in range(maxi(0, origin.x - radius_cells), mini(dimensions.x, origin.x + radius_cells + 1)):
                var cell := Vector2i(x, y)
                if cell_to_world(cell).distance_squared_to(_observers[observer]) <= sight_radius * sight_radius:
                    _jobs.append(Vector3i(x, y, observer))
    scanning = true
    return true

func advance(navigation, budget: int = 128) -> bool:
    last_step_checks = 0
    if not scanning:
        return false
    while _job_index < _jobs.size() and last_step_checks < budget:
        var job := _jobs[_job_index]
        var index := job.y * dimensions.x + job.x
        if _next_visible[index] == 0 and navigation.has_clear_sight(_observers[job.z], cell_to_world(Vector2i(job.x, job.y))):
            _next_visible[index] = 1
        _job_index += 1
        last_step_checks += 1
    if _job_index < _jobs.size():
        return false
    scanning = false
    _jobs.clear()
    if visible == _next_visible:
        return false
    visible = _next_visible
    for i in range(explored.size()):
        if visible[i] != 0:
            explored[i] = 1
    revision += 1
    return true

func mask_image() -> Image:
    var pixels := PackedByteArray()
    pixels.resize(visible.size())
    for i in range(pixels.size()):
        pixels[i] = 255 if visible[i] != 0 else (100 if explored[i] != 0 else 0)
    return Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_L8, pixels)

func clear_current() -> void:
    # Mission defeat cancels queued sight work before physics stops. Never let
    # a snapshot from a dead observer republish its former visible circle.
    scanning = false
    _jobs.clear()
    _job_index = 0
    _observers.clear()
    _next_visible = PackedByteArray()
    visible.fill(0)
    last_step_checks = 0
    revision += 1
