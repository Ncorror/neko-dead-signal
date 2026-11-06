extends Node3D
## Frontier v1 art modules over the physically verified 0.0.25 footprints.

const TERRAIN := preload("res://scripts/surface_terrain.gd")
const ASSETS := preload("res://scripts/surface_assets.gd")
var terrain = TERRAIN.new()
var kit = ASSETS.new()
var navigation
var terrain_body: StaticBody3D
var obstacles: Array[Dictionary] = []
var site_markers: Array[Node3D] = []
var npc: Node3D
var vegetation: MultiMeshInstance3D
var material_cache: Dictionary = {}

func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
    var key := color.to_html() + str(glow)
    if material_cache.has(key):
        return material_cache[key]
    var value := StandardMaterial3D.new()
    value.albedo_color = color
    value.roughness = 0.9
    if glow > 0:
        value.emission_enabled = true
        value.emission = color
        value.emission_energy_multiplier = glow
    material_cache[key] = value
    return value

func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, glow: float = 0.0) -> MeshInstance3D:
    var result := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    result.mesh = shape
    result.position = at + Vector3.UP * size.y * 0.5
    result.material_override = material(color, glow)
    parent.add_child(result)
    return result

func caption(parent: Node3D, text: String, y: float) -> Label3D:
    var label := Label3D.new()
    label.text = text
    label.position.y = y
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.pixel_size = 0.01
    label.outline_size = 4
    label.visibility_range_end = 44
    parent.add_child(label)
    return label

func obstacle(at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
    var point: Vector3 = terrain.on_ground(at, 0)
    var result := box(self, point, size, color)
    _block(point, size)
    return result

func _block(point: Vector3, size: Vector3) -> void:
    navigation.set_blocked_box(point, size, 0.7)
    var body := StaticBody3D.new()
    body.position = point + Vector3.UP * size.y * 0.5
    body.collision_layer = 2
    body.collision_mask = 0
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    add_child(body)
    obstacles.append({"at": point, "size": size, "body": body})

func _module_obstacle(id: String, at: Vector3, size: Vector3) -> MeshInstance3D:
    var point: Vector3 = terrain.on_ground(at, 0)
    var visual: MeshInstance3D = kit.place(self, id, point, size)
    visual.set_meta("collision_size", size)
    _block(point, size)
    return visual

func build(nav) -> void:
    navigation = nav
    terrain.build()
    terrain.configure_navigation(navigation)
    var environment := WorldEnvironment.new()
    var sky := Environment.new()
    sky.background_mode = Environment.BG_COLOR
    sky.background_color = Color("#22333f")
    sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    sky.ambient_light_color = Color("#b7c4ce")
    sky.ambient_light_energy = 0.62
    environment.environment = sky
    add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -32, 0)
    sun.light_color = Color("#fff1d3")
    sun.light_energy = 1.0
    add_child(sun)
    var ground := MeshInstance3D.new()
    ground.name = "Terrain128"
    ground.mesh = terrain.mesh
    var ground_material := material(Color.WHITE).duplicate() as StandardMaterial3D
    ground_material.vertex_color_use_as_albedo = true
    ground.material_override = ground_material
    add_child(ground)
    terrain_body = StaticBody3D.new()
    terrain_body.name = "TerrainCollision"
    terrain_body.collision_layer = 1
    terrain_body.collision_mask = 0
    var collision := CollisionShape3D.new()
    var shape: ConcavePolygonShape3D = terrain.mesh.create_trimesh_shape()
    shape.backface_collision = true
    collision.shape = shape
    terrain_body.add_child(collision)
    add_child(terrain_body)
    for i in range(TERRAIN.SITES.size()):
        var marker := Node3D.new()
        marker.position = terrain.on_ground(TERRAIN.SITES[i])
        marker.name = "SurfaceSite_%d" % i
        add_child(marker)
        caption(marker, "%02d · %s" % [i + 1, TERRAIN.SITE_NAMES[i]], 4)
        site_markers.append(marker)
    _outpost()
    _wreck()
    _salvage()
    _ruins()
    _canyon()
    _scatter()

func _outpost() -> void:
    var pad: Vector3 = terrain.on_ground(TERRAIN.SITES[0], -0.02)
    kit.place(self, "landing_pad", pad)
    var hq := _module_obstacle("habitat", Vector3(-50, 0, 41), Vector3(6, 3.2, 6))
    hq.rotation.y = PI
    _module_obstacle("generator", Vector3(-48, 0, 32), Vector3(3, 2.5, 2.5))
    for at in [Vector3(-34.5, 0, 29.5), Vector3(-31.5, 0, 33.5)]:
        _module_obstacle("gate_post", at, Vector3(0.7, 3.2, 0.7))
    for x in [-53, -49, -45]:
        _module_obstacle("wall", Vector3(x, 0, 28), Vector3(3.3, 1.4, 0.7))
    npc = Node3D.new()
    npc.name = "SurfaceVega"
    npc.position = terrain.on_ground(Vector3(-42, 0, 33))
    add_child(npc)
    var person := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.38
    capsule.height = 1.8
    person.mesh = capsule
    person.position.y = 0.9
    person.material_override = material(Color("#cfb375"))
    npc.add_child(person)
    caption(npc, "ВЕГА · СВЯЗИСТ", 2.7)
    navigation.set_blocked_box(npc.position, Vector3(0.8, 1.8, 0.8), 0.6)

func _wreck() -> void:
    _module_obstacle("wreck_hull", Vector3(-11, 0, 11), Vector3(11, 2.5, 3.4))
    _module_obstacle("wreck_wing", Vector3(-6, 0, 7), Vector3(4.5, 0.45, 4))
    _module_obstacle("wreck_engine", Vector3(-18, 0, 13), Vector3(2.8, 2.4, 2.8))

func _salvage() -> void:
    for at in [Vector3(34, 0, 22), Vector3(42, 0, 20), Vector3(39, 0, 9)]:
        _module_obstacle("cargo", at, Vector3(4.4, 2.4, 2.8))
    _module_obstacle("gantry_column", Vector3(47, 0, 12), Vector3(0.8, 7, 0.8))
    _module_obstacle("gantry_column", Vector3(47, 0, 24), Vector3(0.8, 7, 0.8))
    var first: Vector3 = terrain.on_ground(Vector3(47, 0, 12), 7)
    var last: Vector3 = terrain.on_ground(Vector3(47, 0, 24), 7)
    var beam: MeshInstance3D = kit.place(self, "gantry_beam", (first + last) * 0.5 - Vector3.UP * 0.25)
    beam.rotation.x = -atan2(last.y - first.y, 12)

func _ruins() -> void:
    for i in range(6):
        var angle := float(i) * TAU / 6
        var at: Vector3 = TERRAIN.SITES[3] + Vector3(cos(angle), 0, sin(angle)) * 8
        _module_obstacle("obelisk", at, Vector3(1.7, 4.0 + float(i % 3), 1.7))
    _module_obstacle("terminal", Vector3(25, 0, -38), Vector3(1.4, 1.7, 1.4))

func _canyon() -> void:
    for x in [-39, -29]:
        _module_obstacle("cave_pillar", Vector3(x, 0, -40), Vector3(3.5, 6, 4))
    var left: Vector3 = terrain.on_ground(Vector3(-39, 0, -40), 5.4)
    var right: Vector3 = terrain.on_ground(Vector3(-29, 0, -40), 5.4)
    var arch: MeshInstance3D = kit.place(self, "cave_arch", (left + right) * 0.5)
    arch.rotation.z = atan2(right.y - left.y, 10)
    # The entrance is a landmark, not a dungeon transition in this environment slice.
    kit.place(self, "cave_back", terrain.on_ground(Vector3(-34, 0, -42), 0))

func _scatter() -> void:
    var random := RandomNumberGenerator.new()
    random.seed = 20261106
    var plants := MultiMesh.new()
    plants.transform_format = MultiMesh.TRANSFORM_3D
    plants.use_colors = true
    plants.mesh = kit.mesh("flora_rosette")
    plants.instance_count = 180
    var planted := 0
    var rocks := 0
    for attempt in range(3000):
        var at := Vector3(random.randf_range(-60, 60), 0, random.randf_range(-60, 60))
        var near_site := false
        for site in TERRAIN.SITES:
            if Vector2(at.x - site.x, at.z - site.z).length() < 12:
                near_site = true
        if near_site or terrain.road_at(Vector2(at.x, at.z)).x < 6.5:
            continue
        if rocks < 72:
            var size := Vector3(random.randf_range(1.2, 3.2), random.randf_range(1.4, 4), random.randf_range(1.2, 2.8))
            var point: Vector3 = terrain.on_ground(at, 0)
            var floor_height: float = point.y
            for dx in [-0.35, 0.35]:
                for dz in [-0.35, 0.35]:
                    floor_height = minf(floor_height, terrain.height(at.x + dx * size.x, at.z + dz * size.z))
            var rock: MeshInstance3D = kit.place(self, ["rock_a", "rock_b", "rock_c"][rocks % 3], Vector3(at.x, floor_height - 0.03, at.z), size)
            rock.visibility_range_end = 65
            _block(point, size)
            rocks += 1
        elif planted < plants.instance_count:
            var scale_value := random.randf_range(0.35, 0.95)
            var basis := Basis(Vector3.UP, random.randf_range(0, TAU)).scaled(Vector3.ONE * scale_value)
            plants.set_instance_transform(planted, Transform3D(basis, terrain.on_ground(at, 0)))
            plants.set_instance_color(planted, Color("#b5d0bf").lerp(Color.WHITE, random.randf()))
            planted += 1
        if planted == plants.instance_count and rocks == 72:
            break
    vegetation = MultiMeshInstance3D.new()
    vegetation.name = "AlienPlants"
    vegetation.multimesh = plants
    add_child(vegetation)
