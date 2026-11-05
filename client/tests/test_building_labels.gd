extends Node
## Project actual Label3D meshes in a dense base at native sizes and zoom levels.

var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_BUILDING_LABELS_TEST_FAIL " + message)

func _mesh_bounds(camera: Camera3D, label: Label3D) -> Rect2:
    var mesh := label.generate_triangle_mesh()
    if mesh == null:
        return Rect2()
    var vertices := mesh.get_faces()
    if vertices.is_empty():
        return Rect2()
    var rect := Rect2(camera.unproject_position(label.global_position
        + camera.global_basis.x * vertices[0].x + camera.global_basis.y * vertices[0].y), Vector2.ZERO)
    for vertex in vertices:
        rect = rect.expand(camera.unproject_position(label.global_position
            + camera.global_basis.x * vertex.x + camera.global_basis.y * vertex.y))
    return rect

func _settle(op) -> void:
    for frame in range(3):
        await get_tree().process_frame
        op._process(0)

func _check_base(faction: int, extra_generator: bool) -> void:
    GameState.set_selection(faction, 0, "Люди" if faction == 0 else "Саари", "Амина" if faction == 0 else "Сэйра")
    get_tree().change_scene_to_file("res://scenes/operation.tscn")
    await get_tree().scene_changed
    var op = get_tree().current_scene
    op.set_physics_process(false)
    op.set_process(false)
    op.production.credit(5000)
    op.escort.position = Vector3(85, 0, 80)
    # One generator deliberately leaves late buildings without power, so
    # the extra warning line is measured too. Factories occupy the right
    # column with their exit/rally lane outside the block.
    var kinds: Array[StringName] = [&"extractor", &"generator", &"factory",
        &"extractor", &"outpost", &"factory", &"outpost", &"extractor", &"factory"]
    if extra_generator:
        kinds[3] = &"generator"
    for i in range(9):
        var at := Vector3(20 + (i % 3) * 6, 0, 44 + floori(i / 3.0) * 6)
        op.hero.position = at + Vector3(0, 0, 5)
        op._update_visibility(0, true)
        var kind: StringName = kinds[i]
        op.construction.begin(kind, op)
        op.construction.choose(at, op)
        var reason: String = op.construction.validate(kind, at, op)
        _check(reason.is_empty() and op.construction.confirm(op), "dense-base fixture %d %s at %s rejected: %s" % [i, kind, at, reason])
    op.construction.tick(9, op)
    op.economy.recalculate(op)
    # Cover both completed/powered captions and a warning with an extra line.
    var warning_seen := false
    for entry in op.construction.buildings:
        if entry["label"] != null:
            op.construction._update_visual(entry)
            warning_seen = warning_seen or entry["label"].text.contains("НЕТ ПИТАНИЯ")
    _check(warning_seen != extra_generator, "dense-base fixture did not exercise the expected power state")
    op.build_panel.hide()
    op.production_panel.hide()
    var topology: int = op.navigation.topology_revision
    var balance: int = op.production.balance
    var positions: Array[Vector3] = []
    for entry in op.construction.buildings:
        positions.append(entry["node"].position)
    for size in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
        get_tree().root.size = size
        for zoom in [10.0, 22.0, 37.0]:
            op.camera_focus = Vector3(26, 0, 50)
            op.camera_zoom = zoom
            op.camera_pose_initialized = false
            await _settle(op)
            var visible: Array[Rect2] = []
            var visible_ids: Array[int] = []
            for entry in op.construction.buildings:
                var label: Label3D = entry["map_label"]
                var anchor: Vector3 = entry["node"].to_global(label.get_meta("map_anchor"))
                if op.view_camera.is_position_behind(anchor) or not get_viewport().get_visible_rect().has_point(op.view_camera.unproject_position(anchor)):
                    continue
                var rect := _mesh_bounds(op.view_camera, label)
                _check(rect.has_area(), "actual text mesh has no measurable bounds")
                _check(get_viewport().get_visible_rect().encloses(rect), "caption clipped at " + str(size) + " zoom=" + str(zoom))
                for other_index in range(visible.size()):
                    _check(not rect.intersects(visible[other_index]), "dense-base captions %d/%d overlap at %s zoom=%s: %s / %s" % [
                        entry["id"], visible_ids[other_index], size, zoom, rect, visible[other_index]])
                visible.append(rect)
                visible_ids.append(entry["id"])
                _check(not label.text.is_empty() and label.is_visible_in_tree(), "decluttering hid a building caption")
            _check(visible.size() >= 3, "dense-base view did not exercise neighbouring captions")
            var before: Array[Vector3] = []
            for entry in op.construction.buildings:
                before.append(entry["map_label"].position)
            await _settle(op)
            for i in range(before.size()):
                _check(before[i].is_equal_approx(op.construction.buildings[i]["map_label"].position), "stationary captions drifted between frames")
        # Panning must recalculate captions while buildings stay in place.
        op.camera_focus += Vector3(5, 0, 3)
        op.camera_pose_initialized = false
        await _settle(op)
    for i in range(positions.size()):
        _check(op.construction.buildings[i]["node"].position == positions[i], "caption layout moved a structure")
    _check(op.navigation.topology_revision == topology and op.production.balance == balance,
        "caption layout changed navigation or the resource balance")
    # The original headquarters participates too, and retains its full card.
    op.camera_focus = op.factory.position
    op.camera_pose_initialized = false
    await _settle(op)
    op._open_factory()
    _check(op.production_panel.title.text.begins_with("ШТАБ" if faction == 0 else "КОМАНДНЫЙ УЗЕЛ"),
        "caption wrapping changed the full headquarters title")

func _run() -> void:
    get_tree().current_scene = null
    for faction in [0, 1]:
        for extra_generator in [true, false]:
            await _check_base(faction, extra_generator)
    if failures == 0:
        print("RTS_BUILDING_LABELS_TEST_PASS factions=2 bases=4 buildings=10 sizes=3 zooms=3 power=both overlap=none stationary=stable state=unchanged")
    get_tree().quit(0 if failures == 0 else 1)
