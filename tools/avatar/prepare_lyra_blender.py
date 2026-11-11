"""Run with Blender 4.5 LTS --background --python ... -- --output DIR.

Creates a self-contained authoring file, never modifies source GLBs.
Controls start at bind-pose wrists; sockets must be calibrated visually.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCES = {
    "rigged.glb": "2cdfae99b4dda6c69b608cdb3d46875d9003a7208e89e5683a2021592f9bf14e",
    "sniper_rifle.glb": "fa324f0e3fdd5fc9e3447146c0322bd8b5422098275ddf1fe51202897bede47e",
}


def empty(name, position, collection):
    obj = bpy.data.objects.new(name, None)
    collection.objects.link(obj)
    obj.location = position
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.08
    obj.show_in_front = True
    return obj


def bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects if obj.type == "MESH" for corner in obj.bound_box]
    return [Vector([fn(p[i] for p in points) for i in range(3)]) for fn in (min, max)]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--render", action="store_true")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:])
    out = args.output.resolve()
    if (out / "lyra_authoring.blend").exists():
        raise RuntimeError("Choose a new output directory; author work will not be overwritten")
    paths = {}
    for name, expected in SOURCES.items():
        path = ROOT / "client/assets/characters/lyra_voss" / name
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise RuntimeError("Source hash mismatch: " + name)
        paths[name] = path
    out.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = 30  # Set BEFORE glTF import: clip seconds stay unchanged.
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    bpy.ops.import_scene.gltf(filepath=str(paths["rigged.glb"]))
    rigs = [o for o in scene.objects if o.type == "ARMATURE"]
    assert len(rigs) == 1
    rig = rigs[0]
    assert len(rig.data.bones) == 66
    actions = list(bpy.data.actions)
    assert len(actions) == 20
    for action in actions:
        action.use_fake_user = True
    # Preserve source actions/NLA, but leave authoring controls at rest.
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    character_meshes = [o for o in scene.objects if o.type == "MESH" and any(m.type == "ARMATURE" and m.object == rig for m in o.modifiers)]
    assert character_meshes, "No skinned character mesh"
    body_bounds = bounds(character_meshes)
    bone_snapshot = {b.name: [list(row) for row in b.matrix_local] for b in rig.data.bones}
    controls = bpy.data.collections.new("AUTHORING_CONTROLS_NOT_FOR_EXPORT")
    scene.collection.children.link(controls)

    def bone(suffix):
        found = [b for b in rig.pose.bones if b.name.endswith(suffix)]
        assert len(found) == 1, suffix
        return found[0]

    for side in ("Left", "Right"):
        hand, forearm = bone(side + "Hand"), bone(side + "ForeArm")
        target = empty(side + "_Wrist_IK", rig.matrix_world @ hand.head, controls)
        target.rotation_mode = "QUATERNION"
        target.rotation_quaternion = (rig.matrix_world @ hand.matrix).to_quaternion()
        ik = forearm.constraints.new("IK")
        ik.name = "Authoring two-bone arm IK"
        ik.target = target
        ik.chain_count = 2
        ik.use_stretch = False
        # Disabled until pole/hand placement is reviewed; enabling a guessed
        # solution at import would alter the verified rest mesh silently.
        ik.influence = 0.0
        pole = empty(side + "_Elbow_Pole", rig.matrix_world @ forearm.head + Vector((0, 0.3, 0)), controls)
        ik.pole_target = pole
        orient = hand.constraints.new("COPY_ROTATION")
        orient.name = "Authoring wrist orientation"
        orient.target = target
        orient.target_space = "WORLD"
        orient.owner_space = "WORLD"
        orient.influence = 0.0
        target["instructions"] = "Position wrist and elbow pole; tune pole_angle; enable both constraints. Bake visual transforms before export."

    before = set(scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(paths["sniper_rifle.glb"]))
    weapon_objects = set(scene.objects) - before
    weapon_bounds = bounds(weapon_objects)
    weapon_root = empty("Rifle_Layout", (0, 0, 0), controls)
    center = (weapon_bounds[0] + weapon_bounds[1]) * 0.5
    for obj in weapon_objects:
        if obj.parent not in weapon_objects:
            matrix = obj.matrix_world.copy()
            obj.parent = weapon_root
            obj.matrix_world = matrix
    # Same uniform scale used by runtime. Display separately for calibration.
    weapon_root.scale = (0.5,) * 3
    weapon_root.location = Vector((1.0, 0.0, 1.0)) - center * 0.5
    weapon_root["status"] = "LAYOUT ONLY: calibrate grip/support/stock/muzzle on actual geometry before attaching"
    bpy.context.view_layer.update()
    assert bone_snapshot == {b.name: [list(row) for row in b.matrix_local] for b in rig.data.bones}
    # Capture measured rest-pose landmarks and actual weapon bounds so the
    # first rifle grip and support placements use this GLB, not guessed axes.
    sockets = {}
    for label in (
        "Spine2", "Neck", "Head", "LeftShoulder", "RightShoulder",
        "LeftArm", "RightArm", "LeftForeArm", "RightForeArm",
        "LeftHand", "RightHand", "Hips",
    ):
        pbone = bone(label)
        sockets[label] = {
            "head": [round(float(c), 5) for c in rig.matrix_world @ pbone.head],
            "tail": [round(float(c), 5) for c in rig.matrix_world @ pbone.tail],
        }
    dims = weapon_bounds[1] - weapon_bounds[0]
    weapon_stats = {
        "bounds_world": [list(map(float, corner)) for corner in weapon_bounds],
        "dimensions_world": [round(float(c), 5) for c in dims],
        "long_axis": "XYZ"[max(range(3), key=lambda i: dims[i])],
    }
    report = {
        "status": "AUTHORING_SETUP_NOT_GAME_READY",
        "blender": bpy.app.version_string, "fps": 30, "sources": SOURCES,
        "bones": len(rig.data.bones), "rest_matrices_unchanged": True,
        "character_bounds_m": [list(v) for v in body_bounds],
        "weapon_source_bounds_m": [list(v) for v in weapon_bounds],
        "actions_seconds": {a.name: float(a.frame_range[1] - a.frame_range[0]) / 30 for a in actions},
        "constraints_enabled": False, "sockets_calibrated": False,
        "rest_pose_landmarks": sockets, "rifle_source_geometry": weapon_stats,
    }
    print("LYRA_GEOMETRY_PROBE " + json.dumps({
        "bones": sockets, "rifle": weapon_stats,
    }, sort_keys=True))
    (out / "setup_report.json").write_text(json.dumps(report, indent=2) + "\n")
    note = bpy.data.texts.new("START_HERE")
    note.write("Lyra authoring setup. Source clips preserved (fake users), NLA muted.\n"
               "Blender axes: Z up, character front -Y (glTF +Z). Units metres, 30 fps.\n"
               "Rifle displayed separately at runtime scale 0.5; not calibrated.\n"
               "Wrist IK and rotation constraints OFF initially. Tune elbow poles before enabling.\n"
               "Keep rest bones/skin unchanged. Bake authored action on deform bones for glTF export.\n"
               "Do not export controls, lights, cameras or layout rifle with character animations.\n"
               "No new animation is approved or generated by this setup script.\n")
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 16
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new("Studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs[0].default_value = (0.12, 0.12, 0.12, 1)
    for name, at, power in [("Key", (2, -4, 4), 500), ("Fill", (-3, -1, 2), 250)]:
        light = bpy.data.lights.new(name, "AREA")
        light.energy = power
        light.shape = "DISK"
        light.size = 4
        obj = bpy.data.objects.new(name, light)
        scene.collection.objects.link(obj)
        obj.location = at
        obj.rotation_euler = (Vector((0, 0, 1)) - obj.location).to_track_quat("-Z", "Y").to_euler()
    cam = bpy.data.objects.new("ReviewCamera", bpy.data.cameras.new("ReviewCamera"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.7
    scene.camera = cam
    cam.location = (2.8, -4.5, 2.1)
    cam.rotation_euler = (Vector((0.4, 0, 0.9)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(out / "lyra_authoring.blend"))
    if args.render:
        for name, at in [("front", (0.4, -5, 1.0)), ("three_quarter", (2.8, -4.5, 2.1)), ("side", (5, 0, 1.0))]:
            cam.location = at
            cam.rotation_euler = (Vector((0.4, 0, 0.9)) - cam.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = str(out / (name + ".png"))
            bpy.ops.render.render(write_still=True)
    print("LYRA_BLENDER_SETUP_PASS", out)


if __name__ == "__main__":
    main()
