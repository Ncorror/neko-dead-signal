"""Author editable Lyra rifle pose candidates from the pinned Blender setup.

Usage: blender --background lyra_authoring.blend --python-exit-code 1 \
  --python tools/avatar/author_lyra_rifle.py -- --output DIR

Review-only artifact: does not replace any game GLB or original animation.
"""
import argparse
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

FPS = 30
LENGTHS = {"Rifle_Ready": 91, "Rifle_Aim": 61, "Rifle_Fire": 19}


def named_bone(rig, suffix):
    matches = [p for p in rig.pose.bones if p.name.endswith(suffix)]
    if len(matches) != 1:
        raise RuntimeError("Missing/ambiguous bone " + suffix)
    return matches[0]


def controlled_empty(name):
    o = bpy.data.objects.get(name)
    if o is None or o.type != "EMPTY":
        raise RuntimeError("Missing Blender authoring controller: " + name)
    return o


def reset_controller_actions(ctrls):
    for ctrl in ctrls:
        action = ctrl.animation_data.action if ctrl.animation_data else None
        ctrl.animation_data_clear()
        if action is not None and action.users == 0:
            bpy.data.actions.remove(action)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    out = args.output.resolve()
    if out.exists() and any(out.iterdir()):
        raise RuntimeError("Refuse to overwrite existing artist work")
    out.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    if scene.render.fps != FPS:
        raise RuntimeError("Original authoring scene must use 30 fps")
    rigs = [o for o in scene.objects if o.type == "ARMATURE"]
    if len(rigs) != 1:
        raise RuntimeError("Expected exactly one Lyra rig")
    rig = rigs[0]
    if len(rig.data.bones) != 66:
        raise RuntimeError("Lyra's original 66 bones missing")
    source_action_names = set(bpy.data.actions.keys())
    if len(source_action_names) != 20 or source_action_names & LENGTHS.keys():
        raise RuntimeError("Expected exactly 20 original animation clips")
    original_rest = {b.name: [list(row) for row in b.matrix_local]
                     for b in rig.data.bones}
    for a in bpy.data.actions:
        a.use_fake_user = True
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for p in rig.pose.bones:
        p.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()

    right_arm = named_bone(rig, "RightArm")
    left_arm = named_bone(rig, "LeftArm")
    right_fore = named_bone(rig, "RightForeArm")
    left_fore = named_bone(rig, "LeftForeArm")
    targets = [controlled_empty("Right_Wrist_IK"),
               controlled_empty("Left_Wrist_IK")]
    poles = [controlled_empty("Right_Elbow_Pole"),
             controlled_empty("Left_Elbow_Pole")]
    rifle = controlled_empty("Rifle_Layout")
    if any(abs(axis - 0.5) > 0.001 for axis in rifle.scale):
        raise RuntimeError("Expected the measured 0.5x game weapon scale")
    for fore, target, pole in zip((right_fore, left_fore), targets, poles):
        constraints = [c for c in fore.constraints if c.type == "IK"]
        if len(constraints) != 1 or constraints[0].target != target:
            raise RuntimeError("Unexpected hand authoring IK")
        if constraints[0].pole_target != pole or constraints[0].chain_count != 2:
            raise RuntimeError("Unexpected elbow IK geometry")
        constraints[0].influence = 1.0
        constraints[0].use_stretch = False

    shoulder_r = rig.matrix_world @ right_arm.head
    shoulder_l = rig.matrix_world @ left_arm.head
    grip = shoulder_r + Vector((-0.02, -0.21, -0.12))
    support = shoulder_l + Vector((-0.21, -0.37, -0.07))
    reach = {}
    for label, arm, fore, shoulder, target in [
        ("right", right_arm, right_fore, shoulder_r, grip),
        ("left", left_arm, left_fore, shoulder_l, support),
    ]:
        length = (arm.tail - arm.head).length + (fore.tail - fore.head).length
        distance = (target - shoulder).length
        if distance >= length * 0.98:
            raise RuntimeError(label + " IK target exceeds real limb reach")
        reach[label] = {"required_m": round(distance, 4),
                        "available_m": round(length, 4)}
    poles[0].location = shoulder_r + Vector((-0.30, -0.06, -0.26))
    poles[1].location = shoulder_l + Vector((+0.30, -0.06, -0.26))

    def under_rifle(obj):
        while obj.parent is not None:
            obj = obj.parent
            if obj == rifle:
                return True
        return False

    # Preview render exposed +X as the STOCK, not muzzle. Correct forward
    # orientation maps source -X to character -Y.
    rifle.rotation_euler = (0.0, 0.0, math.pi / 2)
    bpy.context.view_layer.update()
    corners = [obj.matrix_world @ Vector(corner)
               for obj in scene.objects if obj.type == "MESH" and under_rifle(obj)
               for corner in obj.bound_box]
    if not corners:
        raise RuntimeError("Rifle mesh missing")
    min_v = Vector(tuple(min(v[i] for v in corners) for i in range(3)))
    max_v = Vector(tuple(max(v[i] for v in corners) for i in range(3)))
    length = max_v.y - min_v.y
    if not 0.7 < length < 1.2:
        raise RuntimeError("Expected approximately 0.95 m rifle, got %.3f" % length)
    center = shoulder_r + Vector((0.0, -length * 0.5, -0.025))
    rifle.location += center - (min_v + max_v) * 0.5
    rifle_base = rifle.location.copy()

    markers = bpy.data.collections.new("RIFLE_SOCKETS_APPROXIMATE_REVIEW")
    scene.collection.children.link(markers)
    positions = {
        "Rifle_Stock": shoulder_r + Vector((0, -0.04, -0.025)),
        "Rifle_Grip": grip,
        "Rifle_Support": support,
        "Rifle_Muzzle": center + Vector((0, -length * 0.5, 0)),
    }
    for name, pos in positions.items():
        obj = bpy.data.objects.new(name, None)
        markers.objects.link(obj)
        obj.empty_display_type = "SPHERE"
        obj.empty_display_size = 0.035
        obj.location = pos
        obj["status"] = "APPROXIMATE — inspect exact geometry before export"

    # The frames are genuine authored arm trajectories (not renamed bow clips).
    # Keyframe controllers, then visual-bake the IK result onto deform bones.
    frames = {
        "Rifle_Ready": [
            (1, 0, 0, 0), (45, 0, 0, 0.006), (91, 0, 0, 0),
        ],
        "Rifle_Aim": [
            (1, 0, 0, 0), (10, -0.015, 0.030, 0),
            (50, -0.015, 0.030, 0), (61, 0, 0, 0),
        ],
        "Rifle_Fire": [
            (1, -0.015, 0.030, 0), (4, 0.055, 0.048, 0.07),
            (7, 0.012, 0.036, 0.027), (19, -0.015, 0.030, 0),
        ],
    }
    bpy.ops.object.mode_set(mode="OBJECT") if bpy.context.object and bpy.context.object.mode != "OBJECT" else None
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="POSE")
    for b in rig.data.bones:
        b.select = True
    controllers = [*targets, rifle]
    for name, keys in frames.items():
        rig.animation_data.action = None
        reset_controller_actions(controllers)
        for frame, forward, up, recoil in keys:
            scene.frame_set(frame)
            for target, position in zip(targets, (grip, support)):
                target.location = position + Vector((0, forward + recoil, up))
                target.keyframe_insert(data_path="location", frame=frame)
            rifle.location = rifle_base + Vector((0, forward + recoil, up))
            rifle.keyframe_insert(data_path="location", frame=frame)
            bpy.context.view_layer.update()
        scene.frame_set(1)
        result = bpy.ops.nla.bake(
            frame_start=1, frame_end=LENGTHS[name], step=1,
            only_selected=True, visual_keying=True,
            clear_constraints=False, clear_parents=False,
            use_current_action=False, clean_curves=False, bake_types={"POSE"})
        if "FINISHED" not in result or rig.animation_data.action is None:
            raise RuntimeError("Visual pose bake failed: " + name)
        rig.animation_data.action.name = name
        rig.animation_data.action.use_fake_user = True
        print("LYRA_RIFLE_ACTION_BAKED", name, LENGTHS[name])

    bpy.ops.object.mode_set(mode="OBJECT")
    for fore in (right_fore, left_fore):
        for constraint in fore.constraints:
            if constraint.type == "IK":
                constraint.influence = 0.0
    reset_controller_actions(controllers)
    rifle.location = rifle_base
    rig.animation_data.action = None
    if original_rest != {b.name: [list(row) for row in b.matrix_local]
                        for b in rig.data.bones}:
        raise RuntimeError("Source rest pose mutated")
    # Author the matching weapon recoil as its own editable Action. It plays
    # alongside the skeletal Fire Action in Blender previews, never on top of
    # the imported GLB and never in the shipping Android animation set.
    for frame, forward, up, recoil in frames["Rifle_Fire"]:
        scene.frame_set(frame)
        rifle.location = rifle_base + Vector((0, forward + recoil, up))
        rifle.keyframe_insert(data_path="location", frame=frame)
    weapon_recoil = rifle.animation_data.action
    if weapon_recoil is None:
        raise RuntimeError("Weapon recoil Action could not be authored")
    weapon_recoil.name = "Rifle_Recoil_Visual"
    weapon_recoil.use_fake_user = True
    rifle.animation_data.action = None
    rifle.location = rifle_base
    if len(bpy.data.actions) != 24 or not source_action_names.issubset(
        set(bpy.data.actions.keys())
    ):
        raise RuntimeError("Original actions missing or prototype actions not preserved")

    evidence = {
        "status": "DRAFT_REQUIRES_VISUAL_ACCEPTANCE",
        "source_actions": 20,
        "source_bones": 66,
        "prototype_clips": LENGTHS,
        "rifle_recoil_action": "Rifle_Recoil_Visual",
        "fps": FPS,
        "shot_event_frame": 4,
        "shot_event_seconds": 0.1,
        "source_rifle_axis": "-X is muzzle (visual review of first prototype)",
        "assumed_game_muzzle_direction": "-Y (flipped after first render showed stock forward)",
        "rifle_length_m": round(length, 4),
        "arm_reach": reach,
        "approximate_sockets_world": {k: list(map(float, v))
                                      for k, v in positions.items()},
        "pending": [
            "Actual stock/trigger/barrel mesh contact calibration",
            "Hands/fingers/pole angles, cloth and shoulder skinning review",
            "Front, side, rear and 3/4 visual acceptance",
            "Animation export and Android gameplay integration",
        ],
    }
    (out / "rifle_draft_report.json").write_text(
        json.dumps(evidence, indent=2, ensure_ascii=False) + "\n")
    note = bpy.data.texts.new("RIFLE_DRAFT_README")
    note.write("LYRA PROTOTYPE ONLY: do not ship until visual acceptance.\n"
               "Original 20 Mixamo clips and 66 bones are untouched.\n"
               "Rifle_Ready/Rifle_Aim/Rifle_Fire are editable IK-baked candidates.\n"
               "Rifle_Recoil_Visual animates the separate weapon root during fire.\n"
               "Grip/support/stock/muzzle markers are approximate; calibrate to rifle mesh.\n"
               "Source -X is muzzle: first renders exposed a reversed stock.\n"
               "Shot frame 4 at 30 fps (.1s) is NOT wired to game damage.\n")
    # Open the file in Rifle_Ready rather than the original A-pose, so the
    # reviewer's first visible state is the candidate under examination.
    rig.animation_data.action = bpy.data.actions["Rifle_Ready"]
    scene.frame_set(45)
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "lyra_rifle_draft.blend"))
    if args.render:
        cam = scene.camera
        if cam is None:
            raise RuntimeError("Original authoring camera missing")
        for label, clip, frame, viewpoint in (
            ("ready_front", "Rifle_Ready", 45, Vector((0.0, -5.0, 1.0))),
            ("aim_three_quarter", "Rifle_Aim", 35, Vector((2.8, -4.5, 2.1))),
            ("fire_side", "Rifle_Fire", 4, Vector((5.0, 0.0, 1.0))),
        ):
            rig.animation_data.action = bpy.data.actions[clip]
            rifle.animation_data.action = weapon_recoil if clip == "Rifle_Fire" else None
            if clip != "Rifle_Fire":
                rifle.location = rifle_base
            scene.frame_set(frame)
            cam.location = viewpoint
            cam.rotation_euler = (Vector((0.0, -0.25, 1.0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(out / (label + ".png"))
            bpy.ops.render.render(write_still=True)
        rifle.animation_data.action = None
        rifle.location = rifle_base
    print("LYRA_RIFLE_DRAFT_PASS", json.dumps({
        "actions": list(LENGTHS), "weapon_action": "Rifle_Recoil_Visual", "source_actions": 20,
        "source_bones": 66, "visual_review_required": True,
    }))


if __name__ == "__main__":
    main()
