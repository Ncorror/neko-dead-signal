extends Node
## Mesh-plane agreement, actual map dimensions, reachable sites and disk failure recovery.

const TERRAIN := preload("res://scripts/surface_terrain.gd")
const ENVIRONMENT := preload("res://scripts/surface_environment.gd")
const NAV := preload("res://scripts/rts_navigation.gd")
const STORE := preload("res://scripts/surface_progress.gd")
const PATH := "user://surface-unit-regression/sector.json"
var failures := 0

class FailedWrite:
    extends "res://scripts/surface_progress.gd"
    func _write(_path: String, _value: Dictionary) -> bool:
        return false

func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("SURFACE_TERRAIN_TEST_FAIL " + message)

func _clean() -> void:
    for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
        if FileAccess.file_exists(PATH + suffix):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))

func _ready() -> void:
    var started := Time.get_ticks_msec()
    var nav = NAV.new()
    var world = ENVIRONMENT.new()
    add_child(world)
    world.build(nav)
    var terrain = world.terrain
    var bounds: AABB = terrain.mesh.get_aabb()
    _check(bounds.size.x == 128 and bounds.size.z == 128 and bounds.position.x == -64 and bounds.position.z == -64,
        "terrain is not a full 128x128 mesh: " + str(bounds))
    _check(terrain.maximum - terrain.minimum > 10 and terrain.minimum < 0 and terrain.maximum > 9,
        "landscape has no meaningful height variation")
    var arrays: Array = terrain.mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
    _check(vertices.size() == 16641 and indices.size() == 98304, "terrain mesh budget changed unexpectedly")
    for i in range(0, vertices.size(), 97):
        _check(vertices[i].is_finite() and normals[i].is_finite() and normals[i].y > 0
            and absf(normals[i].length() - 1) < 0.001, "terrain vertex/normal is invalid")
    var random := RandomNumberGenerator.new()
    random.seed = 128128
    for sample in range(200):
        var x := random.randf_range(-61, 61)
        var z := random.randf_range(-61, 61)
        var ix := floori(x + 64)
        var iz := floori(z + 64)
        var triangle := (iz * 128 + ix) * 6
        if (x + 64 - ix) + (z + 64 - iz) > 1:
            triangle += 3
        var a := vertices[indices[triangle]]
        var b := vertices[indices[triangle + 1]]
        var c := vertices[indices[triangle + 2]]
        var intersection: Variant = Plane(a, b, c).intersects_ray(Vector3(x, 50, z), Vector3.DOWN)
        _check(intersection != null and absf(intersection.y - terrain.height(x, z)) < 0.001,
            "walking height differs from the actual triangle plane")
        _check((b - a).cross(c - a).y < 0, "terrain faces are not clockwise from above")
    for i in range(TERRAIN.SITES.size()):
        _check(nav.is_walkable(nav.world_to_cell(TERRAIN.SITES[i])), "site centre is blocked: " + str(i))
        for j in range(TERRAIN.SITES.size()):
            var path: Array[Vector3] = nav.get_path(TERRAIN.SITES[i], TERRAIN.SITES[j])
            _check(not path.is_empty(), "sites disconnected: %d -> %d" % [i, j])
            var previous: Vector3 = TERRAIN.SITES[i]
            for point in path:
                _check(nav.has_walkable_segment(previous, point), "smoothed route crosses an obstruction")
                previous = point
    _check(world.obstacles.size() >= 90 and world.vegetation.multimesh.instance_count == 180,
        "landmarks/rocks/plant instancing were not created")
    _check(world.vegetation.name == "EarthVegetation", "vegetation still exposes the old off-world identity")
    _check(world.atmosphere_root != null and world.skyline != null and world.skyline.get_child_count() >= 11,
        "earth skyline atmosphere was not created")
    _check(world.anomaly_markers.size() == 3, "radio anomaly markers were not created")
    _check(world.atmosphere_root.find_children("*", "StaticBody3D", true, false).is_empty(),
        "visual atmosphere unexpectedly changed physics/navigation")
    _saves()
    _clean()
    if failures == 0:
        print("SURFACE_TERRAIN_TEST_PASS size=128x128 triangles=32768 height=real planes=200 routes=25 save=isolated,reload,backup,failed_write build_ms=" + str(Time.get_ticks_msec() - started))
    get_tree().quit(0 if failures == 0 else 1)

func _saves() -> void:
    _clean()
    var store = STORE.new()
    _check(store.open_profile(PATH, "amina"), "fresh surface profile failed")
    _check(store.checkpoint(Vector3(37, 3, 16), 18.5, [0, 1, 2, 3, 4]), "128x128 coordinates were rejected")
    var loaded = STORE.new()
    _check(loaded.open_profile(PATH, "amina") and loaded.state()["position"] == [37.0, 16.0]
        and loaded.state()["visited"] == [0, 1, 2, 3, 4] and loaded.state()["zoom"] == 18.5,
        "surface reload lost the exact position, visited sites or zoom")
    var before := FileAccess.get_file_as_string(PATH)
    var failed := FailedWrite.new()
    failed.open_profile(PATH, "amina")
    _check(not failed.checkpoint(Vector3(25, 7, -34), 20, [0, 1]) and FileAccess.get_file_as_string(PATH) == before
        and failed.state()["visited"].size() == 5, "failed write changed the committed profile")
    _check(not loaded.checkpoint(Vector3(90, 0, 0), 16, []) and not loaded.checkpoint(Vector3.ZERO, 16, [1, 1])
        and FileAccess.get_file_as_string(PATH) == before, "invalid snapshot overwrote the confirmed save")
    _check(loaded.checkpoint(Vector3(25, 7, -34), 20, [0, 1, 2, 3, 4]), "second surface snapshot failed")
    var file := FileAccess.open(PATH, FileAccess.WRITE)
    file.store_string("{broken")
    file.close()
    _check(loaded.open_profile(PATH, "amina") and loaded.recovered and loaded.state()["visited"].size() == 5,
        "last confirmed surface backup was not recovered")
    _check(loaded.checkpoint(Vector3(25, 7, -34), 20, [0, 1, 2, 3, 4]), "recovered profile could not resume")
    var other = STORE.new()
    _check(other.open_profile(PATH, "mira_kade") and other.state()["visited"].is_empty(), "another hero inherited exploration progress")
    for suffix in ["", ".bak"]:
        file = FileAccess.open(PATH + suffix, FileAccess.WRITE)
        file.store_string("[]")
        file.close()
    _check(not loaded.open_profile(PATH, "amina") and not loaded.checkpoint(Vector3.ZERO, 16, [])
        and FileAccess.get_file_as_string(PATH) == "[]", "two damaged files were silently replaced")
