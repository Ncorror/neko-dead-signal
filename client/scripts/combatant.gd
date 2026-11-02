extends Node3D
## Weapon and hull for one actor in the local landing encounter.

var hull := 100
var damage := 12
var weapon_range := 5.0
var reload_time := 0.85
var cooldown := 0.0

func tick(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)

func fire_at(target) -> bool:
    if hull <= 0 or target.hull <= 0 or cooldown > 0.0:
        return false
    if position.distance_to(target.position) > weapon_range:
        return false
    target.hull = maxi(0, target.hull - damage)
    cooldown = reload_time
    return true
