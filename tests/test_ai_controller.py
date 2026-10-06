import os
import unittest

class TestAIController(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cls.ai_controller_path = os.path.join(base_dir, "scripts", "AIController.gd")
        cls.main_script_path = os.path.join(base_dir, "scripts", "Main.gd")
        cls.main_scene_path = os.path.join(base_dir, "scenes", "Main.tscn")

        with open(cls.ai_controller_path, "r", encoding="utf-8") as f:
            cls.ai_code = f.read()

        with open(cls.main_script_path, "r", encoding="utf-8") as f:
            cls.main_script = f.read()

        with open(cls.main_scene_path, "r", encoding="utf-8") as f:
            cls.main_scene = f.read()

    def test_file_exists(self):
        self.assertTrue(os.path.isfile(self.ai_controller_path), "scripts/AIController.gd must exist")

    def test_class_declaration_and_inheritance(self):
        self.assertIn("class_name AIController", self.ai_code)
        self.assertIn("extends Node", self.ai_code)

    def test_timing_constants_and_properties(self):
        self.assertIn("DEFAULT_DECISION_INTERVAL: float = 0.35", self.ai_code)
        self.assertIn("DEFAULT_JITTER_RANGE: float = 0.05", self.ai_code)
        self.assertIn("FAR_THRESHOLD: float = 85.0", self.ai_code)
        self.assertIn("CLOSE_THRESHOLD: float = 45.0", self.ai_code)
        self.assertIn("var decision_interval: float", self.ai_code)
        self.assertIn("var jitter_range: float", self.ai_code)
        self.assertIn("var decision_timer: float", self.ai_code)
        self.assertIn("var rng: RandomNumberGenerator", self.ai_code)

    def test_essential_methods_declared(self):
        self.assertIn("func setup(", self.ai_code)
        self.assertIn("func reset(", self.ai_code)
        self.assertIn("func step(", self.ai_code)
        self.assertIn("func decide(", self.ai_code)
        self.assertIn("func _is_guarded(", self.ai_code)
        self.assertIn("func _zero_inputs(", self.ai_code)

    def test_guard_states_checked(self):
        self.assertIn("FighterScript.State.HIT_STUN", self.ai_code)
        self.assertIn("FighterScript.State.BLOCK_STUN", self.ai_code)
        self.assertIn("FighterScript.State.KNOCKDOWN", self.ai_code)
        self.assertIn("FighterScript.State.DEAD", self.ai_code)
        self.assertIn("inputs_frozen", self.ai_code)
        self.assertIn("is_dummy", self.ai_code)

    def test_decision_logic_thresholds(self):
        # Far band (> 85.0)
        self.assertIn("dist > FAR_THRESHOLD", self.ai_code)
        self.assertIn("fighter.input_dir = dir_to_opponent", self.ai_code)

        # Close band (< 45.0)
        self.assertIn("dist < CLOSE_THRESHOLD", self.ai_code)
        self.assertIn("roll < 0.40", self.ai_code) # Punch
        self.assertIn("roll < 0.70", self.ai_code) # Kick
        self.assertIn("roll < 0.90", self.ai_code) # Block

        # Mid band (45.0 <= dist <= 85.0)
        self.assertIn("roll < 0.60", self.ai_code) # Advance
        self.assertIn("-dir_to_opponent", self.ai_code) # Step back

    def test_defensive_colocated_fallback(self):
        self.assertIn("-float(fighter.facing)", self.ai_code)

    def test_main_orchestrator_integration(self):
        self.assertIn("AIControllerScript", self.main_script)
        self.assertIn("ai_controller", self.main_script)
        self.assertIn("ai_controller.reset()", self.main_script)
        self.assertIn("ai_controller.setup(p2, p1)", self.main_script)

    def test_main_scene_p2_cpu_flag(self):
        self.assertIn('node name="P2"', self.main_scene)
        self.assertIn("is_cpu = true", self.main_scene)

if __name__ == "__main__":
    unittest.main()
