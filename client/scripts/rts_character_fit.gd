extends RefCounted
## Normalizes an imported static or rigged character into world-sized dimensions.
## Uses transformed corners of every MeshInstance3D and leaves all source files intact.

static func fit_to_height(model: Node3D, desired_height: float) -> Dictionary:
    var meshes: Array[MeshInstance3D] = []
    if model is MeshInstance3D:
        meshes.append(model as MeshInstance3D)
    for child in model.find_children("*", "MeshInstance3D", true, false):
        meshes.append(child as MeshInstance3D)
    var bounds_ready := false
    var lower := Vector3.ZERO
    var upper := Vector3.ZERO
    for mesh_instance in meshes:
        if mesh_instance.mesh == null:
            continue
        var bounds: AABB = mesh_instance.mesh.get_aabb()
        for x in range(2):
            for y in range(2):
                for z in range(2):
                    var vertex := bounds.position + Vector3(
                        float(x) * bounds.size.x,
                        float(y) * bounds.size.y,
                        float(z) * bounds.size.z
                    )
                    var p: Vector3 = model.to_local(mesh_instance.to_global(vertex))
                    if not bounds_ready:
                        lower = p
                        upper = p
                        bounds_ready = true
                    else:
                        lower = lower.min(p)
                        upper = upper.max(p)
    if not bounds_ready:
        return {"ok": false, "reason": "no meshes"}
    var source_height: float = upper.y - lower.y
    if source_height <= 0.0001:
        return {"ok": false, "reason": "zero height"}

    var factor: float = clampf(desired_height / source_height, 0.01, 100.0)
    var center := (lower + upper) * 0.5
    model.scale = Vector3.ONE * factor
    model.position = Vector3(-center.x * factor, -lower.y * factor, -center.z * factor)
    return {
        "ok": true,
        "source_height": source_height,
        "target_height": source_height * factor,
        "scale": factor,
        "mesh_count": meshes.size(),
        "center": center
    }
