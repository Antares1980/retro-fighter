import os
import re
import unittest

class TestProjectGodot(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        project_file = os.path.join(os.path.dirname(__file__), "..", "project.godot")
        cls.project_path = os.path.abspath(project_file)
        with open(cls.project_path, "r", encoding="utf-8") as f:
            cls.content = f.read()

    def test_viewport_dimensions(self):
        self.assertRegex(self.content, r'window/size/viewport_width\s*=\s*384')
        self.assertRegex(self.content, r'window/size/viewport_height\s*=\s*224')

    def test_window_overrides(self):
        self.assertRegex(self.content, r'window/size/window_width_override\s*=\s*1152')
        self.assertRegex(self.content, r'window/size/window_height_override\s*=\s*672')

    def test_stretch_mode_and_aspect(self):
        self.assertRegex(self.content, r'window/stretch/mode\s*=\s*"viewport"')
        self.assertRegex(self.content, r'window/stretch/aspect\s*=\s*"keep"')

    def test_rendering_texture_filter(self):
        self.assertRegex(self.content, r'textures/canvas_textures/default_texture_filter\s*=\s*0')

    def test_physics_ticks_rate(self):
        self.assertRegex(self.content, r'common/physics_ticks_per_second\s*=\s*60')

    def test_main_scene_path(self):
        self.assertRegex(self.content, r'run/main_scene\s*=\s*"res://scenes/Main.tscn"')

    def test_physics_layers(self):
        self.assertRegex(self.content, r'2d_physics/layer_1\s*=\s*"WorldFloor"')
        self.assertRegex(self.content, r'2d_physics/layer_2\s*=\s*"FighterBody"')
        self.assertRegex(self.content, r'2d_physics/layer_3\s*=\s*"StageWall"')
        self.assertRegex(self.content, r'2d_physics/layer_4\s*=\s*"P1_Hurtbox"')
        self.assertRegex(self.content, r'2d_physics/layer_5\s*=\s*"P1_Hitbox"')
        self.assertRegex(self.content, r'2d_physics/layer_6\s*=\s*"P2_Hurtbox"')
        self.assertRegex(self.content, r'2d_physics/layer_7\s*=\s*"P2_Hitbox"')

    def test_input_actions_defined(self):
        expected_actions = [
            "p1_left", "p1_right", "p1_up", "p1_down", "p1_punch", "p1_kick", "p1_block",
            "p2_left", "p2_right", "p2_up", "p2_down", "p2_punch", "p2_kick", "p2_block",
            "toggle_p2_dummy"
        ]
        for action in expected_actions:
            self.assertIn(f"{action}={{", self.content)

    def test_p1_keys(self):
        # A: 65, D: 68, W: 87, S: 83, J: 74, K: 75, L: 76
        key_map = {
            "p1_left": 65,
            "p1_right": 68,
            "p1_up": 87,
            "p1_down": 83,
            "p1_punch": 74,
            "p1_kick": 75,
            "p1_block": 76,
        }
        for action, keycode in key_map.items():
            pattern = rf'{action}=\{{[^}}]*"physical_keycode":\s*{keycode}'
            self.assertRegex(self.content, pattern, f"Action {action} should have physical_keycode {keycode}")

    def test_p2_keys_and_fallbacks(self):
        # LEFT: 4194319, RIGHT: 4194321, UP: 4194320, DOWN: 4194322
        # PUNCH: KP_1 (4194439) & COMMA (44)
        # KICK: KP_2 (4194440) & PERIOD (46)
        # BLOCK: KP_0 (4194438) & SLASH (47)
        self.assertRegex(self.content, r'p2_left=\{[^}]*"physical_keycode":\s*4194319')
        self.assertRegex(self.content, r'p2_right=\{[^}]*"physical_keycode":\s*4194321')
        self.assertRegex(self.content, r'p2_up=\{[^}]*"physical_keycode":\s*4194320')
        self.assertRegex(self.content, r'p2_down=\{[^}]*"physical_keycode":\s*4194322')

        # Fallbacks
        self.assertRegex(self.content, r'p2_punch=\{[^}]*"physical_keycode":\s*4194439[^}]*"physical_keycode":\s*44')
        self.assertRegex(self.content, r'p2_kick=\{[^}]*"physical_keycode":\s*4194440[^}]*"physical_keycode":\s*46')
        self.assertRegex(self.content, r'p2_block=\{[^}]*"physical_keycode":\s*4194438[^}]*"physical_keycode":\s*47')

    def test_dummy_toggle_key(self):
        # F1: 4194332
        self.assertRegex(self.content, r'toggle_p2_dummy=\{[^}]*"physical_keycode":\s*4194332')

if __name__ == "__main__":
    unittest.main()
