"""Static integration contracts; runtime GLB loading is tested in Godot CI."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent.parent


class AvatarIntegrationContract(unittest.TestCase):
    def test_menu_and_editor_navigation(self):
        menu = (ROOT / "client/scripts/main.gd").read_text()
        editor = (ROOT / "client/scripts/character_creator.gd").read_text()
        self.assertIn('res://scenes/character_creator.tscn', menu)
        self.assertIn('res://scenes/main.tscn', editor)
        self.assertIn('func _set_mode(', editor)
        self.assertIn("inventory_panel", editor)

    def test_asset_fetch_is_pinned_and_nondestructive(self):
        downloader = (ROOT / "scripts/install_female_base_v3.py").read_text()
        self.assertIn("7cc75e795daea65520520d0547762a6c0e6e18e3432be5a1ded753d999983b6a", downloader)
        self.assertIn("REFUSING_TO_OVERWRITE_AVATAR_WRONG_HASH", downloader)
        self.assertIn("os.replace(temporary, dst)", downloader)
        preview = (ROOT / "client/scripts/avatar_static_preview.gd").read_text()
        self.assertIn("res://assets/characters/female_base_v3/editor_relaxed.glb", preview)

    def test_separate_profile_and_runtime_smoke(self):
        profile = (ROOT / "client/scripts/character_profile_store.gd").read_text()
        self.assertIn("user://characters/profiles-v1.json", profile)
        self.assertNotIn("commander_selection.cfg", profile)
        self.assertNotIn("world/progress-v1.json", profile)
        workflow = (ROOT / ".github/workflows/vienna-rts-android.yml").read_text()
        self.assertIn("scripts/install_female_base_v3.py", workflow)
        self.assertIn("res://tests/test_character_creator.tscn", workflow)
        self.assertIn("NEKO_AVATAR_EDITOR_TEST_PASS", workflow)
