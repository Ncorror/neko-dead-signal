extends RefCounted
## Lyra Voss uses the 20 verified imported Meshy/Mixamo clips.
## Export contains no regular Idle: sample Walking at a stationary frame.
const FIT := preload("res://scripts/rts_character_fit.gd")
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


const UPPER_BONES = ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]

static func find_skeleton(player: AnimationPlayer) -> Skeleton3D:
    if player == null:
        return null
    var root: Node = player.get_parent()
    for attempt in range(4):
        if root == null:
            break
        if root is Skeleton3D:
            return root as Skeleton3D
        for candidate in root.find_children("*", "Skeleton3D", true, false):
            if candidate is Skeleton3D:
                return candidate as Skeleton3D
        root = root.get_parent()
    return null

static func bone_index(skeleton: Skeleton3D, suffix: String) -> int:
    if skeleton == null:
        return -1
    var i: int = skeleton.find_bone("mixamorig:" + suffix)
    if i >= 0:
        return i
    i = skeleton.find_bone(suffix)
    if i >= 0:
        return i
    # Godot's glTF importer sanitizes ':' in joint names (often as '_').
    # Match the verified Mixamo suffix against the ACTUAL imported skeleton.
    for index in range(skeleton.get_bone_count()):
        if str(skeleton.get_bone_name(index)).to_lower().ends_with(suffix.to_lower()):
            return index
    return -1

static func mount(parent: Node3D, height: float) -> Dictionary:
    if not ResourceLoader.exists(MODEL_PATH):
        return {"ok": false, "reason": "missing asset"}
    var source: Resource = load(MODEL_PATH)
    if not (source is PackedScene):
        return {"ok": false, "reason": "wrong resource"}
    var instance: Node = (source as PackedScene).instantiate()
    if not (instance is Node3D):
        instance.queue_free()
        return {"ok": false, "reason": "wrong scene root"}
    var rig: Node3D = instance as Node3D
    rig.name = "LyraRig"
    parent.add_child(rig)
    var player: AnimationPlayer = find_player(rig)
    if player == null or loaded_count(player) != 20:
        rig.queue_free()
        return {"ok": false, "reason": "missing clips"}
    var fitted: Dictionary = FIT.fit_to_height(rig, height)
    if not bool(fitted.get("ok", false)):
        rig.queue_free()
        return {"ok": false, "reason": "invalid bounds"}
    if not hold_ready_pose(player):
        rig.queue_free()
        return {"ok": false, "reason": "invalid ready pose"}
    return {"ok": true, "rig": rig, "player": player, "fit": fitted}

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
    # Source frame audit: Standing_Reload at t=0 has both feet planted.
    # Walking at t=0 has relaxed arms. Combine skeleton poses, not a mid-stride freeze.
    var standing := resolve_clip(player, "Standing_Reload")
    var walking := resolve_clip(player, "Walking")
    if standing.is_empty() or walking.is_empty():
        return false
    var skeleton: Skeleton3D = find_skeleton(player)
    var relaxed: Dictionary = {}
    if skeleton != null:
        player.play(walking)
        player.seek(0.0, true)
        player.pause()
        for bone_name in UPPER_BONES:
            var index: int = bone_index(skeleton, str(bone_name))
            if index >= 0:
                relaxed[index] = skeleton.get_bone_pose_rotation(index)
    player.play(standing)
    player.seek(0.0, true)
    player.pause()
    if skeleton != null:
        for index in relaxed:
            skeleton.set_bone_pose_rotation(int(index), relaxed[index])
        skeleton.force_update_all_bone_transforms()
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
