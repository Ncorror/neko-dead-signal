extends Node3D
## Local 3D landing prototype. NO multiplayer, AI, resource economy or fog-of-war yet.

const MAP_LIMIT := 24.0
const HERO_SPEED := 7.0
const RTS_SPEED := 11.0

var hero: Node3D
var view_camera: Camera3D
var rts_focus: Vector3 = Vector3.ZERO
var touch_direction: Vector2 = Vector2.ZERO
var hero_mode: bool = true
var crates: Array[Node3D] = []
var resources_collected: int = 0
var status: Label
var mode_button: Button

func _ready() -> void:
    _create_world()
    _create_ui()
    _update_mode_label()
    view_camera.global_position = Vector3(0, 16, 18)
    _update_camera(1.0)
    print("OPERATION_START faction=", GameState.faction_name, " officer=", GameState.officer_name)

func _create_world() -> void:
    var ground := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(50, 50)
    ground.mesh = plane
    ground.material_override = _material(Color("#283b45"))
    add_child(ground)

    var sunlight := DirectionalLight3D.new()
    sunlight.rotation_degrees = Vector3(-52, 25, 0)
    sunlight.light_energy = 1.6
    add_child(sunlight)

    hero = Node3D.new()
    hero.name = "StartingOfficer"
    add_child(hero)
    var body := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.55
    capsule.height = 1.9
    body.mesh = capsule
    body.position.y = 0.95
    body.material_override = _material(Color("#75c8f1") if GameState.faction_index == 0 else Color("#c69efa"))
    hero.add_child(body)

    for p in [Vector3(-12, 0, -8), Vector3(9, 0, 7), Vector3(16, 0, -12)]:
        _make_box(p, Vector3(3, 1.5, 3), Color("#4f6269"))
    for p in [Vector3(5, 0, 2), Vector3(-8, 0, 11), Vector3(13, 0, -6)]:
        var crate := _make_box(p, Vector3(1.25, 1, 1.25), Color("#e7b65b"))
        crate.name = "PrototypeSupplyCrate"
        crates.append(crate)

    view_camera = Camera3D.new()
    view_camera.current = true
    view_camera.fov = 55.0
    add_child(view_camera)

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.9
    return mat

func _make_box(pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var block := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    block.mesh = mesh
    block.position = pos + Vector3(0, size.y * 0.5, 0)
    block.material_override = _material(color)
    add_child(block)
    return block

func _create_ui() -> void:
    var overlay := CanvasLayer.new()
    add_child(overlay)
    var root := Control.new()
    overlay.add_child(root)
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    var top := VBoxContainer.new()
    root.add_child(top)
    top.anchor_right = 1.0
    top.offset_left = 14
    top.offset_top = 10
    top.offset_right = -14
    status = Label.new()
    status.add_theme_font_size_override("font_size", 19)
    top.add_child(status)

    var actions := HBoxContainer.new()
    top.add_child(actions)
    mode_button = Button.new()
    mode_button.pressed.connect(_toggle_mode)
    actions.add_child(mode_button)
    var return_button := Button.new()
    return_button.text = "На корабль"
    return_button.pressed.connect(_back_to_ship)
    actions.add_child(return_button)

    var bottom := HBoxContainer.new()
    root.add_child(bottom)
    bottom.anchor_top = 1.0
    bottom.anchor_bottom = 1.0
    bottom.offset_left = 12
    bottom.offset_top = -80
    bottom.offset_bottom = -12
    for entry in [
        ["◀", Vector2(-1, 0)], ["▲", Vector2(0, -1)],
        ["▼", Vector2(0, 1)], ["▶", Vector2(1, 0)]
    ]:
        var button := Button.new()
        button.text = entry[0]
        button.custom_minimum_size = Vector2(72, 56)
        button.button_down.connect(_touch_down.bind(entry[1]))
        button.button_up.connect(_touch_up)
        bottom.add_child(button)

func _touch_down(direction: Vector2) -> void:
    touch_direction = direction

func _touch_up() -> void:
    touch_direction = Vector2.ZERO

func _toggle_mode() -> void:
    hero_mode = not hero_mode
    if not hero_mode:
        rts_focus = hero.position
    _update_mode_label()
    print("CONTROL_MODE ", "HERO" if hero_mode else "RTS")

func _update_mode_label() -> void:
    mode_button.text = "Режим: герой" if hero_mode else "Режим: RTS"
    status.text = "%s | %s | контейнеры: %d | ресурсы: %d" % [
        GameState.faction_name, GameState.officer_name,
        3 - crates.size(), resources_collected
    ]

func _process(delta: float) -> void:
    var direction := touch_direction
    if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        direction.x -= 1
    if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        direction.x += 1
    if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
        direction.y -= 1
    if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
        direction.y += 1
    direction = direction.limit_length()

    if hero_mode:
        hero.position.x = clamp(hero.position.x + direction.x * HERO_SPEED * delta, -MAP_LIMIT, MAP_LIMIT)
        hero.position.z = clamp(hero.position.z + direction.y * HERO_SPEED * delta, -MAP_LIMIT, MAP_LIMIT)
        _check_crates()
    else:
        rts_focus.x = clamp(rts_focus.x + direction.x * RTS_SPEED * delta, -MAP_LIMIT, MAP_LIMIT)
        rts_focus.z = clamp(rts_focus.z + direction.y * RTS_SPEED * delta, -MAP_LIMIT, MAP_LIMIT)
    _update_camera(delta)

func _update_camera(delta: float) -> void:
    var focus := hero.position if hero_mode else rts_focus
    var offset := Vector3(0, 10, 11) if hero_mode else Vector3(0, 26, 27)
    var destination := focus + offset
    view_camera.global_position = view_camera.global_position.lerp(destination, minf(1.0, delta * 7.0))
    view_camera.look_at(focus + Vector3.UP, Vector3.UP)

func _check_crates() -> void:
    for crate in crates.duplicate():
        if hero.position.distance_to(Vector3(crate.position.x, 0, crate.position.z)) < 1.8:
            crates.erase(crate)
            crate.queue_free()
            resources_collected += 100
            print("CONTAINER_PICKUP value=100 total=", resources_collected)
            _update_mode_label()

func _back_to_ship() -> void:
    print("OPERATION_END collected=", resources_collected)
    get_tree().change_scene_to_file("res://scenes/main.tscn")
