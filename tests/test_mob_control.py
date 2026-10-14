import os
import unittest

class TestMobControl(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cls.scenes_dir = os.path.join(base_dir, "scenes", "mob_control")
        cls.scripts_dir = os.path.join(base_dir, "scripts", "mob_control")
        cls.tests_dir = os.path.join(base_dir, "tests")

        cls.main_scene_path = os.path.join(cls.scenes_dir, "MobControlMain.tscn")
        cls.cannon_scene_path = os.path.join(cls.scenes_dir, "Cannon3D.tscn")
        cls.mob_scene_path = os.path.join(cls.scenes_dir, "MobUnit3D.tscn")
        cls.gate_scene_path = os.path.join(cls.scenes_dir, "MultiplierGate3D.tscn")
        cls.giant_scene_path = os.path.join(cls.scenes_dir, "GiantEnemy3D.tscn")

        cls.main_script_path = os.path.join(cls.scripts_dir, "MobControlMain.gd")
        cls.cannon_script_path = os.path.join(cls.scripts_dir, "Cannon3D.gd")
        cls.mob_script_path = os.path.join(cls.scripts_dir, "MobUnit3D.gd")
        cls.gate_script_path = os.path.join(cls.scripts_dir, "MultiplierGate3D.gd")
        cls.giant_script_path = os.path.join(cls.scripts_dir, "GiantEnemy3D.gd")

        cls.test_gd_path = os.path.join(cls.tests_dir, "test_mob_control.gd")
        cls.test_runner_path = os.path.join(cls.tests_dir, "test_runner.gd")

        with open(cls.main_scene_path, "r", encoding="utf-8") as f:
            cls.main_scene = f.read()
        with open(cls.cannon_scene_path, "r", encoding="utf-8") as f:
            cls.cannon_scene = f.read()
        with open(cls.mob_scene_path, "r", encoding="utf-8") as f:
            cls.mob_scene = f.read()
        with open(cls.gate_scene_path, "r", encoding="utf-8") as f:
            cls.gate_scene = f.read()
        with open(cls.giant_scene_path, "r", encoding="utf-8") as f:
            cls.giant_scene = f.read()

        with open(cls.main_script_path, "r", encoding="utf-8") as f:
            cls.main_script = f.read()
        with open(cls.cannon_script_path, "r", encoding="utf-8") as f:
            cls.cannon_script = f.read()
        with open(cls.mob_script_path, "r", encoding="utf-8") as f:
            cls.mob_script = f.read()
        with open(cls.gate_script_path, "r", encoding="utf-8") as f:
            cls.gate_script = f.read()
        with open(cls.giant_script_path, "r", encoding="utf-8") as f:
            cls.giant_script = f.read()
        with open(cls.test_runner_path, "r", encoding="utf-8") as f:
            cls.test_runner = f.read()
        with open(cls.test_gd_path, "r", encoding="utf-8") as f:
            cls.test_gd = f.read()

    def test_files_exist(self):
        self.assertTrue(os.path.isfile(self.main_scene_path), "MobControlMain.tscn must exist")
        self.assertTrue(os.path.isfile(self.cannon_scene_path), "Cannon3D.tscn must exist")
        self.assertTrue(os.path.isfile(self.mob_scene_path), "MobUnit3D.tscn must exist")
        self.assertTrue(os.path.isfile(self.gate_scene_path), "MultiplierGate3D.tscn must exist")
        self.assertTrue(os.path.isfile(self.giant_scene_path), "GiantEnemy3D.tscn must exist")

        self.assertTrue(os.path.isfile(self.main_script_path), "MobControlMain.gd must exist")
        self.assertTrue(os.path.isfile(self.cannon_script_path), "Cannon3D.gd must exist")
        self.assertTrue(os.path.isfile(self.mob_script_path), "MobUnit3D.gd must exist")
        self.assertTrue(os.path.isfile(self.gate_script_path), "MultiplierGate3D.gd must exist")
        self.assertTrue(os.path.isfile(self.giant_script_path), "GiantEnemy3D.gd must exist")
        self.assertTrue(os.path.isfile(self.test_gd_path), "test_mob_control.gd must exist")

    def test_main_scene_structure(self):
        self.assertIn('node name="MobControlMain" type="Node3D"', self.main_scene)
        self.assertIn('node name="Camera3D" type="Camera3D"', self.main_scene)
        self.assertIn('node name="DirectionalLight3D" type="DirectionalLight3D"', self.main_scene)
        self.assertIn('node name="Road" type="MeshInstance3D"', self.main_scene)
        self.assertIn('node name="Cannon"', self.main_scene)
        self.assertIn('node name="GiantEnemy"', self.main_scene)
        self.assertIn('node name="Gates" type="Node3D"', self.main_scene)
        self.assertIn('gate_left_1', self.main_scene)
        self.assertIn('gate_right_1', self.main_scene)
        self.assertIn('gate_left_2', self.main_scene)
        self.assertIn('gate_right_2', self.main_scene)
        self.assertIn('VictoryBanner', self.main_scene)
        self.assertIn('DefeatBanner', self.main_scene)
        self.assertIn('ControlsHint', self.main_scene)
        self.assertIn('A/D or ARROWS: STEER | HOLD J or SPACE: FIRE | ESC: MENU', self.main_scene)

    def test_giant_scene_structure(self):
        self.assertIn('node name="GiantEnemy3D" type="Area3D"', self.giant_scene)
        self.assertIn('size = Vector3(9.5, 2.5, 2.5)', self.giant_scene)
        self.assertIn('node name="Label3D" type="Label3D"', self.giant_scene)
        self.assertIn('node name="HealthBar"', self.giant_scene)

    def test_cannon_scene_structure(self):
        self.assertIn('node name="Cannon3D" type="Node3D"', self.cannon_scene)
        self.assertIn('node name="Muzzle" type="Marker3D"', self.cannon_scene)

    def test_gate_scene_structure(self):
        self.assertIn('node name="MultiplierGate3D" type="Area3D"', self.gate_scene)
        self.assertIn('size = Vector3(4, 2, 0.6)', self.gate_scene)
        self.assertIn('node name="Label3D" type="Label3D"', self.gate_scene)

    def test_mob_scene_structure(self):
        self.assertIn('node name="MobUnit3D" type="Area3D"', self.mob_scene)
        self.assertIn('CapsuleShape3D', self.mob_scene)
        self.assertIn('CapsuleMesh', self.mob_scene)

    def test_scripts_contract(self):
        self.assertIn('class_name MobControlMain', self.main_script)
        self.assertIn('enum GameState { PLAYING, VICTORY, DEFEAT }', self.main_script)
        self.assertIn('const MAX_MOBS: int = 300', self.main_script)
        self.assertIn('func step(delta: float)', self.main_script)
        self.assertIn('func flush_pending_spawns()', self.main_script)
        self.assertIn('func cleanup_all_mobs()', self.main_script)
        self.assertIn('func reset_stage()', self.main_script)
        self.assertIn('func return_to_menu()', self.main_script)
        self.assertIn('signal return_to_menu_requested', self.main_script)
        self.assertIn('controls_hint', self.main_script)

        self.assertIn('class_name Cannon3D', self.cannon_script)
        self.assertIn('var move_input: float', self.cannon_script)
        self.assertIn('var fire_held: bool', self.cannon_script)
        self.assertIn('const FIRE_INTERVAL: float = 0.14', self.cannon_script)
        self.assertIn('signal shoot_requested', self.cannon_script)
        self.assertIn('mc_fire', self.cannon_script)

        self.assertIn('class_name MobUnit3D', self.mob_script)
        self.assertIn('var is_consumed: bool = false', self.mob_script)
        self.assertIn('var passed_gates: Dictionary = {}', self.mob_script)

        self.assertIn('class_name MultiplierGate3D', self.gate_script)
        self.assertIn('func calculate_clones() -> int', self.gate_script)

        self.assertIn('class_name GiantEnemy3D', self.giant_script)
        self.assertIn('var hp: int = 150', self.giant_script)
        self.assertIn('func take_damage(', self.giant_script)
        self.assertIn('func reset(', self.giant_script)

    def test_mc_fire_input_contract(self):
        project_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "project.godot")
        with open(project_file, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("mc_fire={", content)
        self.assertRegex(content, r'mc_fire=\{[^}]*"physical_keycode":\s*32')

    def test_runner_registered(self):
        self.assertIn('tests/test_mob_control.gd', self.test_runner)
        self.assertIn('success_mob_control', self.test_runner)

    @staticmethod
    def _find_godot_binary():
        import shutil
        for name in ["godot", "godot.exe", "godot4", "godot4.exe"]:
            cmd = shutil.which(name)
            if cmd:
                return cmd
        local_app_data = os.environ.get("LOCALAPPDATA", "")
        if local_app_data:
            winget_dir = os.path.join(local_app_data, "Microsoft", "WinGet", "Packages")
            if os.path.isdir(winget_dir):
                for root, _, files in os.walk(winget_dir):
                    for f in files:
                        if "godot" in f.lower() and f.endswith(".exe") and "console" in f.lower():
                            return os.path.join(root, f)
        return None

    def test_cold_cache_script_compilation_contract(self):
        """GWT 1: Ensure MobControlMain.gd has no bare class dependencies and compiles cold without global class cache."""
        import re
        import subprocess

        # 1. Preload constants present
        self.assertIn('const Cannon3DScript = preload("res://scripts/mob_control/Cannon3D.gd")', self.main_script)
        self.assertIn('const GiantEnemy3DScript = preload("res://scripts/mob_control/GiantEnemy3D.gd")', self.main_script)
        self.assertIn('const MultiplierGate3DScript = preload("res://scripts/mob_control/MultiplierGate3D.gd")', self.main_script)
        self.assertIn('const MobUnit3DScript = preload("res://scripts/mob_control/MobUnit3D.gd")', self.main_script)

        # 2. No bare class name references in MobControlMain.gd
        bare_patterns = [
            r'Array\[\s*(MobUnit3D|Cannon3D|GiantEnemy3D|MultiplierGate3D)\s*\]',
            r':\s*(MobUnit3D|Cannon3D|GiantEnemy3D|MultiplierGate3D)\b',
            r'as\s+(MobUnit3D|Cannon3D|GiantEnemy3D|MultiplierGate3D)\b',
            r'is\s+(MobUnit3D|Cannon3D|GiantEnemy3D|MultiplierGate3D)\b',
            r'->\s*(MobUnit3D|Cannon3D|GiantEnemy3D|MultiplierGate3D)\b',
        ]
        for pat in bare_patterns:
            matches = re.findall(pat, self.main_script)
            self.assertEqual(matches, [], f"Bare class name found matching {pat}: {matches}")

        # 3. Dynamic cold-compilation check if Godot binary is available
        godot_bin = self._find_godot_binary()
        if godot_bin:
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            cache_file = os.path.join(base_dir, ".godot", "global_script_class_cache.cfg")
            bak_file = cache_file + ".bak_test"
            cache_existed = os.path.exists(cache_file)
            try:
                if cache_existed:
                    os.rename(cache_file, bak_file)
                proc = subprocess.run(
                    [godot_bin, "--headless", "--check-only", "--script", "res://scripts/mob_control/MobControlMain.gd"],
                    cwd=base_dir,
                    capture_output=True,
                    text=True
                )
                self.assertEqual(proc.returncode, 0, f"check-only failed: {proc.stderr or proc.stdout}")
                self.assertNotIn("Parse Error", proc.stderr + proc.stdout)
                self.assertNotIn("Could not find type", proc.stderr + proc.stdout)
            finally:
                if cache_existed and os.path.exists(bak_file):
                    os.rename(bak_file, cache_file)

    def test_cannon_raw_key_fallbacks(self):
        """GWT 2, 3, 4: Cannon3D polls raw keys KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_J, KEY_SPACE, but not KEY_ESCAPE."""
        self.assertIn("KEY_A", self.cannon_script)
        self.assertIn("KEY_D", self.cannon_script)
        self.assertIn("KEY_LEFT", self.cannon_script)
        self.assertIn("KEY_RIGHT", self.cannon_script)
        self.assertIn("KEY_J", self.cannon_script)
        self.assertIn("KEY_SPACE", self.cannon_script)
        self.assertNotIn("KEY_ESCAPE", self.cannon_script)

    def test_single_phase_loop_preservation(self):
        """GWT 7, 8: Verify single-phase loop integrity (Giant hp 150, z >= 9.0 defeat) without non-existent entities."""
        self.assertIn("var hp: int = 150", self.giant_script)
        self.assertIn("global_position.z >= 9.0", self.main_script)
        self.assertIn("state = GameState.DEFEAT", self.main_script)
        self.assertIn("state = GameState.VICTORY", self.main_script)
        self.assertNotIn("Yellow Base", self.main_script)
        self.assertNotIn("siege", self.main_script.lower())

    def test_is_live_untyped_and_pruning_contract(self):
        """Issue #41 / GWT 1-4: Verify untyped is_live(mob: Variant), pre-tick pruning, and regression tests."""
        self.assertIn("func is_live(mob: Variant) -> bool:", self.main_script)
        self.assertNotIn("func is_live(mob: MobUnit3D", self.main_script)
        self.assertIn("blue_mobs.remove_at(i)", self.main_script)
        self.assertIn("red_mobs.remove_at(i)", self.main_script)
        self.assertIn("test_scenario_9_freed_instance_safety_and_pruning", self.test_gd)

if __name__ == "__main__":
    unittest.main()

