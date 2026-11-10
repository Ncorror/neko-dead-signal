extends RefCounted
## Lyra Voss uses the 20 verified imported Meshy/Mixamo clips.
## Export contains no authored Idle. Neutral state uses the symmetric skeleton rest pose.
const FIT := preload("res://scripts/rts_character_fit.gd")
const MODEL_PATH := "res://assets/characters/lyra_voss/rigged.glb"
const WEAPON_PATH := "res://assets/characters/lyra_voss/sniper_rifle.glb"
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

static func has_weapon(rig: Node3D) -> bool:
    if rig == null:
        return false
    for mount in rig.find_children("LyraRifleBackMount", "BoneAttachment3D", true, false):
        if mount.get_node_or_null("LyraSniperRifle") != null:
            return true
    return false


static func attach_weapon(rig: Node3D) -> bool:
    # Keep the approved sniper rifle on the back for the neutral/movement
    # poses. There is no rifle-specific firing clip yet; do not pretend
    # the exported archery motions are realistic gun handling.
    if rig == null or not ResourceLoader.exists(WEAPON_PATH):
        return false
    var skeleton: Skeleton3D = null
    for child in rig.find_children("*", "Skeleton3D", true, false):
        if child is Skeleton3D:
            skeleton = child as Skeleton3D
            break
    if skeleton == null:
        return false
    var spine_index := bone_index(skeleton, "Spine2")
    if spine_index < 0:
        return false
    if skeleton.get_node_or_null("LyraRifleBackMount") != null:
        return true
    var source: Resource = load(WEAPON_PATH)
    if not (source is PackedScene):
        return false
    var weapon: Node = (source as PackedScene).instantiate()
    if not (weapon is Node3D):
        weapon.queue_free()
        return false
    var mount_node := BoneAttachment3D.new()
    mount_node.name = "LyraRifleBackMount"
    skeleton.add_child(mount_node)
    mount_node.bone_name = skeleton.get_bone_name(spine_index)
    var visual: Node3D = weapon as Node3D
    visual.name = "LyraSniperRifle"
    mount_node.add_child(visual)
    # Meshy source spans 1.90m on X. Calibrate to ~1.03m and angle the
    # rifle over the right shoulder. No mesh/skin modification.
    visual.scale = Vector3.ONE * 0.54
    visual.rotation_degrees = Vector3(0.0, 0.0, 68.0)
    visual.position = Vector3(0.21, 0.03, -0.20)
    return true


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
    if not attach_weapon(rig):
        rig.queue_free()
        return {"ok": false, "reason": "missing or unattachable sniper rifle"}
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

static func root_motion_offset(player: AnimationPlayer) -> Vector3:
    # Imported combat clips animate Mixamo Hips translation. RTS movement is
    # driven by navigation; the animation lab cancels horizontal root travel.
    var skeleton: Skeleton3D = find_skeleton(player)
    if skeleton == null:
        return Vector3.ZERO
    var hips := bone_index(skeleton, "Hips")
    if hips < 0:
        return Vector3.ZERO
    return skeleton.get_bone_global_pose(hips).origin - skeleton.get_bone_global_rest(hips).origin


static func hold_ready_pose(player: AnimationPlayer) -> bool:
    # Verified by source GLB joint transforms: the bind/rest pose has
    # feet nearly equal in Y and Z. Prior Walking t=0.25 froze one leg
    # forward by ~0.66m and must NEVER be used for idle/standing.
    var skeleton: Skeleton3D = find_skeleton(player)
    if skeleton == null:
        return false
    if bone_index(skeleton, "LeftFoot") < 0 or bone_index(skeleton, "RightFoot") < 0:
        return false
    player.stop()
    skeleton.reset_bone_poses()
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
