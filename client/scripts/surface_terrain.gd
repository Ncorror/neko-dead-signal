extends RefCounted
## Authored heightfield and paths, shared by the visible mesh, physics and walking.

const SIZE := 128
const HALF := 64
const SIDE := 129
const PLAY_LIMIT := 62.0
const SPAWN := Vector3(-43, 0.6, 39)
const SITES := [Vector3(-43, 0.6, 39), Vector3(-11, 2.0, 16), Vector3(37, 3.0, 16),
    Vector3(25, 7.0, -34), Vector3(-34, -1.2, -32)]
const SITE_NAMES := ["ЭКСПЕДИЦИОННЫЙ ФОРПОСТ", "ОСТОВ ТРАНСПОРТА", "ПОЛЕ УТИЛИЗАЦИИ", "ДРЕВНИЙ РАДИОУЗЕЛ", "КАНЬОН · ВХОД В ПЕЩЕРУ"]
const ROADS := [
    [Vector3(-43, 0.6, 39), Vector3(-31, 0.8, 30), Vector3(-20, 1.4, 22), Vector3(-11, 2, 16),
        Vector3(6, 2.3, 11), Vector3(22, 2.8, 16), Vector3(37, 3, 16)],
    [Vector3(-11, 2, 16), Vector3(-6, 2.8, 3), Vector3(4, 4.1, -10), Vector3(14, 5.7, -24), Vector3(25, 7, -34)],
    [Vector3(-11, 2, 16), Vector3(-23, 1.4, 3), Vector3(-34, 0.0, -10), Vector3(-34, -1.2, -32)],
    [Vector3(-34, -1.2, -32), Vector3(-15, 1.8, -27), Vector3(3, 4.5, -33), Vector3(25, 7, -34)]]

var heights := PackedFloat32Array()
var road_weights := PackedFloat32Array()
var mesh: ArrayMesh
var minimum := INF
var maximum := -INF

func road_at(point: Vector2) -> Vector2:
    var best := INF
    var elevation := 0.0
    for road in ROADS:
        for i in range(road.size() - 1):
            var from: Vector3 = road[i]
            var to: Vector3 = road[i + 1]
            var a := Vector2(from.x, from.z)
            var b := Vector2(to.x, to.z)
            var t := clampf((point - a).dot(b - a) / a.distance_squared_to(b), 0, 1)
            var distance := point.distance_to(a.lerp(b, t))
            if distance < best:
                best = distance
                elevation = lerpf(from.y, to.y, t)
    return Vector2(best, elevation)

func _height_at_vertex(point: Vector2) -> Vector2:
    var x := point.x
    var z := point.y
    var y := 2.8 + sin(x * 0.075) * 1.5 + cos(z * 0.09) * 1.1
    y += 9.0 * exp(-point.distance_squared_to(Vector2(41, -32)) / 370.0)
    y += 6.0 * exp(-point.distance_squared_to(Vector2(-48, -9)) / 230.0)
    y += 4.0 * exp(-point.distance_squared_to(Vector2(19, 40)) / 260.0)
    y -= 4.0 * exp(-pow((x + 32.0) / 7.0, 2)) * exp(-pow((z + 29.0) / 23.0, 2))
    y += pow(maxf(0, (maxf(absf(x), absf(z)) - 55.0) / 9.0), 2) * 4.0
    var road := road_at(point)
    var blend := 1.0 - smoothstep(2.8, 6.5, road.x)
    y = lerpf(y, road.y, blend)
    for site in SITES:
        var weight := 1.0 - smoothstep(7.5, 11.0, point.distance_to(Vector2(site.x, site.z)))
        y = lerpf(y, site.y, weight)
    return Vector2(y, blend)

func build() -> void:
    heights.resize(SIDE * SIDE)
    road_weights.resize(SIDE * SIDE)
    minimum = INF
    maximum = -INF
    for z in range(SIDE):
        for x in range(SIDE):
            var sample := _height_at_vertex(Vector2(x - HALF, z - HALF))
            var index := z * SIDE + x
            heights[index] = sample.x
            road_weights[index] = sample.y
            minimum = minf(minimum, sample.x)
            maximum = maxf(maximum, sample.x)
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var colors := PackedColorArray()
    var indices := PackedInt32Array()
    vertices.resize(SIDE * SIDE)
    normals.resize(SIDE * SIDE)
    colors.resize(SIDE * SIDE)
    for z in range(SIDE):
        for x in range(SIDE):
            var i := z * SIDE + x
            var y := heights[i]
            vertices[i] = Vector3(x - HALF, y, z - HALF)
            var dx := _vertex(x + 1, z) - _vertex(x - 1, z)
            var dz := _vertex(x, z + 1) - _vertex(x, z - 1)
            normals[i] = Vector3(-dx * 0.5, 1, -dz * 0.5).normalized()
            var rock := Color("#637c83").lerp(Color("#a0adb0"), clampf((y - 5) / 8, 0, 1))
            var noise := sin(float(x * 17 + z * 31)) * 0.035
            colors[i] = rock.lerp(Color("#415963"), road_weights[i] * 0.8).lightened(noise)
    # Clockwise faces viewed from above; height() uses precisely this diagonal.
    for z in range(SIZE):
        for x in range(SIZE):
            var a := z * SIDE + x
            var b := a + 1
            var c := a + SIDE
            var d := c + 1
            indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices
    mesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

func _vertex(x: int, z: int) -> float:
    return heights[clampi(z, 0, SIZE) * SIDE + clampi(x, 0, SIZE)]

func height(x: float, z: float) -> float:
    var px := clampf(x + HALF, 0, SIZE - 0.00001)
    var pz := clampf(z + HALF, 0, SIZE - 0.00001)
    var ix := floori(px)
    var iz := floori(pz)
    var fx := px - ix
    var fz := pz - iz
    var a := _vertex(ix, iz)
    var b := _vertex(ix + 1, iz)
    var c := _vertex(ix, iz + 1)
    var d := _vertex(ix + 1, iz + 1)
    if fx + fz <= 1:
        return a + (b - a) * fx + (c - a) * fz
    return d + (c - d) * (1 - fx) + (b - d) * (1 - fz)

func on_ground(point: Vector3, lift: float = 0.04) -> Vector3:
    return Vector3(point.x, height(point.x, point.z) + lift, point.z)

func slope(x: float, z: float) -> float:
    return Vector2(height(x + 0.5, z) - height(x - 0.5, z), height(x, z + 0.5) - height(x, z - 0.5)).length()

func configure_navigation(nav) -> void:
    nav.configure(PLAY_LIMIT)
    for x in range(-62, 63):
        for z in range(-62, 63):
            if slope(x, z) > 0.65:
                nav.grid.set_point_solid(Vector2i(x, z), true)
