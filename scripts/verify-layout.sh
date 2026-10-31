#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
for p in README.md client/project.godot client/scenes/main.tscn client/scripts/main.gd docs/ONLINE_WORLD_GDD_v0.1.md docs/ARCHITECTURE.md docs/ROADMAP.md docs/DECISIONS.md docs/ENGINE_AND_MESHY_RESEARCH_2026-11-01.md; do
  [[ -s "$p" ]] || { echo "MISSING_OR_EMPTY: $p"; exit 1; }
done
grep -q 'main.tscn' client/project.godot
grep -q 'extends Control' client/scripts/main.gd
git diff --check
echo "STRUCTURE_CHECK: PASS (does not validate Godot/Android runtime)"
