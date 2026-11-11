extends Control
## Vector-only UI artwork. Placeholder until our original Meshy GLB models arrive.
## No external assets, fonts or licenses.

var mode: int = 0 # 0 = post-Silence Earth backdrop, 1 = officer hologram
var faction_index: int = 0
var officer_index: int = 0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    resized.connect(queue_redraw)

func _draw() -> void:
    if mode == 0:
        _draw_earth()
    else:
        _draw_officer()

func _draw_earth() -> void:
    # Earth's storm-lit industrial corridor and the NEKO base signal tower.
    var w: float = size.x
    var h: float = size.y
    draw_rect(Rect2(Vector2.ZERO, size), Color("#030e16"))
    for stripe in range(36):
        var t: float = float(stripe) / 36.0
        draw_rect(Rect2(0, h * t, w, h / 34.0 + 1.0),
            Color(0.015 + t * 0.035, 0.055 + t * 0.045, 0.085 + t * 0.038))
    var rng := RandomNumberGenerator.new()
    rng.seed = 20892317
    # Distant lights behind a ruined city skyline, not orbiting spacecraft.
    for i in range(85):
        var x: float = rng.randf_range(0.0, w)
        var y: float = rng.randf_range(h * 0.16, h * 0.78)
        draw_circle(Vector2(x, y), rng.randf_range(0.5, 1.5),
            Color(0.42, 0.82, 0.86, rng.randf_range(0.04, 0.21)))
    for building in range(26):
        var bw: float = w / 22.0
        var x: float = float(building) * bw - bw
        var top: float = h * rng.randf_range(0.40, 0.76)
        draw_rect(Rect2(x, top, bw * 0.86, h - top), Color("#081c26"))
        for light in range(3):
            var ly: float = top + 13.0 + float(light) * 16.0
            if ly < h - 8.0 and rng.randf() > 0.42:
                draw_rect(Rect2(x + bw * 0.27, ly, 3.0, 4.0), Color("#397f88"))
    # The signal mast stands above the mobile ground headquarters.
    var tx: float = w * 0.70
    var by: float = h * 0.84
    var peak: Vector2 = Vector2(tx, h * 0.19)
    draw_line(Vector2(tx - w * 0.095, by), peak, Color("#183f4b"), 4.0, true)
    draw_line(Vector2(tx + w * 0.095, by), peak, Color("#183f4b"), 4.0, true)
    draw_line(Vector2(tx - w * 0.095, by), Vector2(tx + w * 0.095, by), Color("#247987"), 3.0, true)
    for height in [0.40, 0.54, 0.67, 0.78]:
        var yy: float = h * height
        var half_width: float = w * 0.095 * (yy - peak.y) / (by - peak.y)
        draw_line(Vector2(tx - half_width, yy), Vector2(tx + half_width, yy),
            Color("#276776"), 2.0, true)
    draw_circle(peak, 5.5, Color("#ff5d63"))
    draw_arc(peak, minf(w, h) * 0.09, PI * 1.1, PI * 1.9, 54,
        Color(0.93, 0.25, 0.28, 0.20), 1.8, true)
    draw_arc(peak, minf(w, h) * 0.16, PI * 1.1, PI * 1.9, 54,
        Color(0.93, 0.25, 0.28, 0.10), 1.2, true)
    # Heavy rain and abandoned rail lines lead to the NEKO night base.
    for drop in range(55):
        var p: Vector2 = Vector2(rng.randf_range(0.0, w), rng.randf_range(0.0, h))
        draw_line(p, p + Vector2(-6, 19), Color(0.48, 0.75, 0.84, 0.10), 1.0)
    draw_line(Vector2(0, h * 0.98), Vector2(w * 0.45, h * 0.73), Color("#23515c"), 3.0, true)
    draw_line(Vector2(w, h * 0.98), Vector2(w * 0.55, h * 0.73), Color("#23515c"), 3.0, true)

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
