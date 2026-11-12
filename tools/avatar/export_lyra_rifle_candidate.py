#!/usr/bin/env python3
"""Export the authored Lyra rifle candidate to a runtime GLB.

Run with Blender 4.5 LTS:
  blender --background lyra_rifle_draft.blend --python-exit-code 1 \
    --python tools/avatar/export_lyra_rifle_candidate.py -- --output FILE

The export keeps the original 20 Lyra actions and the authored
Rifle_Ready/Rifle_Aim/Rifle_Fire actions. The separate review-only rifle
recoil action and authoring controls are not exported.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy

SOURCE_CLIPS = {
    "Running", "Walking", "Archery_Aim_with_Lateral_Scan",
    "Archery_Shot_2", "Bar_Hang_Idle", "Charged_Spell_Cast_1",
    "Dead", "Fall_Dead_from_Abdominal_Injury",
    "Hit_in_Back_While_Running", "Kneeling_Reload",
    "Roll_Dodge_1", "Roll_Dodge_3", "Roll_Dodge_4",
    "Shot_and_Fall_Forward", "Slow_Walk_Reload",
    "Standing_Reload", "Sword_Parry_Backward_3",
    "air_squat", "falling_down", "walking_2",
}
RIFLE_CLIPS = {"Rifle_Ready", "Rifle_Aim", "Rifle_Fire"}
REQUIRED = SOURCE_CLIPS | RIFLE_CLIPS


def parse_glb(path: Path) -> dict:
    with path.open("rb") as f:
        header = f.read(12)
        if len(header) != 12:
            raise RuntimeError("Candidate GLB header is truncated")
        magic, version, length = struct.unpack("<4sII", header)
        if magic != b"glTF" or version != 2 or length != path.stat().st_size:
            raise RuntimeError("Candidate is not a complete GLB2")
        json_len, json_type = struct.unpack("<I4s", f.read(8))
        if json_type != b"JSON":
            raise RuntimeError("Candidate GLB has no JSON chunk")
        return json.loads(f.read(json_len))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if len(rigs) != 1:
        raise RuntimeError("Expected exactly one Lyra armature")
    rig = rigs[0]
    if len(rig.data.bones) != 66:
        raise RuntimeError("Expected Lyra 66-bone skeleton")

    action_names = set(bpy.data.actions.keys())
    missing = REQUIRED - action_names
    if missing:
        raise RuntimeError("Missing required actions: " + ", ".join(sorted(missing)))
    if "Rifle_Recoil_Visual" not in action_names:
        raise RuntimeError("Expected review-only weapon recoil action in source blend")

    character_meshes = [
        o for o in bpy.context.scene.objects
        if o.type == "MESH"
        and any(m.type == "ARMATURE" and m.object == rig for m in o.modifiers)
    ]
    if not character_meshes:
        raise RuntimeError("No skinned Lyra mesh found")

    for obj in bpy.context.scene.objects:
        obj.select_set(False)
    rig.select_set(True)
    for mesh in character_meshes:
        mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig

    if rig.animation_data is None:
        rig.animation_data_create()
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for bone in rig.pose.bones:
        bone.matrix_basis.identity()
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()

    result = bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format="GLB",
        use_selection=True,
        export_cameras=False,
        export_lights=False,
        export_extras=False,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_anim_single_armature=True,
        export_nla_strips=False,
        export_force_sampling=True,
        export_reset_pose_bones=True,
        export_current_frame=False,
        export_rest_position_armature=True,
        export_skins=True,
        export_all_influences=False,
        export_morph=True,
        export_morph_animation=True,
        export_yup=True,
    )
    if "FINISHED" not in result or not output.is_file():
        raise RuntimeError("Blender GLB export failed")

    doc = parse_glb(output)
    clips = [a.get("name", "") for a in doc.get("animations", [])]
    clip_set = set(clips)
    if len(clips) != len(clip_set):
        raise RuntimeError("Duplicate animation names in runtime candidate")
    missing_export = REQUIRED - clip_set
    if missing_export:
        raise RuntimeError("Export omitted actions: " + ", ".join(sorted(missing_export)))
    if "Rifle_Recoil_Visual" in clip_set:
        raise RuntimeError("Review-only weapon recoil leaked into runtime GLB")
    if len(clips) != 23:
        raise RuntimeError(f"Expected 23 runtime clips, got {len(clips)}")

    skins = doc.get("skins", [])
    if len(skins) != 1 or len(skins[0].get("joints", [])) != 66:
        raise RuntimeError("Exported candidate changed Lyra skeleton inventory")
    if not any(
        "JOINTS_0" in primitive.get("attributes", {})
        and "WEIGHTS_0" in primitive.get("attributes", {})
        for mesh in doc.get("meshes", [])
        for primitive in mesh.get("primitives", [])
    ):
        raise RuntimeError("Exported candidate lost skin weights")

    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    report = {
        "status": "PASS",
        "sha256": digest,
        "bytes": output.stat().st_size,
        "bones": 66,
        "clips": clips,
        "source_clips": 20,
        "authored_rifle_clips": sorted(RIFLE_CLIPS),
        "visual_acceptance": "REQUIRED_ON_ANDROID",
    }
    report_path = output.with_suffix(".json")
    report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print("LYRA_RIFLE_RUNTIME_EXPORT_PASS " + json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
