"""Cheap repository checks. They do not replace gameplay or browser tests."""
from pathlib import Path
import json
import os
import re
import subprocess
import unittest

ROOT = Path(__file__).resolve().parent.parent


class RepositoryContract(unittest.TestCase):
    def test_release_metadata_agrees(self):
        project = (ROOT / 'client/project.godot').read_text()
        version = re.search(r'config/version="([^"]+)"', project)[1]
        export = (ROOT / 'client/export_presets.cfg').read_text()
        book = (ROOT / 'docs/DEVICE_TEST_RTS_008.html').read_text()
        workflow = (ROOT / '.github/workflows/vienna-rts-android.yml').read_text()
        self.assertIn('version/name="' + version + '"', export)
        self.assertIn('NEKO_DEAD_SIGNAL-' + version + '-debug.apk', workflow)
        self.assertNotIn('cp docs/DEVICE_TEST_RTS_008.html', workflow)
        first = re.search(r'<select id="tested-version"><option value="([^"]+)"', book)[1]
        self.assertIn('REINA_RTS-' + first + '-debug.apk', book)
        versions = re.search(r'const versions=\[(.*?)\];', book)[1]
        self.assertEqual(re.findall(r"'([^']+)'", versions)[-1], first)
        cases = re.findall(r'<section class="case" data-id="([^"]+)"', book)
        self.assertEqual(len(cases), len(set(cases)), 'duplicate testbook case IDs')
        self.assertEqual(len(cases), 36)

    def test_neko_branding_identity(self):
        project = (ROOT / 'client/project.godot').read_text()
        export = (ROOT / 'client/export_presets.cfg').read_text()
        menu = (ROOT / 'client/scripts/main.gd').read_text()
        diagnostics = (ROOT / 'client/scripts/rts_diagnostics.gd').read_text()
        workflow = (ROOT / '.github/workflows/vienna-rts-android.yml').read_text()
        self.assertIn('config/name="NEKO: DEAD SIGNAL"', project)
        version = re.search(r'config/version="([^"]+)"', project)[1]
        match = re.fullmatch(r'0\.0\.(\d+)', version)
        self.assertIsNotNone(match, version)
        build_code = int(match[1])
        self.assertGreaterEqual(build_code, 29)
        self.assertIn('package/unique_name="com.ncorror.neko.deadsignal"', export)
        self.assertIn('package/name="NEKO DEAD SIGNAL"', export)
        self.assertIn('version/code=' + str(build_code), export)
        self.assertIn('version/name="' + version + '"', export)
        self.assertIn('export_path="build/NEKO_DEAD_SIGNAL-debug.apk"', export)
        self.assertIn('_label("NEKO: DEAD SIGNAL",', menu)
        self.assertIn('"project": "NEKO: DEAD SIGNAL"', diagnostics)
        self.assertIn('NEKO DEAD SIGNAL DEBUG', diagnostics)
        self.assertIn('NEKO_DEAD_SIGNAL-' + version + '-debug.apk', workflow)
        self.assertIn('neko-dead-signal-debug-', workflow)

    def test_runtime_brand_and_deployment_repo(self):
        menu = (ROOT / 'client/scripts/main.gd').read_text()
        operation = (ROOT / 'client/scripts/operation.gd').read_text()
        dialogs = (ROOT / 'client/scripts/rts_diagnostics_ui.gd').read_text()
        server = (ROOT / 'server/control_api.py').read_text()
        deploy = (ROOT / 'ops/vienna/deploy-one-shot-termux.sh').read_text()
        runner = (ROOT / 'ops/vienna/install-runner.sh').read_text()
        for source in (menu, operation, dialogs):
            self.assertIn('NEKO: DEAD SIGNAL', source)
            self.assertNotIn('REINA: DEAD SIGNAL', source)
        self.assertNotIn('REINA SYSTEMS', menu)
        self.assertIn('"service": "neko-dead-signal"', server)
        self.assertIn('REPO="Ncorror/neko-dead-signal"', deploy)
        self.assertIn('https://github.com/Ncorror/neko-dead-signal', runner)

    def test_relative_markdown_links_exist(self):
        # Optional proof for a partial local checkout; normal CI checks real files.
        manifest = os.environ.get('NEKO_SOURCE_TREE_MANIFEST') or os.environ.get('REINA_SOURCE_TREE_MANIFEST')
        remote = set()
        if manifest:
            remote = {entry['path'] for entry in json.loads(Path(manifest).read_text())['tree'] if entry['type'] == 'blob'}
        for source in ROOT.rglob('*.md'):
            if any(part in {'.git', '.godot', 'node_modules'} for part in source.parts):
                continue
            for link in re.findall(r'\[[^\]]*\]\(([^)\n]+)\)', source.read_text()):
                target = link.strip('<>').split('#', 1)[0]
                if not target or '://' in target or target.startswith(('mailto:', '/')):
                    continue
                resolved = (source.parent / target).resolve()
                remote_art = (resolved.suffix.lower() in {'.png', '.jpg', '.jpeg', '.glb'}
                              and str(resolved.relative_to(ROOT)) in remote)
                self.assertTrue(resolved.exists() or remote_art, str(source.relative_to(ROOT)) + ': ' + target)

    def test_earth_story_replaces_legacy_cosmic_design(self):
        menu = (ROOT / 'client/scripts/main.gd').read_text()
        visuals = (ROOT / 'client/scripts/command_visuals.gd').read_text()
        gdd = ROOT / 'docs/DEAD_SIGNAL_EARTH_GDD_v0.4.md'
        self.assertTrue(gdd.is_file())
        self.assertIn('Ночи Тишины', gdd.read_text())
        self.assertIn('"name": "NEKO"', menu)
        self.assertIn('"name": "КОНТУР"', menu)
        self.assertIn('«НОЧНАЯ ЛИНИЯ»', menu)
        self.assertIn('ЗЕМЛЯ · СЕВЕРНЫЙ ПОЯС', menu)
        self.assertIn('func _draw_earth()', visuals)
        for obsolete in ('НЕИЗВЕСТНАЯ ПЛАНЕТА', 'НЕИЗВЕДАННАЯ ПЛАНЕТА',
                         'ЭКСПЕДИЦИОННЫЙ ФЛОТ', 'ЗВЁЗДНЫЙ КОНКЛАВ',
                         '"name": "СААРИ"'):
            self.assertNotIn(obsolete, menu)
        for path in (
            'docs/ONLINE_WORLD_GDD_v0.1.md',
            'docs/ONLINE_WORLD_GDD_v0.2.md',
            'docs/DEAD_SIGNAL_MMORTS_GDD_v0.3.md',
            'docs/FIFTH_CHARACTER_EX_PIRATE_TANK_CONCEPT_2026-11-06.md',
        ):
            self.assertFalse((ROOT / path).exists(), path)
        game_state = (ROOT / 'client/scripts/game_state.gd').read_text()
        self.assertIn('faction_index: int = 0', game_state)
        self.assertIn('world/progress-v1.json', game_state)
        self.assertIn('surface/sector01-v1.json', game_state)

    def test_no_reactivated_space_lore(self):
        obsolete = (
            "docs/AUDIT_PURE_RTS_2026-11-02.md",
            "docs/AUDIT_SUMMARY_0.0.32.md",
            "docs/NEKO_032_ACTION_ITEMS.md",
            "docs/PRODUCTION_MESHY_FEMALE_BASE_V1_2026-11-06.md",
            "docs/PRODUCTION_MESHY_FEMALE_BASE_V2_2026-11-06.md",
            "docs/MMORTS_HERO_ACTIVE_SKILLS_V02_2026-11-06.md",
            "docs/MMORTS_FIVE_CLASSES_AND_HEROINES_v0.1.md",
            "docs/REINA_TACTICAL_BARRIER_DUAL_MODE_DESIGN_v0.1.md",
            "docs/REINA_TARGETED_SHIELD_DESIGN_v0.1.md",
            "docs/MIRA_KADE_HEALER_MASS_HEAL_DESIGN_v0.1.md",
            "docs/AMINA_ASSAULT_DPS_GRENADE_DESIGN_v0.1.md",
            "docs/RTS_SQUAD_ANDROID_TESTBOOK_v0.1.md",
            "docs/PRODUCTION_AND_MAP_010.md",
            "docs/ANDROID_004_CAMERA_SELECTION_PORTRAITS.md",
            "docs/ANDROID_PREVIEW_AND_MOVEMENT_007.md",
            "docs/AMINA_STATIC_LANDING_005.md",
            "docs/ENGINE_AND_MESHY_RESEARCH_2026-11-01.md",
            "docs/AI_3D_MESHY_VS_TRIPO_DECISION_2026-11-06.md",
            "docs/REINA_CHANTER_AION_COMPARISON_2026-11-06.md",
            "docs/RTS_DEBUG_DIAGNOSTICS_AND_3D_MENU.md",
            "docs/SURFACE_SECTOR_01_ISOMETRIC_ENVIRONMENT_PLAN_2026-11-06.md",
        )
        for name in obsolete:
            self.assertFalse((ROOT / name).exists(), "obsolete guide resurrected: " + name)
        forbidden_in_game = ("Саари", "НЕИЗВЕДАННАЯ ПЛАНЕТА", "ORBITAL COMMAND", "НА КОРАБЛЬ")
        for path in (ROOT / "client/scripts").glob("*.gd"):
            script = path.read_text()
            for name in forbidden_in_game:
                self.assertNotIn(name, script, str(path))
        for path in (ROOT / "client/tests").glob("*.gd"):
            fixture = path.read_text()
            self.assertNotIn('"Саари"', fixture, str(path))
            self.assertNotIn('Люди — флот «Рэйна»', fixture, str(path))

    def test_all_bash_scripts_parse_without_execution(self):
        for script in sorted(ROOT.glob('ops/**/*.sh')) + sorted(ROOT.glob('scripts/*.sh')):
            result = subprocess.run(['bash', '-n', str(script)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, str(script) + result.stderr)

    def test_no_tracked_signing_keys(self):
        names = subprocess.check_output(['git', 'ls-files', '-z'], cwd=ROOT, text=True).split('\0')
        forbidden = {'.keystore', '.jks', '.p12', '.pem', '.key'}
        for name in names:
            self.assertNotIn(Path(name).suffix.lower(), forbidden, 'signing/secret key tracked: ' + name)


if __name__ == '__main__':
    unittest.main()
