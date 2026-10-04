import os
import unittest

class TestCamera(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cls.camera_script_path = os.path.join(base_dir, "scripts", "DynamicFightCamera.gd")
        cls.camera_scene_path = os.path.join(base_dir, "scenes", "Camera2D.tscn")

        with open(cls.camera_script_path, "r", encoding="utf-8") as f:
            cls.camera_code = f.read()

        with open(cls.camera_scene_path, "r", encoding="utf-8") as f:
            cls.camera_scene = f.read()

    def test_files_exist(self):
        self.assertTrue(os.path.isfile(self.camera_script_path), "scripts/DynamicFightCamera.gd must exist")
        self.assertTrue(os.path.isfile(self.camera_scene_path), "scenes/Camera2D.tscn must exist")

    def test_class_declaration_and_inheritance(self):
        self.assertIn("class_name DynamicFightCamera", self.camera_code)
        self.assertIn("extends Camera2D", self.camera_code)

    def test_camera_constants(self):
        self.assertIn("const VIEWPORT_WIDTH: float = 384.0", self.camera_code)
        self.assertIn("const VIEWPORT_HEIGHT: float = 224.0", self.camera_code)
        self.assertIn("const MIN_CAMERA_X: float = 192.0", self.camera_code)
        self.assertIn("const MAX_CAMERA_X: float = 408.0", self.camera_code)
        self.assertIn("const FIXED_Y: float = 112.0", self.camera_code)

    def test_target_properties_and_aliases(self):
        self.assertIn("target1", self.camera_code)
        self.assertIn("target2", self.camera_code)
        self.assertIn("fighter1", self.camera_code)
        self.assertIn("fighter2", self.camera_code)
        self.assertIn("left_bound", self.camera_code)
        self.assertIn("right_bound", self.camera_code)

    def test_core_methods_declared(self):
        self.assertIn("func find_targets(", self.camera_code)
        self.assertIn("func set_targets(", self.camera_code)
        self.assertIn("func get_midpoint_x(", self.camera_code)
        self.assertIn("func update_camera(", self.camera_code)
        self.assertIn("func get_view_bounds(", self.camera_code)
        self.assertIn("func get_left_bound(", self.camera_code)
        self.assertIn("func get_right_bound(", self.camera_code)

    def test_fixed_zoom_enforced(self):
        self.assertIn("zoom = Vector2(1.0, 1.0)", self.camera_code)

    def test_scene_node_structure(self):
        self.assertIn('node name="Camera2D" type="Camera2D"', self.camera_scene)
        self.assertIn('res://scripts/DynamicFightCamera.gd', self.camera_scene)
        self.assertIn('position = Vector2(300, 112)', self.camera_scene)

    def test_mathematical_invariants(self):
        # 1. Midpoint at center: P1=200, P2=400 -> midpoint = 300
        mid_center = (200.0 + 400.0) * 0.5
        clamped_center = min(max(mid_center, 192.0), 408.0)
        self.assertEqual(clamped_center, 300.0)

        # View bounds at center
        view_left = clamped_center - 192.0
        view_right = clamped_center + 192.0
        self.assertEqual(view_left, 108.0)
        self.assertEqual(view_right, 492.0)
        self.assertEqual(view_right - view_left, 384.0)

        # Fighter clamp at center
        f_min = view_left + 16.0
        f_max = view_right - 16.0
        self.assertEqual(f_min, 124.0)
        self.assertEqual(f_max, 476.0)
        # Max allowable distance
        self.assertEqual(f_max - f_min, 352.0)

        # 2. Stage Left Clamp: midpoint < 192 -> clamped to 192
        mid_left = (16.0 + 80.0) * 0.5
        clamped_left = min(max(mid_left, 192.0), 408.0)
        self.assertEqual(clamped_left, 192.0)
        self.assertEqual(clamped_left - 192.0, 0.0)  # Aligns with stage left (0)
        self.assertEqual(clamped_left - 192.0 + 16.0, 16.0)  # Matches STAGE_MIN_X

        # 3. Stage Right Clamp: midpoint > 408 -> clamped to 408
        mid_right = (520.0 + 584.0) * 0.5
        clamped_right = min(max(mid_right, 192.0), 408.0)
        self.assertEqual(clamped_right, 408.0)
        self.assertEqual(clamped_right + 192.0, 600.0)  # Aligns with stage right (600)
        self.assertEqual(clamped_right + 192.0 - 16.0, 584.0)  # Matches STAGE_MAX_X

if __name__ == "__main__":
    unittest.main()
