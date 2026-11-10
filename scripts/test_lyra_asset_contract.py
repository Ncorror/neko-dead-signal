"""Structural contract tests for Lyra Voss asset pipeline; Godot tests actual rig."""
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent

class LyraAssetTests(unittest.TestCase):
    def test_pinned_asset(self):
        spec = importlib.util.spec_from_file_location(
            "installer", ROOT / "scripts/install_lyra_voss.py")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        self.assertEqual(mod.SHA256, "2cdfae99b4dda6c69b608cdb3d46875d9003a7208e89e5683a2021592f9bf14e")
        self.assertIn("Archery_Aim_with_Lateral_Scan", mod.REQUIRED)
    def test_no_fake_idle_and_no_amina_replacement(self):
        s = (ROOT / "client/scripts/lyra_voss_animations.gd").read_text()
        self.assertIn('"Walking"', s)
        self.assertIn('"Running"', s)
        self.assertIn('hold_ready_pose', s)
        self.assertNotIn('"Idle",', s)
        menu = (ROOT / "client/scripts/commander_3d_preview.gd").read_text()
        self.assertIn("amina/preview.glb", menu)
        self.assertIn("lyra_voss/rigged.glb", menu)

    def test_lyra_rifle_source(self):
        path = ROOT / "scripts/install_lyra_voss_weapon.py"
        spec = importlib.util.spec_from_file_location("weapon_installer", path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertEqual(module.SHA256, "fa324f0e3fdd5fc9e3447146c0322bd8b5422098275ddf1fe51202897bede47e")
        self.assertEqual(module.SIZE, 8373476)
        controller = (ROOT / "client/scripts/lyra_voss_animations.gd").read_text()
        self.assertIn("BoneAttachment3D.new()", controller)
        self.assertIn("LyraRifleBackMount", controller)
        self.assertIn("reset_bone_poses()", controller)
