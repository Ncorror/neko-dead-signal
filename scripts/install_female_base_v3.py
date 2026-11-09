#!/usr/bin/env python3
"""Fetch the approved Female Base v3 static GLB from Drive for Android packaging.

The authoring master remains in Drive. This script never silently overwrites a
different local file and verifies the exact approved export before installing it.
Requires gdown==5.2.0. No credentials, no Meshy credits.
"""
from pathlib import Path
import argparse
import hashlib
import os
import sys

DRIVE_ID = "1ALs9BIDp9QgkVh-XoSCgZ8ne0fPYjYBA"
SHA256 = "7cc75e795daea65520520d0547762a6c0e6e18e3432be5a1ded753d999983b6a"
RELATIVE = Path("client/assets/characters/female_base_v3/editor_relaxed.glb")


def checksum(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def install(root, check_only=False):
    dst = root / RELATIVE
    if dst.exists():
        actual = checksum(dst)
        if actual == SHA256:
            print("NEKO_AVATAR_ASSET_PASS existing=" + str(dst))
            return
        raise SystemExit("REFUSING_TO_OVERWRITE_AVATAR_WRONG_HASH " + actual)
    if check_only:
        raise SystemExit("NEKO_AVATAR_ASSET_MISSING")
    try:
        import gdown
    except ImportError as exc:
        raise SystemExit("Install gdown==5.2.0 first; see Android CI workflow") from exc
    dst.parent.mkdir(parents=True, exist_ok=True)
    temporary = dst.with_suffix(".glb.partial")
    if temporary.exists():
        raise SystemExit("REFUSING_TO_OVERWRITE_PARTIAL_ASSET " + str(temporary))
    try:
        result = gdown.download(id=DRIVE_ID, output=str(temporary), quiet=False)
        if not result or not temporary.is_file():
            raise SystemExit("NEKO_AVATAR_DOWNLOAD_FAILED")
        actual = checksum(temporary)
        if actual != SHA256:
            raise SystemExit("NEKO_AVATAR_SHA256_MISMATCH " + actual)
        with temporary.open("rb") as stream:
            if stream.read(4) != b"glTF":
                raise SystemExit("NEKO_AVATAR_BAD_GLB_MAGIC")
        os.replace(temporary, dst)
        print("NEKO_AVATAR_ASSET_PASS sha256=" + actual)
    finally:
        if temporary.exists():
            temporary.unlink()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-only", action="store_true")
    opts = parser.parse_args()
    install(Path(__file__).resolve().parent.parent, opts.check_only)
