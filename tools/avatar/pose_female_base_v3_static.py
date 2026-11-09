#!/usr/bin/env python3
"""Create a static relaxed standing pose from the approved Meshy Female Base v3.

Uses a smooth, cylindrical arm-influence field around the existing A-pose arms.
No rig, regeneration, remeshing or retexturing. Input is never overwritten.
Requires Python 3 and NumPy. Run on a COPY of the original Meshy asset.
"""
from pathlib import Path
import argparse
import hashlib
import json
import struct
import numpy as np


def smoothstep(value):
    t = np.clip(value, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def process(source: Path, output: Path, degrees: float = 22.0):
    if source.resolve() == output.resolve():
        raise ValueError("Refusing to overwrite the original GLB")
    blob = bytearray(source.read_bytes())
    magic, version, total = struct.unpack_from("<4sII", blob)
    if (magic, version, total) != (b"glTF", 2, len(blob)):
        raise ValueError("Invalid GLB v2")
    json_len, json_typ = struct.unpack_from("<I4s", blob, 12)
    if json_typ != b"JSON":
        raise ValueError("Missing JSON chunk")
    doc = json.loads(blob[20:20 + json_len])
    if len(doc.get("meshes", [])) != 1 or len(doc["meshes"][0]["primitives"]) != 1:
        raise ValueError("Unexpected geometry: script supports the approved Meshy GLB")
    prim = doc["meshes"][0]["primitives"][0]
    bin_offset = 28 + json_len

    def array(name):
        acc = doc["accessors"][prim["attributes"][name]]
        view = doc["bufferViews"][acc["bufferView"]]
        if acc["type"] != "VEC3" or acc["componentType"] != 5126 or view.get("byteStride"):
            raise ValueError("Unexpected vertex data format")
        offset = bin_offset + view.get("byteOffset", 0) + acc.get("byteOffset", 0)
        return (np.frombuffer(blob, "<f4", count=acc["count"] * 3,
                              offset=offset).reshape(-1, 3), acc)

    positions, pos_acc = array("POSITION")
    normals, _ = array("NORMAL")
    p = np.array(positions, copy=True)
    n = np.array(normals, copy=True)
    x, y, _ = p.T
    side = np.where(x >= 0, 1.0, -1.0)
    pivot_x, pivot_y = side * 0.164, 0.530
    dx, dy = x - pivot_x, y - pivot_y

    # The influence follows both arms and softly fades into the shoulders.
    # A narrow x-only selector produces inverted triangles near elbows; do NOT
    # replace this with an x-only cutoff.
    radial = np.abs((np.abs(x) - 0.164) * 0.877 + dy * 0.48)
    along = (np.abs(x) - 0.164) * 0.48 - dy * 0.877
    weight = smoothstep((along - 0.025) / 0.18) * (
        1.0 - smoothstep((radial - 0.060) / 0.12)
    )
    angle = np.deg2rad(degrees) * weight * (-side)
    c, s = np.cos(angle), np.sin(angle)

    p[:, 0] = pivot_x + dx * c - dy * s
    p[:, 1] = pivot_y + dx * s + dy * c
    n[:, 0] = normals[:, 0] * c - normals[:, 1] * s
    n[:, 1] = normals[:, 0] * s + normals[:, 1] * c
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1.0e-12)
    positions[:] = p
    normals[:] = n
    pos_acc["min"] = p.min(axis=0).astype(float).tolist()
    pos_acc["max"] = p.max(axis=0).astype(float).tolist()

    chunk = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode()
    chunk += b" " * (-len(chunk) % 4)
    bin_chunk_pos = 20 + json_len
    bin_len, bin_type = struct.unpack_from("<I4s", blob, bin_chunk_pos)
    if bin_type != b"BIN\\x00".decode("unicode_escape").encode():
        raise ValueError("Missing GLB binary chunk")
    payload = bytes(blob[bin_chunk_pos + 8:bin_chunk_pos + 8 + bin_len])
    with output.open("wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 28 + len(chunk) + len(payload)))
        f.write(struct.pack("<I4s", len(chunk), b"JSON"))
        f.write(chunk)
        f.write(struct.pack("<I4s", len(payload), b"BIN\\x00".decode("unicode_escape").encode()))
        f.write(payload)
    print(json.dumps({
        "original_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "output_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "vertices": int(len(p)), "pose_degrees": degrees,
        "skins": len(doc.get("skins", [])),
        "animations": len(doc.get("animations", [])),
    }, indent=2))


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("source", type=Path)
    ap.add_argument("output", type=Path)
    ap.add_argument("--degrees", type=float, default=22.0)
    args = ap.parse_args()
    process(args.source, args.output, args.degrees)
