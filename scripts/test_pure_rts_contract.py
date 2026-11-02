#!/usr/bin/env python3
"""Contract tests for the pure-RTS prototype. Static tests do not replace Godot/device tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent.parent
CLIENT = ROOT / "client"


class PureRTSContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.operation = (CLIENT / "scripts/operation.gd").read_text()
        cls.menu = (CLIENT / "scripts/main.gd").read_text()
        cls.project = (CLIENT / "project.godot").read_text()
        cls.decisions = (ROOT / "docs/DECISIONS.md").read_text()
        cls.gdd = (ROOT / "docs/ONLINE_WORLD_GDD_v0.2.md").read_text()

    def test_only_rts_commands(self):
        self.assertIn("func _select_unit(", self.operation)
        self.assertIn("func _issue_move(", self.operation)
        self.assertIn("func _handle_tap(", self.operation)
        self.assertIn("func _pan_camera(", self.operation)
        self.assertNotIn("hero_mode", self.operation)
        self.assertNotIn("touch_direction", self.operation)
        self.assertNotIn("func _toggle_mode(", self.operation)
        self.assertNotIn("Input.is_key_pressed(KEY_W)", self.operation)
        self.assertNotIn("Режим: герой", self.operation)

    def test_commander_exists_at_start_and_is_selectable(self):
        self.assertIn('hero = _make_unit("StartingOfficer"', self.operation)
        self.assertIn('_select_unit(hero)', self.operation)
        self.assertIn("unit_paths[unit] = planned", self.operation)
        self.assertIn("navigation.get_path(unit.position, target)", self.operation)
        self.assertIn("func _select_all_units(", self.operation)
        self.assertIn("func _stop_selected_units(", self.operation)
        self.assertIn("func _physics_process(delta: float)", self.operation)

    def test_group_orders_and_animation_hook(self):
        self.assertIn("var selected_units: Array[Combatant]", self.operation)
        self.assertIn("func _select_all_units(", self.operation)
        self.assertIn("func _stop_selected_units(", self.operation)
        self.assertIn("navigation.set_blocked_box(", self.operation)
        self.assertIn("RTS_GROUP_ORDER", self.operation)
        self.assertIn("RTS_PERF", self.operation)
        self.assertIn("amina_rigged.glb", self.operation)
        self.assertIn('RTS_AMINA_ANIMATIONS_PENDING', self.operation)
        self.assertIn('"name": "АМИНА"', self.menu)
        self.assertIn('"name": "РЭЙНА"', self.menu)

    def test_android_input_does_not_duplicate_taps(self):
        self.assertIn("pointing/emulate_mouse_from_touch=false", self.project)
        self.assertIn("InputEvent.DEVICE_ID_EMULATION", self.operation)
        self.assertIn("InputEventScreenTouch", self.operation)
        self.assertIn("InputEventScreenDrag", self.operation)
        self.assertIn("InputEventMouseButton", self.operation)

    def test_design_docs_match_game(self):
        self.assertIn("Только RTS", self.decisions)
        self.assertIn("ЧИСТАЯ RTS", self.gdd)
        self.assertNotIn("переключается на прямое управление", self.gdd)
        self.assertNotIn("Управление героем и камерой RTS", self.menu)


if __name__ == "__main__":
    unittest.main()
