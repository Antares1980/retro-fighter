import os
import re
import unittest

class TestMenu(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cls.project_godot_path = os.path.join(base_dir, "project.godot")
        cls.menu_scene_path = os.path.join(base_dir, "scenes", "Menu.tscn")
        cls.menu_script_path = os.path.join(base_dir, "scripts", "Menu.gd")
        cls.main_scene_path = os.path.join(base_dir, "scenes", "Main.tscn")
        cls.main_script_path = os.path.join(base_dir, "scripts", "Main.gd")
        cls.test_menu_script_path = os.path.join(base_dir, "tests", "test_menu.gd")
        cls.test_runner_path = os.path.join(base_dir, "tests", "test_runner.gd")

        with open(cls.project_godot_path, "r", encoding="utf-8") as f:
            cls.project_godot = f.read()

        with open(cls.menu_scene_path, "r", encoding="utf-8") as f:
            cls.menu_scene = f.read()

        with open(cls.menu_script_path, "r", encoding="utf-8") as f:
            cls.menu_script = f.read()

        with open(cls.main_script_path, "r", encoding="utf-8") as f:
            cls.main_script = f.read()

        with open(cls.test_runner_path, "r", encoding="utf-8") as f:
            cls.test_runner = f.read()

    def test_files_exist(self):
        self.assertTrue(os.path.isfile(self.menu_scene_path), "scenes/Menu.tscn must exist")
        self.assertTrue(os.path.isfile(self.menu_script_path), "scripts/Menu.gd must exist")
        self.assertTrue(os.path.isfile(self.test_menu_script_path), "tests/test_menu.gd must exist")

    def test_project_godot_main_scene(self):
        self.assertRegex(self.project_godot, r'run/main_scene\s*=\s*"res://scenes/Menu.tscn"')

    def test_menu_scene_structure(self):
        self.assertIn('node name="Menu" type="Control"', self.menu_scene)
        self.assertIn('res://scripts/Menu.gd', self.menu_scene)
        self.assertIn('node name="VBoxContainer" type="VBoxContainer"', self.menu_scene)
        self.assertIn('node name="RetroFighterButton" type="Button"', self.menu_scene)
        self.assertIn('text = "1. RETRO FIGHTER"', self.menu_scene)
        self.assertIn('node name="ComingSoonButton" type="Button"', self.menu_scene)
        self.assertIn('text = "2. COMING SOON"', self.menu_scene)
        self.assertIn('disabled = true', self.menu_scene)
        self.assertIn('focus_mode = 0', self.menu_scene)
        self.assertIn('node name="QuitButton" type="Button"', self.menu_scene)
        self.assertIn('text = "3. QUIT"', self.menu_scene)
        self.assertIn('node name="BGMPlayer" type="AudioStreamPlayer"', self.menu_scene)
        self.assertIn('res://audio/music/stage_theme.ogg', self.menu_scene)
        self.assertIn('bus = &"Music"', self.menu_scene)

    def test_menu_script_contract(self):
        self.assertIn('class_name Menu', self.menu_script)
        self.assertIn('extends Control', self.menu_script)
        self.assertIn('signal game_selected(scene_path: String)', self.menu_script)
        self.assertIn('signal quit_requested', self.menu_script)
        self.assertIn('var _is_transitioning: bool = false', self.menu_script)
        self.assertIn('func launch_game(', self.menu_script)
        self.assertIn('func quit_game(', self.menu_script)
        self.assertIn('func _unhandled_input(', self.menu_script)
        self.assertIn('p1_down', self.menu_script)
        self.assertIn('p1_up', self.menu_script)
        self.assertIn('p1_punch', self.menu_script)

    def test_main_script_return_hook(self):
        self.assertIn('signal return_to_menu_requested', self.main_script)
        self.assertIn('var _returning_to_menu: bool = false', self.main_script)
        self.assertIn('func return_to_menu(', self.main_script)
        self.assertIn('func _unhandled_input(', self.main_script)
        self.assertIn('ui_cancel', self.main_script)
        self.assertIn('scenes/Menu.tscn', self.main_script)

    def test_test_runner_registered(self):
        self.assertIn('tests/test_menu.gd', self.test_runner)
        self.assertIn('success_menu', self.test_runner)

if __name__ == "__main__":
    unittest.main()
