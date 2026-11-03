extends Control
## Shared fog and known targets only. A minimap gesture moves the camera, never units.

var operation
var refresh_age := 0.0
var touch_index := -1

func install(owner_node) -> void:
    operation = owner_node
    name = "TacticalMinimap"
    mouse_filter = Control.MOUSE_FILTER_STOP
    clip_contents = true
    texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func map_rect() -> Rect2:
    return Rect2(7, 25, size.x - 14, size.y - 32)

func world_to_map(point: Vector3) -> Vector2:
    var bounds: Rect2 = operation.visibility.bounds
    return map_rect().position + (Vector2(point.x, point.z) - bounds.position) / bounds.size * map_rect().size

func _draw() -> void:
    if operation == null:
        return
    draw_rect(Rect2(Vector2.ZERO, size), Color("#0b1e29"))
    var area: Vector2 = operation.visibility.bounds.size
    draw_string(ThemeDB.fallback_font, Vector2(8, 18), "КАРТА  ·  %d × %d" % [int(area.x), int(area.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#9ac8ce"))
    draw_texture_rect(operation.sight_texture, map_rect(), false, Color("#6f9ba9"))
    draw_rect(map_rect(), Color("#41606b"), false, 1)
    for collection in [operation.crates, operation.supply_caches]:
        for crate in collection:
            if operation.visibility.is_visible(crate.position):
                draw_circle(world_to_map(crate.position), 2.2, Color("#e7b65b"))
    var base: Vector2 = world_to_map(operation.factory.position)
    draw_rect(Rect2(base - Vector2.ONE * 3, Vector2.ONE * 6), Color("#65dfe3"))
    for unit in operation.units:
        draw_circle(world_to_map(unit.position), 2.5, Color("#62ecf0") if unit == operation.hero else Color("#a3cfb8"))
    if operation.sentry.hull > 0 and operation.visibility.is_visible(operation.sentry.position):
        draw_circle(world_to_map(operation.sentry.position), 3.0, Color("#ff9257"))
    var view: Vector2 = get_viewport().get_visible_rect().size
    var outline := PackedVector2Array()
    for corner in [Vector2.ZERO, Vector2(view.x, 0), view, Vector2(0, view.y), Vector2.ZERO]:
        var ground: Variant = operation._screen_to_ground(corner)
        if ground != null:
            var point := world_to_map(ground)
            outline.append(point.clamp(map_rect().position, map_rect().end))
    if outline.size() == 5:
        draw_polyline(outline, Color("#c9f0ed"), 1.0, true)

func _process(delta: float) -> void:
    refresh_age += delta
    if refresh_age >= 0.15:
        refresh_age = 0.0
        queue_redraw()

func _navigate(at: Vector2) -> void:
    var rect := map_rect()
    var ratio := (at - rect.position) / rect.size
    ratio = ratio.clamp(Vector2.ZERO, Vector2.ONE)
    var bounds: Rect2 = operation.visibility.bounds
    var point := bounds.position + ratio * bounds.size
    operation.camera_focus = Vector3(point.x, 0, point.y)
    operation._clamp_camera_focus()
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event.device == InputEvent.DEVICE_ID_EMULATION:
        return
    if event is InputEventScreenTouch:
        if event.pressed and not event.canceled and touch_index == -1 and map_rect().has_point(event.position):
            touch_index = event.index
            _navigate(event.position)
        elif event.index == touch_index:
            touch_index = -1
        accept_event()
    elif event is InputEventScreenDrag and event.index == touch_index:
        _navigate(event.position)
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        if event.pressed and map_rect().has_point(event.position):
            _navigate(event.position)
        accept_event()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
        touch_index = -1
