"""Non-destructive GLB inspector smoke tests (synthetic minimal glTF 2.0)."""
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
INSPECTOR = ROOT / "tools/avatar/inspect_glb.py"


class AvatarInspectorTest(unittest.TestCase):
    def test_minimal_glb_inventory(self):
        scene = {
            "asset": {"version": "2.0"},
            "accessors": [{"count": 3}],
            "meshes": [{
                "name": "female_base_stub",
                "primitives": [{"attributes": {"POSITION": 0}}],
            }],
            "materials": [{"name": "test_material"}],
            "nodes": [{"mesh": 0}],
        }
        payload = json.dumps(scene, separators=(",", ":")).encode()
        payload += b" " * (-len(payload) % 4)
        glb = (struct.pack("<4sII", b"glTF", 2, len(payload) + 20)
               + struct.pack("<II", len(payload), 0x4E4F534A) + payload)
        with tempfile.TemporaryDirectory() as tempdir:
            path = Path(tempdir) / "stub.glb"
            path.write_bytes(glb)
            result = subprocess.run([sys.executable, str(INSPECTOR), str(path)],
                                    capture_output=True, text=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        report = json.loads(result.stdout)
        self.assertEqual(report["sha256"], hashlib.sha256(glb).hexdigest())
        self.assertEqual(report["mesh_count"], 1)
        self.assertEqual(report["estimated_total_mesh_triangles"], 1)
        self.assertEqual(report["material_count"], 1)
        self.assertEqual(report["skin_count"], 0)
        self.assertEqual(report["animations"], [])

    def test_rejects_not_glb_without_writing(self):
        with tempfile.TemporaryDirectory() as tempdir:
            path = Path(tempdir) / "wrong.glb"
            path.write_bytes(b"this is not a binary glb")
            initial = path.read_bytes()
            result = subprocess.run([sys.executable, str(INSPECTOR), str(path)],
                                    capture_output=True, text=True, check=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("GLB_INSPECTION_FAILED", result.stderr)
            self.assertEqual(initial, path.read_bytes())


if __name__ == "__main__":
    unittest.main()
