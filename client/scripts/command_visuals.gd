extends Control
## Vector-only UI artwork. Placeholder until our original Meshy GLB models arrive.
## No external assets, fonts or licenses.

var mode: int = 0 # 0 = planetary backdrop, 1 = officer hologram
var faction_index: int = 0
var officer_index: int = 0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func _draw() -> void:
    if mode == 0:
        _draw_orbit()
    else:
        _draw_officer()

func _draw_orbit() -> void:
    var w: float = size.x
    var h: float = size.y
    draw_rect(Rect2(Vector2.ZERO, size), Color("#030c14"))
    for stripe in range(30):
        var t: float = float(stripe) / 30.0
        draw_rect(Rect2(0, h * t, w, h / 28.0 + 1.0), Color(0.01 + t * 0.022, 0.045 + t * 0.025, 0.08 + t * 0.031))
    var rng := RandomNumberGenerator.new()
    rng.seed = 1901124
    for i in range(155):
        var p := Vector2(rng.randf_range(0.0, w), rng.randf_range(0.0, h))
        var a: float = rng.randf_range(0.12, 0.64)
        draw_circle(p, rng.randf_range(0.55, 1.4), Color(0.62, 0.83, 1.0, a))

    var planet := Vector2(w * 0.51, h * 0.75)
    var radius: float = minf(w * 0.25, h * 0.43)
    for j in range(28, 0, -1):
        var distance: float = radius + float(j) * 4.7
        draw_circle(planet, distance, Color(0.09, 0.65, 0.77, (29.0 - float(j)) * 0.0005))
    draw_circle(planet, radius, Color("#0d2633"))
    draw_circle(planet + Vector2(radius * 0.3, -radius * 0.26), radius * 0.91, Color("#06141c"))
    draw_arc(planet, radius + 1.5, PI * 0.92, PI * 1.96, 110, Color(0.25, 0.88, 0.92, 0.6), 2.1, true)
    for n in range(11):
        var v := float(n) / 11.0
        var y := planet.y + radius * (v * 1.6 - 0.7)
        var half: float = sqrt(maxf(0.0, radius * radius - pow(y - planet.y, 2.0)))
        draw_line(Vector2(planet.x - half * 0.6, y), Vector2(planet.x + half * 0.63, y), Color(0.11, 0.56, 0.62, 0.04 + v * 0.04), 1.0)
    for angle in [0.08, 0.24, 0.43, 0.62]:
        var a: float = -PI * angle
        var p1 := planet + Vector2(cos(a), sin(a)) * (radius + 68.0)
        var p2 := planet + Vector2(cos(a + 0.48), sin(a + 0.48)) * (radius + 68.0)
        draw_line(p1, p2, Color(0.15, 0.75, 0.88, 0.11), 1.2)
    # Sparse ship silhouettes in orbit: graphics, not playable ships.
    var ship := Vector2(w * 0.74, h * 0.35)
    var shp := PackedVector2Array([ship + Vector2(-75, -3), ship + Vector2(-22, -9),
        ship + Vector2(16, -27), ship + Vector2(35, -9),
        ship + Vector2(83, -2), ship + Vector2(35, 4),
        ship + Vector2(13, 17), ship + Vector2(-21, 5)])
    draw_colored_polygon(shp, Color("#132b39"))
    draw_polyline(shp, Color(0.23, 0.74, 0.82, 0.32), 1.2, true)
    draw_line(ship + Vector2(-32, 0), ship + Vector2(43, 0), Color("#48c5cf"), 1.5, true)
    draw_circle(ship + Vector2(-65, 0), 4.0, Color(0.21, 0.8, 0.96, 0.58))
    for i in range(22):
        var x: float = float(i) * 72.0
        draw_line(Vector2(x, 0), Vector2(x - 150, h), Color(0.08, 0.42, 0.5, 0.045), 1.0)

func _draw_officer() -> void:
    var w: float = size.x
    var h: float = size.y
    var cx: float = w * 0.5
    var cy: float = h * 0.53
    var scale_factor: float = minf(w / 390.0, h / 430.0)
    var accent := Color("#69dfe8") if faction_index == 0 else Color("#b99aff")
    var secondary := Color("#244856") if faction_index == 0 else Color("#433856")

    # Circular HUD, angle cuts and targeting ticks.
    for r in [107.0, 140.0, 175.0]:
        draw_arc(Vector2(cx, cy), r * scale_factor, -PI * 0.8, PI * 0.4,
            120, Color(accent.r, accent.g, accent.b, 0.17), 1.2, true)
    for i in range(34):
        var a: float = float(i) * TAU / 34.0
        var r1 := 166.0 * scale_factor
        var r2 := (174.0 if i % 4 == 0 else 169.0) * scale_factor
        var v := Vector2(cos(a), sin(a))
        draw_line(Vector2(cx, cy) + v * r1, Vector2(cx, cy) + v * r2,
            Color(accent.r, accent.g, accent.b, 0.27), 1.2, true)
    draw_line(Vector2(cx - 175.0 * scale_factor, cy + 166.0 * scale_factor),
        Vector2(cx + 175.0 * scale_factor, cy + 166.0 * scale_factor),
        Color(accent.r, accent.g, accent.b, 0.36), 2.0, true)

    # Armoured heroine placeholder: schematic so no fake claim of Meshy artwork.
    var center := Vector2(cx, cy + 18.0 * scale_factor)
    var shoulders := PackedVector2Array([
        center + Vector2(-49,-76) * scale_factor,
        center + Vector2(-97,-44) * scale_factor,
        center + Vector2(-91,84) * scale_factor,
        center + Vector2(-57,151) * scale_factor,
        center + Vector2(57,151) * scale_factor,
        center + Vector2(91,84) * scale_factor,
        center + Vector2(97,-44) * scale_factor,
        center + Vector2(49,-76) * scale_factor
    ])
    draw_colored_polygon(shoulders, Color("#132630"))
    draw_polyline(shoulders, Color(accent.r, accent.g, accent.b, 0.65), 2.1, true)
    var armor := PackedVector2Array([
        center + Vector2(-43,-73) * scale_factor,
        center + Vector2(0,-48) * scale_factor,
        center + Vector2(43,-73) * scale_factor,
        center + Vector2(58,62) * scale_factor,
        center + Vector2(0,104) * scale_factor,
        center + Vector2(-58,62) * scale_factor
    ])
    draw_colored_polygon(armor, secondary)
    draw_line(center + Vector2(0,-48)*scale_factor, center + Vector2(0,104)*scale_factor, accent.darkened(0.4), 2.0)
    draw_circle(center + Vector2(0,3)*scale_factor, 9.0*scale_factor, accent.darkened(0.3))
    draw_circle(center + Vector2(0,3)*scale_factor, 4.0*scale_factor, accent)
    # Neck, face and silver/blue hair.
    draw_rect(Rect2(center + Vector2(-14,-112)*scale_factor, Vector2(28,43)*scale_factor), Color("#8bafb8"))
    draw_circle(center + Vector2(0,-157)*scale_factor, 43.0*scale_factor, Color("#a0b6bd"))
    draw_arc(center + Vector2(0,-168)*scale_factor, 43.0*scale_factor, PI*0.82, PI*2.19, 55,
        Color("#dae6e8") if faction_index == 0 else Color("#d9cff9"), 9.0*scale_factor, true)
    draw_line(center + Vector2(-32,-157)*scale_factor, center + Vector2(-30,-75)*scale_factor,
        Color("#ccdfe5") if faction_index == 0 else Color("#c6bde9"), 11.0*scale_factor)
    draw_line(center + Vector2(34,-156)*scale_factor, center + Vector2(30,-72)*scale_factor,
        Color("#ccdfe5") if faction_index == 0 else Color("#c6bde9"), 11.0*scale_factor)
    draw_line(center + Vector2(-18,-157)*scale_factor, center + Vector2(-5,-158)*scale_factor,
        accent, 2.0*scale_factor, true)
    draw_line(center + Vector2(5,-158)*scale_factor, center + Vector2(19,-157)*scale_factor,
        accent, 2.0*scale_factor, true)
    # Officer specialization badge changes with selection.
    var badge := center + Vector2(63,16)*scale_factor
    draw_circle(badge, 13.0*scale_factor, Color("#04121b"))
    draw_arc(badge, 12.0*scale_factor, 0.0, TAU, 32, accent, 1.8, true)
    if officer_index == 0:
        draw_line(badge + Vector2(-5,0)*scale_factor, badge + Vector2(5,0)*scale_factor, accent, 2.5, true)
        draw_line(badge + Vector2(0,-5)*scale_factor, badge + Vector2(0,5)*scale_factor, accent, 2.5, true)
    else:
        draw_circle(badge, 4.0*scale_factor, accent)
