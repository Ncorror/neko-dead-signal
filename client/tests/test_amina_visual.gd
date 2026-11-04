extends Node
## Real Godot import test: experimental Meshy Amina in orbital menu and RTS battle.

var failures: int = 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("RTS_AMINA_VISUAL_TEST_FAIL: " + message)

func _check_full_model(preview_node) -> void:
    var viewport_size: Vector2 = preview_node.preview.size
    var frame := Rect2(Vector2.ONE * 2.0, viewport_size - Vector2.ONE * 4.0)
    for mesh in preview_node.active_model.find_children("*", "MeshInstance3D", true, false):
        if mesh.mesh == null:
            continue
        var box: AABB = mesh.mesh.get_aabb()
        for corner in range(8):
            var point: Vector3 = mesh.to_global(box.get_endpoint(corner))
            if preview_node.camera.is_position_behind(point) or not frame.has_point(preview_node.camera.unproject_position(point)):
                _check(false, "model clipped by preview frame")
                return

func _preview_touch(preview_node, pressed: bool, at: Vector2) -> void:
    var touch := InputEventScreenTouch.new()
    touch.position = at
    touch.pressed = pressed
    preview_node.get_viewport().push_input(touch, true)

func _run() -> void:
    var tree := get_tree()
    tree.current_scene = null
    GameState.set_selection(0, 0, "Люди — флот «Рэйна»", "Амина — разведка и дроны")
    tree.root.size = Vector2i(1280, 720)
    tree.change_scene_to_file("res://scenes/main.tscn")
    await tree.scene_changed
    for frame in range(8):
        await tree.process_frame
    var menu = tree.current_scene
    _check(menu.hero_preview_3d.visible, "selected Amina should have a 3D preview")
    var model: Node3D = menu.hero_preview_3d.active_model
    _check(model != null, "menu 3D model missing")
    if model != null:
        _check(model.scale.y > 2.0, "menu character must be normalized above original size")
        _check(model.position.y > 0.0, "mesh center should be raised to place feet at ground")
    if model != null:
        var preview_node = menu.hero_preview_3d
        var original_yaw: float = preview_node.pivot.rotation.y
        for frame in range(30):
            await tree.process_frame
        _check(is_equal_approx(original_yaw, preview_node.pivot.rotation.y), "preview must remain still without input")
        var center: Vector2 = preview_node.get_global_rect().get_center()
        _preview_touch(preview_node, true, center)
        var drag := InputEventScreenDrag.new()
        drag.position = center + Vector2(60, 0)
        drag.relative = Vector2(60, 0)
        preview_node.get_viewport().push_input(drag, true)
        _preview_touch(preview_node, false, drag.position)
        _check(absf(angle_difference(original_yaw, preview_node.pivot.rotation.y)) > 0.1, "touch drag must rotate the model")
        var released_yaw: float = preview_node.pivot.rotation.y
        for frame in range(20):
            await tree.process_frame
        _check(is_equal_approx(released_yaw, preview_node.pivot.rotation.y), "rotation must stop after finger release")
        for resolution in [Vector2i(1280, 720), Vector2i(2048, 945), Vector2i(1024, 600)]:
            tree.root.size = resolution
            for frame in range(20):
                await tree.process_frame
            for angle in range(0, 360, 45):
                preview_node.pivot.rotation.y = deg_to_rad(float(angle))
                _check_full_model(preview_node)
    menu._deploy()
    await tree.scene_changed
    var op = tree.current_scene
    if op == null or not op.has_method("_issue_move"):
        _check(false, "landing scene was not opened")
        tree.quit(1)
        return
    op.set_physics_process(false)
    op.economy.income_enabled = false # Isolate the existing fixed-budget scenario.
    op.objectives.expanded = false # Retain original landing goals in this regression.
    _check(op.hero.hull == 100 and op.escort.hull == 80,
        "existing RTS combatant statistics changed")
    var mount: Node3D = op.hero.get_node_or_null("StaticCommanderPreview")
    _check(mount != null, "static Meshy Amina missing from actual landing unit")
    var capsule: MeshInstance3D = null
    for child in op.hero.get_children():
        if child is MeshInstance3D:
            capsule = child as MeshInstance3D
            break
    _check(capsule != null and not capsule.visible, "test capsule must be hidden only when mesh loaded")
    _check(not op.animation_players.has(op.hero), "static Amina must not masquerade as rigged")
    if mount != null:
        var model_mesh: Node3D = mount.get_child(0) as Node3D
        _check(model_mesh != null and model_mesh.scale.y > 0.5, "model scale not applied")
        var previous: Vector3 = mount.global_position
        op._issue_move(Vector3(3, 0, 0))
        op._physics_process(0.15)
        _check(mount.global_position.distance_to(previous) > 0.001,
            "mesh must follow its original RTS entity")
        op._inspect_commander()
        _check(is_equal_approx(op.camera_zoom, op.CAMERA_MIN_ZOOM),
            "strategic inspect zoom button does not work")
    if failures == 0:
        print("RTS_AMINA_VISUAL_TEST_PASS")
    tree.quit(0 if failures == 0 else 1)
