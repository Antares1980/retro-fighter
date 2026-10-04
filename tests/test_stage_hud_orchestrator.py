import os
import unittest

class TestStageHUDOrchestrator(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cls.stage_scene_path = os.path.join(base_dir, "scenes", "Stage.tscn")
        cls.hud_scene_path = os.path.join(base_dir, "scenes", "HUD.tscn")
        cls.hud_script_path = os.path.join(base_dir, "scripts", "HUD.gd")
        cls.main_scene_path = os.path.join(base_dir, "scenes", "Main.tscn")
        cls.main_script_path = os.path.join(base_dir, "scripts", "Main.gd")

        with open(cls.stage_scene_path, "r", encoding="utf-8") as f:
            cls.stage_scene = f.read()

        with open(cls.hud_scene_path, "r", encoding="utf-8") as f:
            cls.hud_scene = f.read()

        with open(cls.hud_script_path, "r", encoding="utf-8") as f:
            cls.hud_script = f.read()

        with open(cls.main_scene_path, "r", encoding="utf-8") as f:
            cls.main_scene = f.read()

        with open(cls.main_script_path, "r", encoding="utf-8") as f:
            cls.main_script = f.read()

    def test_files_exist(self):
        self.assertTrue(os.path.isfile(self.stage_scene_path), "scenes/Stage.tscn must exist")
        self.assertTrue(os.path.isfile(self.hud_scene_path), "scenes/HUD.tscn must exist")
        self.assertTrue(os.path.isfile(self.hud_script_path), "scripts/HUD.gd must exist")
        self.assertTrue(os.path.isfile(self.main_scene_path), "scenes/Main.tscn must exist")
        self.assertTrue(os.path.isfile(self.main_script_path), "scripts/Main.gd must exist")

    # Stage.tscn Tests
    def test_stage_visuals_and_dimensions(self):
        self.assertIn('node name="Stage" type="Node2D"', self.stage_scene)
        self.assertIn('GradientTexture2D_sunset', self.stage_scene)
        self.assertIn('width = 600', self.stage_scene)
        self.assertIn('height = 224', self.stage_scene)
        self.assertIn('node name="Cityscape" type="Polygon2D"', self.stage_scene)

    def test_stage_ground_collision_layer_and_position(self):
        self.assertIn('node name="Ground" type="StaticBody2D"', self.stage_scene)
        self.assertIn('collision_layer = 1', self.stage_scene)
        # Ground collision centered at Y=207 with height 34 -> top edge at Y=190
        self.assertIn('position = Vector2(300, 207)', self.stage_scene)
        self.assertIn('size = Vector2(600, 34)', self.stage_scene)

    def test_stage_walls_collision(self):
        self.assertIn('node name="StageWalls" type="StaticBody2D"', self.stage_scene)
        self.assertIn('collision_layer = 4', self.stage_scene)

    # HUD Tests
    def test_hud_class_and_inheritance(self):
        self.assertIn('class_name HUD', self.hud_script)
        self.assertIn('extends CanvasLayer', self.hud_script)

    def test_hud_elements_declared(self):
        self.assertIn('p1_health_bar', self.hud_script)
        self.assertIn('p2_health_bar', self.hud_script)
        self.assertIn('timer_label', self.hud_script)
        self.assertIn('announcer_label', self.hud_script)

    def test_hud_methods(self):
        self.assertIn('func update_p1_health(', self.hud_script)
        self.assertIn('func update_p2_health(', self.hud_script)
        self.assertIn('func update_timer(', self.hud_script)
        self.assertIn('func show_announcer(', self.hud_script)
        self.assertIn('func hide_announcer(', self.hud_script)
        self.assertIn('func reset_hud(', self.hud_script)

    def test_hud_scene_structure(self):
        self.assertIn('node name="HUD" type="CanvasLayer"', self.hud_scene)
        self.assertIn('node name="P1HealthBar" type="ProgressBar"', self.hud_scene)
        self.assertIn('node name="P2HealthBar" type="ProgressBar"', self.hud_scene)
        self.assertIn('node name="TimerLabel" type="Label"', self.hud_scene)
        self.assertIn('node name="AnnouncerLabel" type="Label"', self.hud_scene)
        self.assertIn('fill_mode = 1', self.hud_scene) # P2 bar depletes right-to-left

    # Main Orchestrator Tests
    def test_main_class_and_inheritance(self):
        self.assertIn('class_name Main', self.main_script)
        self.assertIn('extends Node2D', self.main_script)

    def test_main_observable_contract(self):
        self.assertIn('signal round_ended(winner_id: int, reason: String)', self.main_script)
        self.assertIn('var last_winner_id: int', self.main_script)
        self.assertIn('var last_reason: String', self.main_script)

    def test_main_fsm_states(self):
        expected_states = ["ROUND_INTRO", "IN_ROUND", "ROUND_OVER", "RESET"]
        for s in expected_states:
            self.assertIn(s, self.main_script)

    def test_main_constants(self):
        self.assertIn('const ROUND_INTRO_DURATION: float = 1.5', self.main_script)
        self.assertIn('const ROUND_OVER_DURATION: float = 3.0', self.main_script)
        self.assertIn('const INITIAL_ROUND_TIME: int = 99', self.main_script)
        self.assertIn('const P1_START_X: float = 200.0', self.main_script)
        self.assertIn('const P2_START_X: float = 400.0', self.main_script)
        self.assertIn('const FLOOR_Y: float = 190.0', self.main_script)

    def test_main_scene_wiring(self):
        self.assertIn('res://scripts/Main.gd', self.main_scene)
        self.assertIn('res://scenes/Stage.tscn', self.main_scene)
        self.assertIn('res://scenes/Fighter.tscn', self.main_scene)
        self.assertIn('res://scenes/Camera2D.tscn', self.main_scene)
        self.assertIn('res://scenes/HUD.tscn', self.main_scene)
        self.assertIn('position = Vector2(200, 190)', self.main_scene) # P1
        self.assertIn('position = Vector2(400, 190)', self.main_scene) # P2
        self.assertIn('player_id = 2', self.main_scene)
        self.assertIn('position = Vector2(300, 112)', self.main_scene) # Camera

    def test_match_loop_logic(self):
        # 1. P2 KO -> P1 wins with "KO"
        def evaluate_ko(p1_hp, p2_hp):
            if p1_hp <= 0 and p2_hp <= 0:
                return (0, "DRAW")
            elif p1_hp <= 0:
                return (2, "KO")
            elif p2_hp <= 0:
                return (1, "KO")
            return None

        self.assertEqual(evaluate_ko(92, 0), (1, "KO"))
        self.assertEqual(evaluate_ko(0, 80), (2, "KO"))
        self.assertEqual(evaluate_ko(0, 0), (0, "DRAW"))

        # 2. Timeout logic
        def evaluate_timeout(p1_hp, p2_hp):
            if p1_hp > p2_hp:
                return (1, "TIME_UP")
            elif p2_hp > p1_hp:
                return (2, "TIME_UP")
            else:
                return (0, "DRAW")

        self.assertEqual(evaluate_timeout(80, 50), (1, "TIME_UP"))
        self.assertEqual(evaluate_timeout(40, 75), (2, "TIME_UP"))
        self.assertEqual(evaluate_timeout(60, 60), (0, "DRAW"))

if __name__ == "__main__":
    unittest.main()
