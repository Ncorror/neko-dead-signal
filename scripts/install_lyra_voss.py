#!/usr/bin/env python3
"""Install SHA256-pinned Lyra Voss rigged GLB from approved Google Drive file."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct

DRIVE_ID = "1pGFfupTnkiciqnsIxJcA5-leoDHFqT9N"
SHA256 = "2cdfae99b4dda6c69b608cdb3d46875d9003a7208e89e5683a2021592f9bf14e"
RELATIVE = Path("client/assets/characters/lyra_voss/rigged.glb")
REQUIRED = {"Walking", "Running", "Archery_Aim_with_Lateral_Scan", "Standing_Reload", "Dead"}

def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1048576), b""):
            h.update(chunk)
    return h.hexdigest()

def inspect(path: Path):
    with path.open("rb") as f:
        header = f.read(12)
        if len(header) != 12:
            raise ValueError("Invalid GLB header")
        magic, version, length = struct.unpack("<4sII", header)
        if (magic, version, length) != (b"glTF", 2, path.stat().st_size):
            raise ValueError("Not a complete GLB2")
        length_json, kind = struct.unpack("<I4s", f.read(8))
        if kind != b"JSON" or length_json > 16_777_216:
            raise ValueError("Invalid GLB JSON")
        doc = json.loads(f.read(length_json))
    clips = [c.get("name", "") for c in doc.get("animations", [])]
    if len(clips) != 20 or len(set(clips)) != 20 or not REQUIRED.issubset(clips):
        raise ValueError("Wrong Lyra animation library")
    skins = doc.get("skins", [])
    if len(skins) != 1 or len(skins[0].get("joints", [])) != 66:
        raise ValueError("Wrong Mixamo skeleton")
    if not any("JOINTS_0" in p.get("attributes", {}) and "WEIGHTS_0" in p.get("attributes", {})
               for m in doc.get("meshes", []) for p in m.get("primitives", [])):
        raise ValueError("Missing vertex weights")
    return len(clips), len(skins[0]["joints"])

def install(root: Path, check_only=False):
    target = root / RELATIVE
    if target.exists():
        if digest(target) != SHA256:
            raise ValueError("REFUSE_TO_OVERWRITE_UNVERIFIED_LYRA_MODEL")
        clips, bones = inspect(target)
        print("LYRA_ASSET_PASS existing=1 clips=%d bones=%d" % (clips, bones))
        return
    if check_only:
        raise ValueError("LYRA_ASSET_MISSING")
    try:
        import gdown
    except ImportError as exc:
        raise RuntimeError("Install gdown==5.2.0") from exc
    target.parent.mkdir(parents=True, exist_ok=True)
    temp = target.with_suffix(".glb.partial")
    if temp.exists():
        raise ValueError("REFUSE_TO_OVERWRITE_PARTIAL")
    try:
        downloaded = gdown.download(id=DRIVE_ID, output=str(temp), quiet=False)
        if not downloaded or not temp.is_file():
            raise ValueError("LYRA_DOWNLOAD_FAILED")
        if digest(temp) != SHA256:
            raise ValueError("LYRA_SHA256_MISMATCH")
        clips, bones = inspect(temp)
        os.replace(temp, target)
        print("LYRA_ASSET_PASS clips=%d bones=%d" % (clips, bones))
    finally:
        if temp.exists():
            temp.unlink()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    install(Path(__file__).resolve().parent.parent, args.check_only)
