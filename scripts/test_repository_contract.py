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
        self.assertIn('config/version="0.0.28"', project)
        self.assertIn('package/unique_name="com.ncorror.neko.deadsignal"', export)
        self.assertIn('package/name="NEKO DEAD SIGNAL"', export)
        self.assertIn('version/code=28', export)
        self.assertIn('export_path="build/NEKO_DEAD_SIGNAL-debug.apk"', export)
        self.assertIn('_label("NEKO: DEAD SIGNAL",', menu)
        self.assertIn('"project": "NEKO: DEAD SIGNAL"', diagnostics)
        self.assertIn('NEKO DEAD SIGNAL DEBUG', diagnostics)
        self.assertIn('NEKO_DEAD_SIGNAL-0.0.28-debug.apk', workflow)
        self.assertIn('neko-dead-signal-debug-', workflow)

    def test_relative_markdown_links_exist(self):
        # Optional proof for a partial local checkout; normal CI checks real files.
        manifest = os.environ.get('REINA_SOURCE_TREE_MANIFEST')
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
