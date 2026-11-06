extends MeshInstance3D
## Visual terrain beyond the playable square. No physics or navigation is added.

const TERRAIN := preload("res://scripts/surface_terrain.gd")
const RINGS := [64.0, 80.0, 112.0, 152.0, 208.0]
const PERIMETER := 512
var terrain
var minimum := INF
var maximum := -INF

func _edge_point(index: int) -> Vector2:
    var along := float(index % 128) - 64.0
    match index / 128:
        0: return Vector2(along, -64)
        1: return Vector2(64, along)
        2: return Vector2(-along, 64)
        _: return Vector2(-64, -along)

func height(x: float, z: float) -> float:
    var point := Vector2(x, z)
    var radius := maxf(absf(x), absf(z))
    if radius <= TERRAIN.HALF:
        return terrain.height(x, z)
    var edge := point * (float(TERRAIN.HALF) / radius)
    var distance := radius - TERRAIN.HALF
    var ridge := 11.0 + sin(x * 0.045 + z * 0.017) * 5.0 + cos(z * 0.04 - x * 0.013) * 3.0
    return terrain.height(edge.x, edge.y) + smoothstep(0, 96, distance) * ridge

func build(source, paint: Material) -> void:
    terrain = source
    name = "DistantTerrain"
    var ground: Array = terrain.mesh.surface_get_arrays(0)
    var ground_colors: PackedColorArray = ground[Mesh.ARRAY_COLOR]
    var ground_normals: PackedVector3Array = ground[Mesh.ARRAY_NORMAL]
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    for radius in RINGS:
        for i in range(PERIMETER):
            var edge := _edge_point(i)
            var point := edge * (float(radius) / TERRAIN.HALF)
            var y := height(point.x, point.y)
            vertices.append(Vector3(point.x, y, point.y))
            minimum = minf(minimum, y)
            maximum = maxf(maximum, y)
            var sample := (roundi(edge.y) + TERRAIN.HALF) * TERRAIN.SIDE + roundi(edge.x) + TERRAIN.HALF
            var normal := Vector3(height(point.x - 0.5, point.y) - height(point.x + 0.5, point.y),
                1, height(point.x, point.y - 0.5) - height(point.x, point.y + 0.5)).normalized()
            normals.append(ground_normals[sample] if radius == RINGS[0] else normal)
            var blend := smoothstep(0, 96, float(radius) - TERRAIN.HALF) * 0.65
            colors.append(ground_colors[sample].lerp(Color("#6b7e7e"), blend))
    for ring in range(RINGS.size() - 1):
        for i in range(PERIMETER):
            var a := ring * PERIMETER + i
            var b := ring * PERIMETER + (i + 1) % PERIMETER
            var c := a + PERIMETER
            var d := b + PERIMETER
            indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    var result := ArrayMesh.new()
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    mesh = result
    material_override = paint
    cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
