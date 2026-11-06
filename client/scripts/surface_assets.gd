extends RefCounted
## Authored GLB modules. One mesh/material per asset; shared across the whole scene.

const ROOT := "res://assets/environment/frontier_v1/"
const SIZES := {"habitat": Vector3(6, 3.2, 6), "generator": Vector3(3, 2.5, 2.5),
    "gate_post": Vector3(0.7, 3.2, 0.7), "wall": Vector3(3.3, 1.4, 0.7), "landing_pad": Vector3(12, 0.05, 12),
    "cargo": Vector3(4.4, 2.4, 2.8), "wreck_hull": Vector3(11, 2.5, 3.4), "wreck_engine": Vector3(2.8, 2.8, 2.8),
    "wreck_wing": Vector3(4.5, 0.45, 4), "gantry_column": Vector3(0.8, 7, 0.8), "gantry_beam": Vector3(0.8, 0.5, 13),
    "obelisk": Vector3(1.7, 4, 1.7), "terminal": Vector3(1.4, 1.7, 1.4), "cave_pillar": Vector3(3.5, 6, 4),
    "cave_arch": Vector3(10.5, 1.3, 4), "cave_back": Vector3(6.5, 4.7, 0.15),
    "rock_a": Vector3.ONE, "rock_b": Vector3.ONE, "rock_c": Vector3.ONE, "flora_rosette": Vector3(0.8, 1.4, 0.8)}

static var cached: Dictionary = {}

func mesh(id: String) -> Mesh:
    if cached.has(id):
        return cached[id]
    var packed := load(ROOT + id + ".glb") as PackedScene
    if packed == null:
        push_error("SURFACE_ASSET_LOAD_FAILED " + id)
        return null
    var root := packed.instantiate()
    var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
    if root is MeshInstance3D:
        meshes.push_front(root)
    if meshes.size() != 1:
        push_error("SURFACE_ASSET_MESH_COUNT " + id)
        root.free()
        return null
    var instance := meshes[0] as MeshInstance3D
    var result: Mesh = instance.mesh
    cached[id] = result
    root.free()
    return result

func place(parent: Node3D, id: String, at: Vector3, size: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var result := MeshInstance3D.new()
    result.name = "Asset_" + id
    result.mesh = mesh(id)
    result.position = at
    if size != Vector3.ZERO:
        result.scale = size / SIZES[id]
    result.set_meta("frontier_asset", id)
    parent.add_child(result)
    return result
