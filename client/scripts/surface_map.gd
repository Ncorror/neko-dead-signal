extends Control
## Cached terrain overview; a small fixed overlay, no per-frame terrain generation.

const TERRAIN := preload("res://scripts/surface_terrain.gd")
const MAP_SIDE := 92.0
const MAP_ORIGIN := Vector2(4, 4)
var zone
var texture: ImageTexture

func install(owner_zone) -> void:
    zone = owner_zone
    custom_minimum_size = Vector2(110, 100)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
    for z in range(64):
        for x in range(64):
            var point := Vector2(x * 2 - 63, z * 2 - 63)
            var y: float = zone.world.terrain.height(point.x, point.y)
            image.set_pixel(x, z, Color("#243d4b").lerp(Color("#8cabb4"), clampf((y + 2) / 15, 0, 1)))
    texture = ImageTexture.create_from_image(image)

func _at(point: Vector3) -> Vector2:
    return MAP_ORIGIN + Vector2((point.x + 64) / 128, (point.z + 64) / 128) * MAP_SIDE

func _draw() -> void:
    if zone == null or texture == null:
        return
    draw_texture_rect(texture, Rect2(MAP_ORIGIN, Vector2.ONE * MAP_SIDE), false)
    draw_rect(Rect2(MAP_ORIGIN, Vector2.ONE * MAP_SIDE), Color("#76939f"), false, 1)
    for road in TERRAIN.ROADS:
        var points := PackedVector2Array()
        for point in road:
            points.append(_at(point))
        draw_polyline(points, Color("#a0b9bb"), 1)
    for i in range(TERRAIN.SITES.size()):
        var at := _at(TERRAIN.SITES[i])
        draw_circle(at, 3, Color("#74d9cd") if zone.visited.has(i) else Color("#dfbe7f"))
        draw_string(ThemeDB.fallback_font, at + Vector2(4, 1), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
    if zone.goal >= 0:
        draw_line(_at(zone.hero.position), _at(TERRAIN.SITES[zone.goal]), Color("#d0ac66"), 1)
    draw_circle(_at(zone.hero.position), 3.5, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(99, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#9fc5cf"))
