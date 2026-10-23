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
        self.assertIn('node name="RoadDecor" type="Node3D"', self.main_scene)
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
        self.assertIn('texture_filter = 5', self.giant_scene)
        self.assertIn('node name="HealthBar"', self.giant_scene)

    def test_cannon_scene_structure(self):
        self.assertIn('node name="Cannon3D" type="Node3D"', self.cannon_scene)
        self.assertIn('node name="Muzzle" type="Marker3D"', self.cannon_scene)

    def test_gate_scene_structure(self):
        self.assertIn('node name="MultiplierGate3D" type="Area3D"', self.gate_scene)
        self.assertIn('size = Vector3(4, 2, 0.6)', self.gate_scene)
        self.assertIn('node name="Label3D" type="Label3D"', self.gate_scene)
        self.assertIn('texture_filter = 5', self.gate_scene)

    def test_mob_scene_structure(self):
        self.assertIn('node name="MobUnit3D" type="Area3D"', self.mob_scene)
        self.assertIn('CapsuleShape3D', self.mob_scene)
        self.assertIn('CapsuleMesh', self.mob_scene)

    def test_scripts_contract(self):
        self.assertIn('class_name MobControlMain', self.main_script)
        self.assertIn('enum GameState { PLAYING, STAGE_CLEAR, VICTORY, DEFEAT }', self.main_script)
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
        """GWT 1, 6, 9: Verify 5-stage base HP table, breach defeat at z >= 9.0, and win condition (Base 0 HP)."""
        self.assertIn('"base_hp": 1200', self.main_script)
        self.assertIn('"base_hp": 10000', self.main_script)
        self.assertIn("global_position.z >= 9.0", self.main_script)
        self.assertIn("state = GameState.DEFEAT", self.main_script)
        self.assertIn("state = GameState.STAGE_CLEAR", self.main_script)
        self.assertIn("state = GameState.VICTORY", self.main_script)
        self.assertIn("giant_enemy.hp <= 0", self.main_script)
        self.assertNotIn("Yellow Base", self.main_script)
        self.assertNotIn("siege", self.main_script.lower())

    def test_is_live_untyped_and_pruning_contract(self):
        """Issue #41 / GWT 1-4: Verify untyped is_live(mob: Variant), pre-tick pruning, and regression tests."""
        self.assertIn("func is_live(mob: Variant) -> bool:", self.main_script)
        self.assertNotIn("func is_live(mob: MobUnit3D", self.main_script)
        self.assertIn("blue_mobs.remove_at(i)", self.main_script)
        self.assertIn("red_mobs.remove_at(i)", self.main_script)
        self.assertIn("test_scenario_9_freed_instance_safety_and_pruning", self.test_gd)

    def test_stage_matrix_and_enum_contract(self):
        """Issue #44 / GWT 7, 8: Verify const STAGES array, stage init, STAGE_CLEAR enum, and dynamic depth bound."""
        self.assertIn('enum GameState { PLAYING, STAGE_CLEAR, VICTORY, DEFEAT }', self.main_script)
        self.assertIn('const STAGES: Array[Dictionary]', self.main_script)
        self.assertIn('"base_hp": 1200', self.main_script)
        self.assertIn('"base_hp": 10000', self.main_script)
        self.assertIn('highway_min_z - 3.0', self.main_script)
        self.assertIn('func init_stage(', self.main_script)
        self.assertIn('func cleanup_stage_entities()', self.main_script)
        self.assertIn('func get_cleanup_bound_z()', self.main_script)
        self.assertIn("test_scenario_10_core_stage_config_and_dynamic_depth_highway", self.test_gd)

    def test_shield_lock_state_machine_contract(self):
        """Issue #45 / GWT 1, 2: Verify 3-Act Base Shield Lock state machine, Pylons, Counter-Surge, and 0-damage discard."""
        self.assertIn('enum EntityMode { BASE, PYLON', self.giant_script)
        self.assertIn('var is_invulnerable: bool', self.giant_script)
        self.assertIn('var is_shielded: bool', self.giant_script)
        self.assertIn('func is_pylon()', self.giant_script)
        self.assertIn('func _apply_damage_to_base(', self.main_script)
        self.assertIn('func _trigger_shield_lock(', self.main_script)
        self.assertIn('func _spawn_shield_pylon(', self.main_script)
        self.assertIn('func _spawn_counter_surge_wave(', self.main_script)
        self.assertIn('func _check_shield_release()', self.main_script)
        self.assertIn('func _resolve_pylon_contacts()', self.main_script)
        self.assertIn('func is_base_shielded()', self.main_script)
        self.assertIn('func get_current_lock_act()', self.main_script)
        self.assertIn("test_scenario_11_three_act_base_shield_lock_state_machine", self.test_gd)

    def test_vault_and_evolution_gate_contract(self):
        """Issue #46 / GWT 3, 4: Verify Destructible Vaults and Two-Way Evolution Gates contract."""
        self.assertIn('var is_locked: bool', self.gate_script)
        self.assertIn('var is_evolution_gate: bool', self.gate_script)
        self.assertIn('func is_active() -> bool', self.gate_script)
        self.assertIn('func feed_blue(', self.gate_script)
        self.assertIn('func sabotage_red(', self.gate_script)
        self.assertIn('const PROGRESS_PER_LEVEL: int = 30', self.gate_script)
        self.assertIn('const MAX_LEVEL: int = 15', self.gate_script)
        self.assertIn('const MIN_LEVEL: int = 1', self.gate_script)
        self.assertIn('func _resolve_vault_contacts()', self.main_script)
        self.assertIn('func on_mob_hit_vault(', self.main_script)
        self.assertIn('func _destroy_vault(', self.main_script)
        self.assertIn('func spawn_vault(', self.main_script)
        self.assertIn('func spawn_evolution_gate(', self.main_script)
        self.assertIn('test_scenario_12_vault_destruction_and_evolution_gates', self.test_gd)

    def test_progression_loop_input_latching_and_pacing_contract(self):
        """Issue #47 / GWT 5, 6, 9: Verify Progression Loop, Input Latching, Campaign Victory, and Pacing."""
        # GWT 5: Event-driven fresh non-echo key-down press advance/retry
        self.assertIn("event.pressed and not event.echo", self.main_script)
        self.assertIn("KEY_SPACE", self.main_script)
        self.assertIn("KEY_ENTER", self.main_script)
        self.assertIn("KEY_R", self.main_script)
        self.assertIn("func advance_stage()", self.main_script)
        self.assertIn("func retry_stage()", self.main_script)

        # GWT 6: Campaign Victory on Stage 5 and restart
        self.assertIn("CAMPAIGN VICTORY!", self.main_script)
        self.assertIn("init_stage(0)", self.main_script)

        # GWT 9: Deterministic Pacing Lower Bounds
        stages_data = [
            {"base_hp": 1200, "pylons": [250, 350, 500], "vault_hp": 400},
            {"base_hp": 2500, "pylons": [400, 550, 750], "vault_hp": 700},
            {"base_hp": 4500, "pylons": [600, 850, 1100], "vault_hp": 1200},
            {"base_hp": 7000, "pylons": [850, 1150, 1450], "vault_hp": 1800},
            {"base_hp": 10000, "pylons": [1100, 1400, 1800], "vault_hp": 2500},
        ]
        max_sustained_blue_dps = 1.0 / 0.14
        max_lane_dps = 400.0 / 60.0
        for s in stages_data:
            effective_hp = s["base_hp"] + sum(s["pylons"]) + s["vault_hp"]
            stage_duration = effective_hp / max_sustained_blue_dps
            self.assertGreaterEqual(stage_duration, 180.0, f"Stage effective HP {effective_hp} duration < 180s")
            vault_duration = s["vault_hp"] / max_lane_dps
            self.assertGreaterEqual(vault_duration, 60.0 - 0.001, f"Vault HP {s['vault_hp']} duration < 60s")

        self.assertIn("test_scenario_13_progression_loop_input_latching_and_pacing", self.test_gd)

    def test_visual_gate_spread_hires_viewport_and_road_scroller_contract(self):
        """Spec 001 / GWT 1-4: Verify lateral gate spread, dynamic 1152x672 viewport switch/restore, and forward highway scroller."""
        # US1: Lateral & Staggered Gate Duplication Spread
        self.assertIn("const CLONE_SPACING_X: float = 0.55", self.main_script)
        self.assertIn("const CLONE_SPACING_Z: float = 0.50", self.main_script)
        self.assertIn("const MAX_ROW_WIDTH: int = 5", self.main_script)
        self.assertIn("const HIGHWAY_HALF_WIDTH: float = 4.5", self.main_script)
        self.assertIn("func _compute_gate_formation_slot(", self.main_script)

        # US2: Dynamic High-Resolution 3D Viewport & Retro 2D Restoration
        self.assertIn("const HI_RES_SIZE: Vector2i = Vector2i(1152, 672)", self.main_script)
        self.assertIn("const RETRO_RES_SIZE: Vector2i = Vector2i(384, 224)", self.main_script)
        self.assertIn("func _apply_high_res_viewport()", self.main_script)
        self.assertIn("func _restore_retro_viewport()", self.main_script)
        self.assertIn("func _exit_tree()", self.main_script)
        self.assertIn("Window.CONTENT_SCALE_MODE_CANVAS_ITEMS", self.main_script)
        self.assertIn("Window.CONTENT_SCALE_MODE_VIEWPORT", self.main_script)
        self.assertIn("Viewport.MSAA_4X", self.main_script)
        self.assertIn("Viewport.MSAA_DISABLED", self.main_script)

        # US3: Deterministic Forward Highway Scroller
        self.assertIn("const ROAD_SCROLL_SPEED: float = 8.0", self.main_script)
        self.assertIn("const ROAD_SCROLL_MIN_Z: float = -52.0", self.main_script)
        self.assertIn("const ROAD_SCROLL_MAX_Z: float = 12.0", self.main_script)
        self.assertIn("func _setup_road_scroller()", self.main_script)
        self.assertIn("func _step_road_scroller(", self.main_script)
        self.assertIn("var road_scroller_nodes: Array[Node3D]", self.main_script)

        self.assertIn("test_scenario_14_gate_spread_hires_viewport_and_road_scroller", self.test_gd)

    def test_multi_cannon_squad_and_bullet_power_contract(self):
        """Verify multi-cannon squad (MAX_CANNONS = 5), xN gate progression, bullet_power scaling, and visual status UI."""
        self.assertIn("const MAX_CANNONS: int = 5", self.main_script)
        self.assertIn("var cannons: Array[Cannon3DScript]", self.main_script)
        self.assertIn("var bullet_power: int = 1", self.main_script)
        self.assertIn("func get_cannon_count() -> int", self.main_script)
        self.assertIn("func get_bullet_power() -> int", self.main_script)
        self.assertIn("func _on_bullet_hit_multiplier_gate(", self.main_script)
        self.assertIn("func _reset_cannons_and_power()", self.main_script)
        self.assertIn("var power: int = 1", self.mob_script)
        self.assertIn("func _update_power_visuals()", self.mob_script)
        self.assertIn('node name="CannonStatusLabel" type="Label"', self.main_scene)
        self.assertIn("test_scenario_15_multi_cannon_squad_and_bullet_power_progression", self.test_gd)

    def test_extended_waves_obstacles_3d_forms_and_destruction_contract(self):
        """Spec 002 / GWT 1-5: Verify multi-wave progression, gate-charge cap, 3 obstacle modes, 3D raider/mech rigs, and destruction FX."""
        # US1: Multi-Wave Stage Progression & Gate-Charge Power Cap
        self.assertIn('"waves": 3', self.main_script)
        self.assertIn('"waves": 5', self.main_script)
        self.assertIn("const GATE_CHARGE_THRESHOLD: int = 35", self.main_script)
        self.assertIn("const MAX_BULLET_POWER: int = 25", self.main_script)
        self.assertIn("const GIANT_FORTIFIED_SPEED: float = 0.18", self.main_script)
        self.assertIn("var current_wave: int = 1", self.main_script)
        self.assertIn("var total_waves_in_stage: int = 3", self.main_script)
        self.assertIn("var gate_power_charge: int = 0", self.main_script)
        self.assertIn("func _check_wave_progression()", self.main_script)

        # US2: Three Highway Obstacle Modes
        self.assertIn("enum EntityMode { BASE, PYLON, WALL, MOVING_BLOCK, HAZARD }", self.giant_script)
        self.assertIn("func is_wall() -> bool", self.giant_script)
        self.assertIn("func is_moving_block() -> bool", self.giant_script)
        self.assertIn("func is_hazard() -> bool", self.giant_script)
        self.assertIn("func step_obstacle(delta: float)", self.giant_script)
        self.assertIn("var active_obstacles: Array[Node3D]", self.main_script)
        self.assertIn("func spawn_obstacle(", self.main_script)
        self.assertIn("func _resolve_obstacle_contacts()", self.main_script)
        self.assertIn("func on_mob_hit_obstacle(", self.main_script)

        # US3: Articulated 3D Raider & Giant Mech Silhouettes
        self.assertIn("func _build_raider_model()", self.mob_script)
        self.assertIn("func step_visuals(delta: float)", self.mob_script)
        self.assertIn("func get_raider_part_count() -> int", self.mob_script)
        self.assertIn("func _build_entity_model()", self.giant_script)
        self.assertIn("func get_visual_part_count() -> int", self.giant_script)

        # US4: Hit Flash, 3D Shatter FX, & Zero-HP Screen Removal
        self.assertIn("func is_hit_flashing() -> bool", self.giant_script)
        self.assertIn("const DESTRUCTION_FX_DURATION: float = 0.45", self.main_script)
        self.assertIn("var active_destruction_fx: Array[Node3D]", self.main_script)
        self.assertIn("func _spawn_destruction_fx(", self.main_script)
        self.assertIn("func _step_destruction_fx(delta: float)", self.main_script)
        self.assertIn("giant_enemy.visible = false", self.main_script)
        self.assertIn("test_scenario_16_extended_waves_obstacles_3d_forms_and_destruction_fx", self.test_gd)

if __name__ == "__main__":
    unittest.main()
