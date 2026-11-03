extends RefCounted
## Paid sites, preview and owned structures. Player orders never belong to this service.

const FACTORY := &"factory"
const OUTPOST := &"outpost"
const WORK := preload("res://scripts/rts_production.gd")
const CLEARANCE := 0.75
const DEFINITIONS := {
    FACTORY: {"cost": 200, "seconds": 8.0, "size": Vector3(3.2, 1.6, 3.2)},
    OUTPOST: {"cost": 100, "seconds": 5.0, "size": Vector3(2, 0.8, 2)}
}

var buildings: Array[Dictionary] = []
var serial := 1
var placing: StringName = &""
var candidate := Vector3.ZERO
var has_candidate := false
var preview: MeshInstance3D
var enabled := true
var connectivity_requests := 0
var _connectivity_key: Array = []
var _connected_cells: Dictionary = {}

func title(kind: StringName) -> String:
    if kind == FACTORY:
        return "ПОЛЕВОЙ ЗАВОД" if GameState.faction_index == 0 else "УЗЕЛ СИНТЕЗА"
    return "РАЗВЕДПОСТ" if GameState.faction_index == 0 else "СЕНСОРНЫЙ ШПИЛЬ"

func register_initial(node: Node3D, work) -> void:
    buildings.append({"id": 1, "kind": FACTORY, "node": node, "work": work,
        "remaining": 0.0, "ready": true, "cost": 0, "label": null,
        "exit": node.position + Vector3(4, 0, 0), "rally": node.position + Vector3(4, 0, -4)})

func begin(kind: StringName, op) -> void:
    if not enabled or not DEFINITIONS.has(kind) or op.outcome != op.Outcome.ACTIVE:
        return
    cancel_preview()
    placing = kind
    has_candidate = false
    preview = op._make_box(Vector3.ZERO, DEFINITIONS[kind]["size"], Color.WHITE)
    preview.name = "BuildingPreview"
    preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mat = preview.material_override
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    preview.hide()

func cancel_preview() -> void:
    if is_instance_valid(preview):
        preview.queue_free()
    preview = null
    placing = &""
    has_candidate = false

func choose(point: Vector3, op) -> void:
    if placing == &"":
        return
    candidate = Vector3(roundf(point.x), 0, roundf(point.z))
    has_candidate = true
    refresh_preview(op)

func refresh_preview(op) -> String:
    if placing == &"" or not has_candidate:
        return "Коснись свободного места на видимой земле."
    var reason := validate(placing, candidate, op)
    preview.position = candidate + Vector3.UP * (float(DEFINITIONS[placing]["size"].y) * 0.5 + 0.05)
    preview.material_override.albedo_color = Color(0.25, 0.95, 0.85, 0.45) if reason.is_empty() else Color(1, 0.25, 0.22, 0.45)
    preview.show()
    return reason

func _cells(at: Vector3, size: Vector3) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for x in range(ceili(at.x - size.x * 0.5 - CLEARANCE), floori(at.x + size.x * 0.5 + CLEARANCE) + 1):
        for z in range(ceili(at.z - size.z * 0.5 - CLEARANCE), floori(at.z + size.z * 0.5 + CLEARANCE) + 1):
            cells.append(Vector2i(x, z))
    return cells

func validate(kind: StringName, at: Vector3, op) -> String:
    if not enabled or op.outcome != op.Outcome.ACTIVE or op.units.is_empty():
        return "Строительство недоступно после окончания операции."
    if not DEFINITIONS.has(kind):
        return "Неизвестная постройка."
    var spec: Dictionary = DEFINITIONS[kind]
    var size: Vector3 = spec["size"]
    if absf(at.x) + size.x * 0.5 + CLEARANCE > op.MAP_LIMIT or absf(at.z) + size.z * 0.5 + CLEARANCE > op.MAP_LIMIT:
        return "Постройка выходит за границу карты."
    # Every part of the footprint must be currently visible, not just explored.
    var first: Vector2i = op.visibility.world_to_cell(at - size * 0.5)
    var last: Vector2i = op.visibility.world_to_cell(at + size * 0.5)
    for x in range(first.x, last.x + 1):
        for z in range(first.y, last.y + 1):
            if not op.visibility.is_visible(op.visibility.cell_to_world(Vector2i(x, z))):
                return "Нужен текущий обзор всей площадки."
    var cells := _cells(at, size)
    for cell in cells:
        if not op.navigation.is_walkable(cell):
            return "Место занято постройкой или препятствием."
    var clearance := Rect2(Vector2(at.x - size.x * 0.5 - CLEARANCE, at.z - size.z * 0.5 - CLEARANCE),
        Vector2(size.x + CLEARANCE * 2, size.z + CLEARANCE * 2)).grow(0.6)
    for unit in op.units:
        if clearance.has_point(Vector2(unit.position.x, unit.position.z)):
            return "Сначала отведи бойца с площадки."
    if op.sentry.hull > 0 and clearance.has_point(Vector2(op.sentry.position.x, op.sentry.position.z)):
        return "Площадка занята."
    for collection in [op.crates, op.supply_caches]:
        for supply in collection:
            if clearance.grow(0.3).has_point(Vector2(supply.position.x, supply.position.z)):
                return "Нельзя перекрывать контейнер с ресурсами."
    if op.production.balance < int(spec["cost"]):
        return "Недостаточно ресурсов: нужно %d." % int(spec["cost"])
    var targets: Array[Vector3] = []
    for unit in op.units:
        targets.append(unit.position)
        if op.unit_paths.has(unit):
            targets.append(op.unit_paths[unit].back())
        for order in op.unit_orders.get(unit, []):
            if order["type"] == "move":
                targets.append(order["target"])
    for entry in buildings:
        if entry["kind"] == FACTORY:
            targets.append(entry["exit"])
            targets.append(entry["rally"])
    if kind == FACTORY:
        targets.append(at + Vector3(4, 0, 0))
        targets.append(at + Vector3(4, 0, -4))
    for collection in [op.crates, op.supply_caches]:
        for supply in collection:
            targets.append(supply.position)
    # Test connectivity without publishing a changed navigation/visibility state.
    for cell in cells:
        op.navigation.grid.set_point_solid(cell, true)
    var anchor: Vector2i = op.navigation.world_to_cell(buildings[0]["exit"])
    var key: Array = [kind, at, op.navigation.topology_revision, anchor]
    if key != _connectivity_key:
        _connectivity_key = key
        _connected_cells.clear()
    var connected: bool = op.navigation.is_walkable(anchor)
    for point in targets:
        var goal: Vector2i = op.navigation.world_to_cell(point)
        if not connected or not op.navigation.is_walkable(goal):
            connected = false
            break
        if not _connected_cells.has(goal):
            connectivity_requests += 1
            _connected_cells[goal] = not op.navigation.grid.get_id_path(anchor, goal).is_empty()
        if not _connected_cells[goal]:
            connected = false
            break
    for cell in cells:
        op.navigation.grid.set_point_solid(cell, false)
    if not connected:
        return "Перекрывается выход базы, маршрут или доступ к ресурсам."
    return ""

func confirm(op) -> bool:
    if placing == &"" or not has_candidate:
        return false
    var kind := placing
    var at := candidate
    var reason := validate(kind, at, op)
    if not reason.is_empty() or not op.production.account.spend(DEFINITIONS[kind]["cost"]):
        return false
    serial += 1
    var spec: Dictionary = DEFINITIONS[kind]
    var node := Node3D.new()
    node.name = "Building_%d" % serial
    node.position = at
    op.add_child(node)
    var body := Node3D.new()
    node.add_child(body)
    var color := Color("#426877") if GameState.faction_index == 0 else Color("#75608d")
    op._make_box(Vector3.ZERO, spec["size"], color, body)
    if kind == FACTORY:
        op._make_box(Vector3(0, 1.6, 0), Vector3(2.3, 0.35, 2.3), color.lightened(0.2), body)
        op._make_box(Vector3(1.55, 0.4, 0), Vector3(0.15, 0.8, 1.3), Color("#62ecf0"), body)
    else:
        op._make_box(Vector3(0, 0.8, 0), Vector3(0.25, 2, 0.25), Color("#62ecf0"), body)
        op._make_box(Vector3(0, 2.5, 0), Vector3(1.1, 0.25, 1.1), color.lightened(0.4), body)
    var label := Label3D.new()
    label.position.y = 3.3
    label.pixel_size = 0.012
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    node.add_child(label)
    var work = WORK.new() if kind == FACTORY else null
    if work != null:
        work.account = op.production.account
    var entry := {"id": serial, "kind": kind, "node": node, "body": body, "work": work,
        "remaining": spec["seconds"], "ready": false, "cost": spec["cost"], "label": label,
        "exit": at + Vector3(4, 0, 0), "rally": at + Vector3(4, 0, -4)}
    buildings.append(entry)
    op.navigation.set_blocked_box(at, spec["size"], CLEARANCE, kind == FACTORY)
    _update_visual(entry)
    cancel_preview()
    op._replan_after_building()
    op._update_visibility(0.0, true)
    op.build_panel.inspect(entry)
    op._update_status()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("construction", "placed", {"id": serial, "kind": str(kind), "at": str(at), "balance": op.production.balance})
    return true

func _update_visual(entry: Dictionary) -> void:
    var spec: Dictionary = DEFINITIONS[entry["kind"]]
    var fraction := 1.0 - float(entry["remaining"]) / float(spec["seconds"])
    entry["body"].scale.y = 0.25 + 0.75 * fraction
    entry["label"].text = "%s · %d%s" % [title(entry["kind"]), entry["id"],
        "" if entry["ready"] else "\nСТРОИТСЯ · %d%%" % int(fraction * 100)]
    entry["label"].modulate = Color("#9ce5e0") if entry["ready"] else Color("#ffd385")

func tick(delta: float, op) -> void:
    if not enabled:
        return
    for entry in buildings:
        if entry["ready"]:
            continue
        entry["remaining"] = maxf(0, entry["remaining"] - maxf(0, delta))
        if entry["remaining"] <= 0:
            entry["ready"] = true
            op._update_visibility(0.0, true)
            if RTSDiagnostics.enabled:
                RTSDiagnostics.event("construction", "completed", {"id": entry["id"], "kind": str(entry["kind"])})
        _update_visual(entry)

func cancel_site(entry: Dictionary, op) -> bool:
    if not enabled or not buildings.has(entry) or entry["ready"] or op.outcome != op.Outcome.ACTIVE:
        return false
    _remove_site(entry, op)
    op._update_visibility(0.0, true)
    op._update_status()
    return true

func _remove_site(entry: Dictionary, op) -> void:
    op.production.account.refund(entry["cost"])
    op.navigation.remove_blocked_box(entry["node"].position)
    buildings.erase(entry)
    entry["node"].queue_free()
    if RTSDiagnostics.enabled:
        RTSDiagnostics.event("construction", "canceled", {"id": entry["id"], "refund": entry["cost"]})

func observers() -> Array[Vector3]:
    var points: Array[Vector3] = []
    if enabled:
        for entry in buildings:
            if entry["ready"] and entry["kind"] == OUTPOST:
                points.append(entry["node"].position)
    return points

func stop(op) -> int:
    if not enabled:
        return 0
    enabled = false
    cancel_preview()
    var refunded := 0
    for entry in buildings.duplicate():
        if not entry["ready"]:
            refunded += int(entry["cost"])
            _remove_site(entry, op)
        if entry["work"] != null:
            refunded += entry["work"].stop()
    return refunded
