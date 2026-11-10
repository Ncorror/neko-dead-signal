#!/usr/bin/env python3
"""Validate structural readiness of a Meshy rigged/animated gameplay GLB.

Uses read-only inspect_glb.py; makes no assumptions about motion preset names.
It does NOT claim animation quality, bone correctness, Android performance or FPS.
"""
import argparse
import json
from pathlib import Path
import sys

from inspect_glb import inspect


def validate_inventory(report: dict, min_clips: int = 3) -> list[str]:
    errors = []
    if int(report.get("estimated_total_mesh_triangles", 0)) <= 0:
        errors.append("NO_TRIANGLE_MESH")
    if int(report.get("skin_count", 0)) < 1 or not any(
        int(s.get("joint_count", 0)) > 0 for s in report.get("skins", [])
    ):
        errors.append("MISSING_SKELETON")
    primitives = [p for m in report.get("mesh_primitives", []) for p in m.get("primitives", [])]
    if not any(p.get("has_joint_weights", False) for p in primitives):
        errors.append("MISSING_SKIN_WEIGHTS")
    animations = report.get("animations", [])
    if len(animations) < min_clips:
        errors.append("TOO_FEW_ANIMATION_CLIPS")
    if any(int(a.get("channel_count", 0)) < 1 for a in animations):
        errors.append("EMPTY_ANIMATION_CLIP")
    if int(report.get("material_count", 0)) < 1:
        errors.append("MISSING_MATERIAL")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("glb", type=Path)
    parser.add_argument("--min-clips", type=int, default=3)
    args = parser.parse_args()
    if args.min_clips < 1:
        parser.error("--min-clips must be >= 1")
    try:
        report = inspect(args.glb)
        errors = validate_inventory(report, args.min_clips)
    except (OSError, ValueError, UnicodeError, TypeError, KeyError) as exc:
        print("GAME_AVATAR_VALIDATION_FAILED: " + str(exc), file=sys.stderr)
        return 1
    print(json.dumps({
        "status": "PASS" if not errors else "FAIL",
        "source_file": report["source_file"],
        "sha256": report["sha256"],
        "triangles": report["estimated_total_mesh_triangles"],
        "skins": report["skins"],
        "animations": report["animations"],
        "material_count": report["material_count"],
        "image_count": report["image_count"],
        "errors": errors,
    }, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
