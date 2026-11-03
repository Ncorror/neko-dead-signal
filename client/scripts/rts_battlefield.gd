extends RefCounted
## Local operation layout. World, navigation, fog and minimap share these bounds.

const WORLD_BOUNDS := Rect2(-100, -100, 200, 200)
const PLAYABLE_LIMIT := 96.0
const FACTORY_POSITION := Vector3(-6, 0, 7)
const FACTORY_SIZE := Vector3(3.2, 1.6, 3.2)
const FACTORY_EXIT := Vector3(-2, 0, 7)
const RALLY_POINT := Vector3(-2, 0, 3)
const MISSION_SUPPLIES := [Vector3(5, 0, 2), Vector3(-8, 0, 11), Vector3(13, 0, -6)]
const REMOTE_SUPPLIES := [Vector3(-58, 0, -42), Vector3(62, 0, -54),
    Vector3(-64, 0, 54), Vector3(60, 0, 58), Vector3(8, 0, -72), Vector3(-76, 0, 10)]
const OUTER_COVER := [
    [Vector3(-42, 0, -28), Vector3(10, 3, 5)],
    [Vector3(40, 0, -35), Vector3(5, 3, 12)],
    [Vector3(-52, 0, 42), Vector3(8, 4, 8)],
    [Vector3(45, 0, 40), Vector3(12, 2, 4)],
    [Vector3(5, 0, 62), Vector3(6, 3, 10)],
    [Vector3(-76, 0, -64), Vector3(8, 5, 6)]
]
