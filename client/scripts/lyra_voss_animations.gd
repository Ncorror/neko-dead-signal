extends RefCounted
## Runtime preview keeps the verified source library and adds authored rifle candidates.
## Rifle Ready/Aim/Fire still require physical Android visual acceptance.
const FIT := preload("res://scripts/rts_character_fit.gd")
const MODEL_PATH := "res://assets/characters/lyra_voss/rigged_rifle_preview.glb"
const WEAPON_PATH := "res://assets/characters/lyra_voss/sniper_rifle.glb"
const FIRE_ANGLE_TOLERANCE := deg_to_rad(8.0)
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
const RIFLE_CLIP_NAMES = ["Rifle_Ready", "Rifle_Aim", "Rifle_Fire"]


const UPPER_BONES = ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]

static func find_skeleton(source: Node) -> Skeleton3D:
    if source == null:
        return null
    var root: Node = source
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


static func _rifle_mount(source: Node) -> BoneAttachment3D:
    if source == null:
        return null
    var root: Node = source
    for attempt in range(5):
        if root == null:
            break
        var direct := root.get_node_or_null("LyraRifleBackMount")
        if direct is BoneAttachment3D:
            return direct as BoneAttachment3D
        for candidate in root.find_children("LyraRifleBackMount", "BoneAttachment3D", true, false):
            if candidate is BoneAttachment3D:
                return candidate as BoneAttachment3D
        root = root.get_parent()
    return null


static func _rifle_carrier(source: Node) -> Node3D:
    var mount := _rifle_mount(source)
    if mount == null:
        return null
    return mount.get_node_or_null("LyraSniperRifle") as Node3D


static func stow_weapon(source: Node) -> bool:
    var skeleton := find_skeleton(source)
    var mount := _rifle_mount(source)
    var carrier := _rifle_carrier(source)
    if skeleton == null or mount == null or carrier == null:
        return false
    var spine_index := bone_index(skeleton, "Spine2")
    if spine_index < 0:
        return false
    mount.bone_name = skeleton.get_bone_name(spine_index)
    var desired_basis := Basis.from_euler(Vector3(0.0, 0.0, deg_to_rad(62.0)))
    var desired := Transform3D(desired_basis, Vector3(0.04, 1.00, -0.11))
    carrier.transform = skeleton.get_bone_global_rest(spine_index).affine_inverse() * desired
    carrier.scale = Vector3.ONE * 0.50
    return true


static func ready_weapon(source: Node) -> bool:
    var skeleton := find_skeleton(source)
    var mount := _rifle_mount(source)
    var carrier := _rifle_carrier(source)
    if skeleton == null or mount == null or carrier == null:
        return false
    var hand_index := bone_index(skeleton, "RightHand")
    if hand_index < 0:
        return false
    # The source rifle's -X axis is the muzzle direction. Calibrate the
    # separate weapon in skeleton space while the authored Rifle_Ready pose is
    # active, then convert that desired transform into RightHand-local space.
    # This avoids inheriting the hand bone's arbitrary local axes (the previous
    # identity transform made the rifle point sideways/down in game).
    var hand_pose: Transform3D = skeleton.get_bone_global_pose(hand_index)
    var rifle_forward_basis := Basis.from_euler(Vector3(0.0, deg_to_rad(90.0), 0.0))
    var desired_origin := hand_pose.origin + Vector3(0.0, 0.025, 0.26)
    var desired := Transform3D(rifle_forward_basis, desired_origin)
    mount.bone_name = skeleton.get_bone_name(hand_index)
    carrier.transform = hand_pose.affine_inverse() * desired
    carrier.scale = Vector3.ONE * 0.50
    return true


static func attach_weapon(rig: Node3D) -> bool:
    if rig == null or not ResourceLoader.exists(WEAPON_PATH):
        return false
    var skeleton: Skeleton3D = find_skeleton(rig)
    if skeleton == null:
        return false
    var spine_index := bone_index(skeleton, "Spine2")
    if spine_index < 0:
        return false
    if skeleton.get_node_or_null("LyraRifleBackMount") != null:
        return stow_weapon(rig)
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

    var carrier := Node3D.new()
    carrier.name = "LyraSniperRifle"
    mount_node.add_child(carrier)
    var visual: Node3D = weapon as Node3D
    visual.name = "RifleGeometry"
    carrier.add_child(visual)

    var measured: Dictionary = FIT.measure_bounds(visual)
    if not bool(measured.get("ok", false)):
        carrier.queue_free()
        return false
    var source_bounds: AABB = measured["bounds"]
    visual.position -= source_bounds.get_center()
    return stow_weapon(rig)


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
    if has_authored_rifle(player) and not ready_weapon(rig):
        rig.queue_free()
        return {"ok": false, "reason": "cannot mount rifle for authored ready pose"}
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


static func has_authored_rifle(player: AnimationPlayer) -> bool:
    if player == null:
        return false
    for clip in RIFLE_CLIP_NAMES:
        if resolve_clip(player, clip).is_empty():
            return false
    return true


static func review_clips(player: AnimationPlayer) -> Array[String]:
    var result: Array[String] = []
    for clip in CLIP_NAMES:
        result.append(str(clip))
    for clip in RIFLE_CLIP_NAMES:
        if not resolve_clip(player, str(clip)).is_empty():
            result.append(str(clip))
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
    var skeleton: Skeleton3D = find_skeleton(player)
    if skeleton == null:
        return false
    var authored := resolve_clip(player, "Rifle_Ready")
    if not authored.is_empty():
        player.stop()
        skeleton.reset_bone_poses()
        var authored_animation := _local_animation(player, authored)
        if authored_animation == null:
            return false
        authored_animation.loop_mode = Animation.LOOP_LINEAR
        player.play(authored)
        player.seek(authored_animation.length * 0.5, true)
        player.pause()
        skeleton.force_update_all_bone_transforms()
        player.set_meta("neko_lyra_motion", "idle")
        return true
    # Fallback for the pinned source GLB: Walking at 0.017 s lowers the arms.
    # Reset hips and both leg chains so the character does not freeze mid-stride.
    var name := resolve_clip(player, "Walking")
    if name.is_empty():
        return false
    player.stop()
    skeleton.reset_bone_poses()
    player.play(name)
    player.seek(0.017, true)
    player.pause()
    for suffix in [
        "Hips",
        "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
        "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"
    ]:
        var index := bone_index(skeleton, suffix)
        if index >= 0:
            skeleton.reset_bone_pose(index)
    skeleton.force_update_all_bone_transforms()
    player.set_meta("neko_lyra_motion", "idle")
    return true


static func restore_ready(player: AnimationPlayer) -> bool:
    if player == null:
        return false
    var authored := has_authored_rifle(player)
    if not hold_ready_pose(player):
        return false
    return ready_weapon(player) if authored else stow_weapon(player)


static func play_attack(player: AnimationPlayer) -> float:
    if player == null or str(player.get_meta("neko_lyra_motion", "")) == "death":
        return 0.0
    # Archery_Shot_2 pulls a bowstring; it is not a two-handed rifle shot.
    # Keep simulation/VFX operational while the authored rifle clip is missing.
    var name := resolve_clip(player, "Rifle_Fire")
    if name.is_empty():
        return 0.0
    var animation := _local_animation(player, name)
    if animation == null or not ready_weapon(player):
        return 0.0
    animation.loop_mode = Animation.LOOP_NONE
    player.set_meta("neko_lyra_motion", "attack")
    player.play(name, 0.06)
    return animation.length


static func play_death(player: AnimationPlayer) -> float:
    if player == null:
        return 0.0
    # Repeated damage/events must not restart a fall or teleport a held rifle
    # onto the back. Keep the attachment used at the moment of death.
    if str(player.get_meta("neko_lyra_motion", "")) == "death":
        return maxf(0.0, player.current_animation_length - player.current_animation_position) if player.is_playing() else 0.0
    var name := resolve_clip(player, "Dead")
    if name.is_empty():
        name = resolve_clip(player, "Fall_Dead_from_Abdominal_Injury")
    if name.is_empty():
        return 0.0
    var animation := _local_animation(player, name)
    if animation == null:
        return 0.0
    animation.loop_mode = Animation.LOOP_NONE
    player.set_meta("neko_lyra_motion", "death")
    player.play(name, 0.08)
    return animation.length


static func play_movement(player: AnimationPlayer, moving: bool, speed: float) -> String:
    if player == null:
        return "missing"
    var current := str(player.get_meta("neko_lyra_motion", ""))
    if current == "death":
        return current
    if current == "attack" and not moving and player.is_playing():
        return current
    var state := "idle"
    if moving:
        state = "run" if speed > 5.2 else "walk"
    if current == state:
        return state
    if state == "idle":
        return "idle" if restore_ready(player) else "missing"
    var name := resolve_clip(player, "Running" if state == "run" else "Walking")
    if name.is_empty():
        return "missing"
    var animation := _local_animation(player, name)
    if animation != null:
        animation.loop_mode = Animation.LOOP_LINEAR
    stow_weapon(player)
    player.play(name, 0.15)
    player.set_meta("neko_lyra_motion", state)
    return state


static func play_preview(player: AnimationPlayer, clip: String) -> bool:
    var name := resolve_clip(player, clip)
    if name.is_empty():
        return false
    if clip in RIFLE_CLIP_NAMES and not ready_weapon(player):
        return false
    var animation := _local_animation(player, name)
    if animation != null:
        animation.loop_mode = Animation.LOOP_LINEAR if clip in ["Walking", "Running", "Rifle_Ready", "Rifle_Aim"] else Animation.LOOP_NONE
    player.set_meta("neko_lyra_motion", "preview")
    player.play(name, 0.1)
    return true


static func _local_animation(player: AnimationPlayer, name: String) -> Animation:
    # PackedScene instances share libraries. Lab loop flags must not change a
    # live actor's death/attack playback. Only copy clips actually used by this
    # actor; meshes, textures, skins and unused animation tracks stay shared.
    if not player.has_meta("neko_local_animations"):
        for library_name in player.get_animation_library_list():
            var original := player.get_animation_library(library_name)
            var local := AnimationLibrary.new()
            for clip in original.get_animation_list():
                local.add_animation(clip, original.get_animation(clip))
            player.remove_animation_library(library_name)
            player.add_animation_library(library_name, local)
        player.set_meta("neko_local_animations", true)
    var copied: Dictionary = player.get_meta("neko_copied_clips", {})
    if not copied.has(name):
        var library_name := name.get_slice("/", 0) if "/" in name else ""
        var clip := name.get_slice("/", 1) if "/" in name else name
        var library := player.get_animation_library(library_name)
        var animation := player.get_animation(name).duplicate() as Animation
        library.remove_animation(clip)
        library.add_animation(clip, animation)
        copied[name] = true
        player.set_meta("neko_copied_clips", copied)
    return player.get_animation(name)
