import os
import unittest

class TestFighter(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cls.fighter_script_path = os.path.join(base_dir, "scripts", "Fighter.gd")
        cls.fighter_scene_path = os.path.join(base_dir, "scenes", "Fighter.tscn")

        with open(cls.fighter_script_path, "r", encoding="utf-8") as f:
            cls.fighter_code = f.read()

        with open(cls.fighter_scene_path, "r", encoding="utf-8") as f:
            cls.fighter_scene = f.read()

    def test_files_exist(self):
        self.assertTrue(os.path.isfile(self.fighter_script_path), "scripts/Fighter.gd must exist")
        self.assertTrue(os.path.isfile(self.fighter_scene_path), "scenes/Fighter.tscn must exist")

    def test_class_declaration_and_inheritance(self):
        self.assertIn("class_name Fighter", self.fighter_code)
        self.assertIn("extends CharacterBody2D", self.fighter_code)

    def test_13_states_in_enum(self):
        expected_states = [
            "IDLE",
            "WALK_FORWARD",
            "WALK_BACKWARD",
            "JUMP_SQUAT",
            "JUMPING",
            "CROUCHING",
            "ATTACK_PUNCH",
            "ATTACK_KICK",
            "BLOCKING",
            "BLOCK_STUN",
            "HIT_STUN",
            "KNOCKDOWN",
            "DEAD"
        ]
        for state in expected_states:
            self.assertIn(state, self.fighter_code)

    def test_movement_and_physics_constants(self):
        self.assertIn("const MAX_HEALTH: int = 100", self.fighter_code)
        self.assertIn("const WALK_FORWARD_SPEED: float = 100.0", self.fighter_code)
        self.assertIn("const WALK_BACKWARD_SPEED: float = 80.0", self.fighter_code)
        self.assertIn("const JUMP_VELOCITY: float = -420.0", self.fighter_code)
        self.assertIn("const GRAVITY: float = 980.0", self.fighter_code)
        self.assertIn("const JUMP_SQUAT_TICKS: int = 3", self.fighter_code)

    def test_punch_frame_data_constants(self):
        self.assertIn("const PUNCH_TOTAL_TICKS: int = 12", self.fighter_code)
        self.assertIn("const PUNCH_STARTUP_TICKS: int = 4", self.fighter_code)
        self.assertIn("const PUNCH_ACTIVE_TICKS: int = 3", self.fighter_code)
        self.assertIn("const PUNCH_RECOVERY_TICKS: int = 5", self.fighter_code)
        self.assertIn("const PUNCH_DAMAGE: int = 8", self.fighter_code)
        self.assertIn("const PUNCH_HIT_STUN_TICKS: int = 12", self.fighter_code)
        self.assertIn("const PUNCH_BLOCK_STUN_TICKS: int = 6", self.fighter_code)
        self.assertIn("const PUNCH_KNOCKBACK: float = 40.0", self.fighter_code)

    def test_kick_frame_data_constants(self):
        self.assertIn("const KICK_TOTAL_TICKS: int = 19", self.fighter_code)
        self.assertIn("const KICK_STARTUP_TICKS: int = 7", self.fighter_code)
        self.assertIn("const KICK_ACTIVE_TICKS: int = 4", self.fighter_code)
        self.assertIn("const KICK_RECOVERY_TICKS: int = 8", self.fighter_code)
        self.assertIn("const KICK_DAMAGE: int = 14", self.fighter_code)
        self.assertIn("const KICK_HIT_STUN_TICKS: int = 18", self.fighter_code)
        self.assertIn("const KICK_BLOCK_STUN_TICKS: int = 8", self.fighter_code)
        self.assertIn("const KICK_KNOCKBACK: float = 80.0", self.fighter_code)

    def test_boundary_clamping_constants(self):
        self.assertIn("const STAGE_MIN_X: float = 16.0", self.fighter_code)
        self.assertIn("const STAGE_MAX_X: float = 584.0", self.fighter_code)
        self.assertIn("const VIEWPORT_MARGIN_X: float = 16.0", self.fighter_code)

    def test_core_methods_defined(self):
        self.assertIn("func setup(", self.fighter_code)
        self.assertIn("func receive_hit(", self.fighter_code)
        self.assertIn("func change_state(", self.fighter_code)
        self.assertIn("func reset_round(", self.fighter_code)
        self.assertIn("func reset_fighter(", self.fighter_code)
        self.assertIn("func toggle_dummy(", self.fighter_code)
        self.assertIn("func update_facing(", self.fighter_code)
        self.assertIn("func _apply_clamping(", self.fighter_code)

    def test_damage_mitigation_formula(self):
        # 80% mitigation via floor(damage * 0.2)
        self.assertIn("floor(float(p_damage) * 0.2)", self.fighter_code)

    def test_signals_declared(self):
        self.assertIn("signal health_changed(", self.fighter_code)
        self.assertIn("signal state_changed(", self.fighter_code)
        self.assertIn("signal hit_received(", self.fighter_code)
        self.assertIn("signal knocked_down", self.fighter_code)
        self.assertIn("signal died", self.fighter_code)

    def test_scene_node_structure(self):
        self.assertIn('node name="Fighter" type="CharacterBody2D"', self.fighter_scene)
        self.assertIn('node name="PushboxShape" type="CollisionShape2D"', self.fighter_scene)
        self.assertIn('node name="Hurtbox" type="Area2D"', self.fighter_scene)
        self.assertIn('node name="Hitbox" type="Area2D"', self.fighter_scene)
        self.assertIn('node name="Visual" type="Node2D"', self.fighter_scene)
        self.assertIn('collision_layer = 2', self.fighter_scene)
        self.assertIn('collision_mask = 7', self.fighter_scene)

    def test_dummy_mode_defaults_and_toggle(self):
        self.assertIn("var is_dummy: bool = false", self.fighter_code)
        self.assertIn("is_dummy = not is_dummy", self.fighter_code)
        # AC-10 specifies toggle action toggle_p2_dummy
        self.assertIn('event.is_action_pressed("toggle_p2_dummy")', self.fighter_code)

    def test_procedural_polygon2d_rig(self):
        rig_nodes = [
            "BackArm", "BackLeg", "TorsoGi", "Belt", "BeltKnot",
            "Head", "Hair", "Headband", "Ties", "LeadLeg", "LeadArm", "Glove"
        ]
        for node in rig_nodes:
            self.assertIn(f'node name="{node}" type="Polygon2D" parent="Visual"', self.fighter_scene)

        # Placeholders must be gone
        self.assertNotIn('node name="Body" type="ColorRect"', self.fighter_scene)
        self.assertNotIn('node name="AttackVisual" type="ColorRect"', self.fighter_scene)

    def test_retyped_visual_members_and_palettes(self):
        self.assertIn("torso_gi: Polygon2D = $Visual/TorsoGi", self.fighter_code)
        self.assertIn("head_poly: Polygon2D = $Visual/Head", self.fighter_code)
        self.assertNotIn("attack_visual", self.fighter_code)
        self.assertNotIn("_set_attack_visual", self.fighter_code)
        self.assertNotIn("GI_COLOR_P1", self.fighter_code)
        self.assertNotIn("GI_COLOR_P2", self.fighter_code)
        self.assertIn("const PALETTES: Dictionary =", self.fighter_code)
        self.assertIn("func apply_palette(", self.fighter_code)

    def test_animation_player_scene_structure(self):
        self.assertIn('node name="AnimationPlayer" type="AnimationPlayer" parent="."', self.fighter_scene)
        self.assertIn('callback_mode_process = 0', self.fighter_scene)

    def test_animation_player_member_and_invariants(self):
        self.assertIn('animation_player: AnimationPlayer = $AnimationPlayer', self.fighter_code)
        self.assertIn('const LIMB_NODES: Array[String] =', self.fighter_code)
        self.assertIn('const STATE_ANIMATIONS: Dictionary =', self.fighter_code)
        self.assertIn('func _apply_neutral_reset()', self.fighter_code)
        self.assertIn('func _reset_limb_transforms()', self.fighter_code)
        self.assertIn('func _play_animation(', self.fighter_code)
        self.assertIn('static func create_animation_library()', self.fighter_code)

    def test_all_13_states_mapped_to_animations(self):
        expected_mappings = [
            ("State.IDLE", '"idle"'),
            ("State.WALK_FORWARD", '"walk"'),
            ("State.WALK_BACKWARD", '"walk_backward"'),
            ("State.JUMP_SQUAT", '"jump_squat"'),
            ("State.JUMPING", '"jump"'),
            ("State.CROUCHING", '"crouch"'),
            ("State.ATTACK_PUNCH", '"punch"'),
            ("State.ATTACK_KICK", '"kick"'),
            ("State.BLOCKING", '"block"'),
            ("State.BLOCK_STUN", '"block_stun"'),
            ("State.HIT_STUN", '"hit"'),
            ("State.KNOCKDOWN", '"knockdown"'),
            ("State.DEAD", '"dead"'),
        ]
        for state_enum, anim_name in expected_mappings:
            pattern = f"{state_enum}: {anim_name}"
            self.assertIn(pattern, self.fighter_code, f"State mapping {pattern} must exist in STATE_ANIMATIONS")

    def test_track_isolation_invariant_enforcement(self):
        # Asserts must guard track creation to only allow LIMB_NODES
        self.assertIn('assert(limb in LIMB_NODES', self.fighter_code)
        self.assertIn('"Visual/%s:%s" % [limb, property]', self.fighter_code)
        # Invariants: no animation calls may touch Visual scale.x or collision nodes directly
        self.assertNotIn('"Visual:scale', self.fighter_code)
        self.assertNotIn('"Visual:scale:x', self.fighter_code)
        self.assertNotIn('"PushboxShape:', self.fighter_code)
        self.assertNotIn('"Hurtbox:', self.fighter_code)
        self.assertNotIn('"Hitbox:', self.fighter_code)

    def test_headless_null_guards(self):
        # All animation calls must be wrapped in null check
        self.assertIn('if animation_player != null', self.fighter_code)


if __name__ == "__main__":
    unittest.main()

