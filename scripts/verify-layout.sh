#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
for p in README.md client/project.godot client/scenes/main.tscn client/scenes/operation.tscn client/scripts/main.gd client/scripts/operation.gd client/scripts/game_state.gd scripts/test_pure_rts_contract.py docs/DEAD_SIGNAL_EARTH_GDD_v0.4.md docs/ANIMATION_REQUIREMENTS_RTS.md docs/COMMANDER_ROSTER_AND_ANIMATIONS_v1.md docs/ARCHITECTURE.md docs/ROADMAP.md docs/DECISIONS.md docs/MESHY_PIPELINE.md; do
  [[ -s "$p" ]] || { echo "MISSING_OR_EMPTY: $p"; exit 1; }
done
grep -q 'main.tscn' client/project.godot
grep -q 'extends Control' client/scripts/main.gd
grep -q 'func _issue_move(' client/scripts/operation.gd
! grep -q 'hero_mode' client/scripts/operation.gd
git diff --check
echo "STRUCTURE_CHECK: PASS (not a substitute for Godot/device tests)"
