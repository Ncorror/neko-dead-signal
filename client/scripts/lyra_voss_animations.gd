extends RefCounted
## Lyra Voss uses the 20 verified imported Meshy/Mixamo clips.
## Export contains no regular Idle: sample Walking at a stationary frame.
const MODEL_PATH := "res://assets/characters/lyra_voss/rigged.glb"
const CLIP_NAMES = [
    "Running", "Walking", "Archery_Aim_with_Lateral_Scan",
    "Archery_Shot_2", "Bar_Hang_Idle", "Charged_Spell_Cast_1",
    "Dead", "Fall_Dead_from_Abdominal_Injury",
    "Hit_in_Back_While_Running", "Kneeling_Reload",
    "Roll_Dodge_1", "Roll_Dodge_3", "Roll_Dodge_4",
    "Shot_and_Fall_Forward", "Slow_Walk_Reload",
    "Standing_Reload", "Sword_Parry_Backward_3",
    "air_squat", "falling_down", "walking_2"
]

static func find_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.find_children("*", "AnimationPlayer", true, false):
        if child is AnimationPlayer:
            return child as AnimationPlayer
    return null

static func resolve_clip(player: AnimationPlayer, clip: String) -> String:
    if player == null:
        return ""
    for name in player.get_animation_library_list():
        var library: AnimationLibrary = player.get_animation_library(name)
        if library != null and library.has_animation(clip):
            return clip if str(name).is_empty() else str(name) + "/" + clip
    return clip if player.has_animation(clip) else ""

static func loaded_count(player: AnimationPlayer) -> int:
    var result := 0
    for clip in CLIP_NAMES:
        if not resolve_clip(player, clip).is_empty():
            result += 1
    return result

static func hold_ready_pose(player: AnimationPlayer) -> bool:
    var name := resolve_clip(player, "Walking")
    if name.is_empty():
        return false
    player.play(name)
    player.seek(0.25, true)
    player.pause()
    player.set_meta("neko_lyra_motion", "idle")
    return true

static func play_movement(player: AnimationPlayer, moving: bool, speed: float) -> String:
    if player == null:
        return "missing"
    var state := "idle"
    if moving:
        state = "run" if speed > 5.2 else "walk"
    if str(player.get_meta("neko_lyra_motion", "")) == state:
        return state
    if state == "idle":
        return "idle" if hold_ready_pose(player) else "missing"
    var name := resolve_clip(player, "Running" if state == "run" else "Walking")
    if name.is_empty():
        return "missing"
    var animation: Animation = player.get_animation(name)
    if animation != null:
        animation.loop_mode = Animation.LOOP_LINEAR
    player.play(name, 0.15)
    player.set_meta("neko_lyra_motion", state)
    return state

static func play_preview(player: AnimationPlayer, clip: String) -> bool:
    var name := resolve_clip(player, clip)
    if name.is_empty():
        return false
    var animation: Animation = player.get_animation(name)
    if animation != null:
        animation.loop_mode = Animation.LOOP_LINEAR if clip in ["Walking", "Running"] else Animation.LOOP_NONE
    player.set_meta("neko_lyra_motion", "preview")
    player.play(name, 0.1)
    return true
