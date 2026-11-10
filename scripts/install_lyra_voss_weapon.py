#!/usr/bin/env python3
"""Install user's exact Meshy Lyra sniper rifle without modifying source assets."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import struct

DRIVE_ID = "1Zna4PSUJka1NuxdghxuW1DI4C3fx4G1n"
SHA256 = "fa324f0e3fdd5fc9e3447146c0322bd8b5422098275ddf1fe51202897bede47e"
SIZE = 8373476
RELATIVE = Path("client/assets/characters/lyra_voss/sniper_rifle.glb")

def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1048576), b""):
            h.update(chunk)
    return h.hexdigest()

def validate(path: Path) -> int:
    with path.open("rb") as f:
        header = f.read(12)
        if len(header) != 12:
            raise ValueError("Truncated rifle GLB")
        magic, version, length = struct.unpack("<4sII", header)
        if (magic, version, length) != (b"glTF", 2, SIZE):
            raise ValueError("Wrong rifle GLB header")
        jlen, jtype = struct.unpack("<I4s", f.read(8))
        if jtype != b"JSON" or jlen > 16_777_216:
            raise ValueError("Wrong rifle JSON")
        doc = json.loads(f.read(jlen))
    if path.stat().st_size != SIZE:
        raise ValueError("Wrong rifle size")
    if doc.get("skins") or doc.get("animations") or len(doc.get("meshes", [])) != 1:
        raise ValueError("Weapon must be a single rigid mesh without animations")
    primitives = doc["meshes"][0].get("primitives", [])
    if len(primitives) != 1 or "POSITION" not in primitives[0].get("attributes", {}):
        raise ValueError("Weapon has no mesh positions")
    accessor = doc["accessors"][primitives[0]["attributes"]["POSITION"]]
    extents = [b - a for a, b in zip(accessor["min"], accessor["max"])]
    if not 1.7 < extents[0] < 2.2 or not 0.3 < extents[1] < 0.6:
        raise ValueError("Unexpected weapon dimensions")
    return len(primitives)

def install(root: Path, check_only=False) -> None:
    target = root / RELATIVE
    if target.exists():
        if digest(target) != SHA256:
            raise ValueError("REFUSE_TO_OVERWRITE_UNRECOGNIZED_RIFLE")
        validate(target)
        print("LYRA_WEAPON_PASS existing=1 sha256=" + SHA256)
        return
    if check_only:
        raise ValueError("LYRA_WEAPON_MISSING")
    try:
        import gdown
    except ImportError as exc:
        raise RuntimeError("Install gdown==5.2.0") from exc
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(".glb.partial")
    if partial.exists():
        raise ValueError("REFUSE_TO_OVERWRITE_PARTIAL_RIFLE")
    try:
        got = gdown.download(id=DRIVE_ID, output=str(partial), quiet=False)
        if not got or not partial.is_file():
            raise ValueError("LYRA_WEAPON_DOWNLOAD_FAILED")
        if digest(partial) != SHA256:
            raise ValueError("LYRA_WEAPON_HASH_MISMATCH")
        validate(partial)
        os.replace(partial, target)
        print("LYRA_WEAPON_PASS sha256=" + SHA256)
    finally:
        if partial.exists():
            partial.unlink()

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    install(Path(__file__).resolve().parent.parent, args.check_only)
