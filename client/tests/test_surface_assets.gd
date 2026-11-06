extends Node
## Validate real imported GLBs, visible materials, shared meshes and collision envelopes.

const KIT := preload("res://scripts/surface_assets.gd")
const ENVIRONMENT := preload("res://scripts/surface_environment.gd")
const NAV := preload("res://scripts/rts_navigation.gd")
var failures := 0

func _ready() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("SURFACE_ASSETS_TEST_FAIL " + message)

func _run() -> void:
    var kit = KIT.new()
    var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(KIT.ROOT + "manifest.json"))
    _check(manifest["assets"].size() == 20 and KIT.SIZES.size() == 20, "asset manifest is incomplete")
    var unique_triangles := 0
    for id in KIT.SIZES:
        var mesh: Mesh = kit.mesh(id)
        _check(mesh != null and mesh == kit.mesh(id), "asset not loaded or mesh cache not reused: " + id)
        if mesh == null:
            continue
        var bounds := mesh.get_aabb()
        var size: Vector3 = KIT.SIZES[id]
        _check(bounds.position.y >= -0.001 and bounds.end.y <= size.y + 0.001
            and absf(bounds.position.x) <= size.x * 0.5 + 0.001 and absf(bounds.end.x) <= size.x * 0.5 + 0.001
            and absf(bounds.position.z) <= size.z * 0.5 + 0.001 and absf(bounds.end.z) <= size.z * 0.5 + 0.001,
            "GLB exceeds its established placement envelope: " + id + " " + str(bounds))
        _check(mesh.get_surface_count() == 1, "asset requires multiple draw surfaces: " + id)
        var material := mesh.surface_get_material(0) as BaseMaterial3D
        _check(material != null and material.vertex_color_use_as_albedo and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
            "asset lost opaque vertex-colour material: " + id)
        var arrays: Array = mesh.surface_get_arrays(0)
        var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
        var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
        _check(colors.size() > 0 and normals.size() > 0, "import lost colour/normal attributes: " + id)
        var triangles := mesh.get_faces().size() / 3
        unique_triangles += int(triangles)
        _check(triangles == manifest["assets"][id]["triangles"], "import changed triangle count: " + id)
    _check(unique_triangles <= 6000, "unique kit geometry exceeded the initial mobile budget")
    var world = ENVIRONMENT.new()
    add_child(world)
    world.build(NAV.new())
    var placed := 0
    var scene_triangles := 0
    var cargo_mesh: Mesh
    for node in world.find_children("*", "MeshInstance3D", true, false):
        var visual := node as MeshInstance3D
        if visual.mesh == null:
            continue
        scene_triangles += visual.mesh.get_faces().size() / 3
        if not visual.has_meta("frontier_asset"):
            continue
        placed += 1
        var id: String = visual.get_meta("frontier_asset")
        if id == "cargo":
            if cargo_mesh == null:
                cargo_mesh = visual.mesh
            _check(cargo_mesh == visual.mesh, "containers do not reuse one mesh resource")
        if visual.has_meta("collision_size"):
            var box := AABB(-visual.get_meta("collision_size") * Vector3(0.5, 0, 0.5), visual.get_meta("collision_size"))
            var local := Transform3D(visual.basis, Vector3.ZERO) * visual.mesh.get_aabb()
            _check(box.grow(0.002).encloses(local), "art projects beyond its collider: " + id)
    var plants: MultiMesh = world.vegetation.multimesh
    scene_triangles += plants.instance_count * plants.mesh.get_faces().size() / 3
    _check(placed == 100 and world.obstacles.size() == 96, "art update changed the established layout")
    _check(plants.mesh == kit.mesh("flora_rosette") and plants.instance_count == 180, "plants lost GPU instancing")
    _check(scene_triangles < 120000, "whole surface geometry exceeds the initial budget: " + str(scene_triangles))
    if failures == 0:
        print("SURFACE_ASSETS_TEST_PASS glb=20 surfaces=one_each cache=shared materials=opaque_color footprints=preserved unique_triangles=%d scene_triangles=%d" % [unique_triangles, scene_triangles])
    get_tree().quit(0 if failures == 0 else 1)
