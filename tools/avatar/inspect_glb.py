#!/usr/bin/env python3
"""Read-only GLB inventory for the NEKO: DEAD SIGNAL avatar pipeline.

Requires only Python 3 standard library. Never modifies the input GLB.
This is a structural inventory, NOT a topology, deformation, or visual QA.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

GLB_MAGIC = b"glTF"
JSON_CHUNK = 0x4E4F534A
TRIANGLES = 4
TRIANGLE_STRIP = 5
TRIANGLE_FAN = 6


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_glb_json(path: Path) -> dict:
    actual_size = path.stat().st_size
    with path.open("rb") as source:
        header = source.read(12)
        if len(header) != 12:
            raise ValueError("GLB header is incomplete")
        magic, version, total_size = struct.unpack("<4sII", header)
        if magic != GLB_MAGIC or version != 2:
            raise ValueError("Expected glTF 2.0 binary GLB")
        if total_size != actual_size:
            raise ValueError(f"GLB size mismatch: header={total_size}, file={actual_size}")
        chunk_header = source.read(8)
        if len(chunk_header) != 8:
            raise ValueError("GLB JSON chunk header is incomplete")
        chunk_size, chunk_type = struct.unpack("<II", chunk_header)
        if chunk_type != JSON_CHUNK or chunk_size > total_size - 20:
            raise ValueError("Invalid GLB JSON chunk")
        # The JSON chunk is normally small even for large geometry files.
        if chunk_size > 64 * 1024 * 1024:
            raise ValueError("GLB JSON chunk unexpectedly exceeds 64 MiB")
        payload = source.read(chunk_size)
        if len(payload) != chunk_size:
            raise ValueError("GLB JSON chunk is truncated")
        result = json.loads(payload.decode("utf-8").rstrip("\x00 \t\r\n"))
        if not isinstance(result, dict) or result.get("asset", {}).get("version") != "2.0":
            raise ValueError("Invalid glTF 2.0 asset metadata")
        return result


def accessor_count(accessors: list, index) -> int:
    if not isinstance(index, int) or not 0 <= index < len(accessors):
        return 0
    value = accessors[index].get("count", 0)
    return value if isinstance(value, int) and value >= 0 else 0


def inspect(path: Path) -> dict:
    root = load_glb_json(path)
    accessors = root.get("accessors", [])
    meshes = []
    sum_triangles = 0
    total_morph_targets = 0
    for mesh in root.get("meshes", []):
        primitives = []
        for primitive in mesh.get("primitives", []):
            mode = primitive.get("mode", TRIANGLES)
            attributes = primitive.get("attributes", {})
            vertex_count = accessor_count(accessors, attributes.get("POSITION"))
            count = accessor_count(accessors, primitive.get("indices")) if "indices" in primitive else vertex_count
            triangle_count = count // 3 if mode == TRIANGLES else max(0, count - 2) if mode in (TRIANGLE_STRIP, TRIANGLE_FAN) else None
            if triangle_count is not None:
                sum_triangles += triangle_count
            morph_count = len(primitive.get("targets", []))
            total_morph_targets += morph_count
            primitives.append({
                "material_index": primitive.get("material"),
                "mode": mode,
                "vertex_count": vertex_count,
                "index_count": count if "indices" in primitive else None,
                "triangle_count": triangle_count,
                "morph_target_count": morph_count,
                "has_joint_weights": "JOINTS_0" in attributes and "WEIGHTS_0" in attributes,
            })
        meshes.append({"name": mesh.get("name", ""), "primitives": primitives})
    skins = [
        {"name": skin.get("name", ""), "joint_count": len(skin.get("joints", []))}
        for skin in root.get("skins", [])
    ]
    animations = [
        {"name": anim.get("name", ""), "channel_count": len(anim.get("channels", []))}
        for anim in root.get("animations", [])
    ]
    return {
        "source_file": path.name,
        "sha256": sha256_file(path),
        "byte_size": path.stat().st_size,
        "gltf_version": root["asset"]["version"],
        "mesh_count": len(meshes),
        "mesh_primitives": meshes,
        "estimated_total_mesh_triangles": sum_triangles,
        "note": "Triangle sum counts mesh definitions; instanced nodes can draw them multiple times.",
        "node_count": len(root.get("nodes", [])),
        "skin_count": len(skins),
        "skins": skins,
        "morph_targets_count_across_primitives": total_morph_targets,
        "animations": animations,
        "material_count": len(root.get("materials", [])),
        "image_count": len(root.get("images", [])),
        "texture_count": len(root.get("textures", [])),
        "extensions_used": root.get("extensionsUsed", []),
        "extensions_required": root.get("extensionsRequired", []),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("glb", type=Path, help="Original GLB downloaded from Meshy")
    args = parser.parse_args()
    try:
        print(json.dumps(inspect(args.glb), ensure_ascii=False, indent=2))
    except (OSError, ValueError, UnicodeError, json.JSONDecodeError, TypeError, KeyError) as error:
        print(f"GLB_INSPECTION_FAILED: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
