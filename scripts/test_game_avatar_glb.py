"""Unit-test Meshy GLB gameplay contract without pretending to test a real export."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools" / "avatar"))
from validate_game_glb import validate_inventory


def valid_fixture():
    return {
        "estimated_total_mesh_triangles": 10000,
        "skin_count": 1,
        "skins": [{"joint_count": 65}],
        "mesh_primitives": [{"primitives": [{"has_joint_weights": True}]}],
        "animations": [
            {"name": "Idle", "channel_count": 65},
            {"name": "Walk", "channel_count": 65},
            {"name": "Run", "channel_count": 65},
        ],
        "material_count": 1,
    }


class GameAvatarContractTest(unittest.TestCase):
    def test_structurally_rigged_clips(self):
        self.assertEqual(validate_inventory(valid_fixture()), [])

    def test_static_broken_model_is_rejected(self):
        state = valid_fixture()
        state["skin_count"] = 0
        state["skins"] = []
        state["animations"] = []
        state["mesh_primitives"][0]["primitives"][0]["has_joint_weights"] = False
        errors = validate_inventory(state)
        self.assertIn("MISSING_SKELETON", errors)
        self.assertIn("MISSING_SKIN_WEIGHTS", errors)
        self.assertIn("TOO_FEW_ANIMATION_CLIPS", errors)

    def test_empty_animation_track_is_rejected(self):
        state = valid_fixture()
        state["animations"][1]["channel_count"] = 0
        self.assertIn("EMPTY_ANIMATION_CLIP", validate_inventory(state))


if __name__ == "__main__":
    unittest.main()
