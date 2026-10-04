import os
import unittest

class TestHitboxHurtbox(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        cls.hitbox_path = os.path.join(base_dir, "scripts", "Hitbox.gd")
        cls.hurtbox_path = os.path.join(base_dir, "scripts", "Hurtbox.gd")

        with open(cls.hitbox_path, "r", encoding="utf-8") as f:
            cls.hitbox_code = f.read()

        with open(cls.hurtbox_path, "r", encoding="utf-8") as f:
            cls.hurtbox_code = f.read()

    def test_files_exist(self):
        self.assertTrue(os.path.isfile(self.hitbox_path), "scripts/Hitbox.gd must exist")
        self.assertTrue(os.path.isfile(self.hurtbox_path), "scripts/Hurtbox.gd must exist")

    def test_hitbox_class_declaration(self):
        self.assertIn("class_name Hitbox", self.hitbox_code)
        self.assertIn("extends Area2D", self.hitbox_code)

    def test_hurtbox_class_declaration(self):
        self.assertIn("class_name Hurtbox", self.hurtbox_code)
        self.assertIn("extends Area2D", self.hurtbox_code)

    def test_7_layer_constants_in_hitbox(self):
        expected_constants = [
            "const LAYER_WORLDFLOOR: int = 1",
            "const LAYER_FIGHTERBODY: int = 2",
            "const LAYER_STAGEWALL: int = 3",
            "const LAYER_P1_HURTBOX: int = 4",
            "const LAYER_P1_HITBOX: int = 5",
            "const LAYER_P2_HURTBOX: int = 6",
            "const LAYER_P2_HITBOX: int = 7",
        ]
        for const in expected_constants:
            self.assertIn(const, self.hitbox_code)

    def test_7_layer_constants_in_hurtbox(self):
        expected_constants = [
            "const LAYER_WORLDFLOOR: int = 1",
            "const LAYER_FIGHTERBODY: int = 2",
            "const LAYER_STAGEWALL: int = 3",
            "const LAYER_P1_HURTBOX: int = 4",
            "const LAYER_P1_HITBOX: int = 5",
            "const LAYER_P2_HURTBOX: int = 6",
            "const LAYER_P2_HITBOX: int = 7",
        ]
        for const in expected_constants:
            self.assertIn(const, self.hurtbox_code)

    def test_hitbox_bitmask_values(self):
        self.assertIn("const MASK_P1_HITBOX: int = 1 << 4", self.hitbox_code)
        self.assertIn("const MASK_P2_HURTBOX: int = 1 << 5", self.hitbox_code)
        self.assertIn("const MASK_P1_HURTBOX: int = 1 << 3", self.hitbox_code)
        self.assertIn("const MASK_P2_HITBOX: int = 1 << 6", self.hitbox_code)

    def test_hitbox_setup_method(self):
        self.assertIn("func setup(p_player_id: int) -> void:", self.hitbox_code)
        self.assertIn("collision_layer = MASK_P1_HITBOX", self.hitbox_code)
        self.assertIn("collision_mask = MASK_P2_HURTBOX", self.hitbox_code)
        self.assertIn("collision_layer = MASK_P2_HITBOX", self.hitbox_code)
        self.assertIn("collision_mask = MASK_P1_HURTBOX", self.hitbox_code)

    def test_hurtbox_setup_method(self):
        self.assertIn("func setup(p_player_id: int) -> void:", self.hurtbox_code)
        self.assertIn("collision_layer = MASK_P1_HURTBOX", self.hurtbox_code)
        self.assertIn("collision_layer = MASK_P2_HURTBOX", self.hurtbox_code)

    def test_hitbox_oneshot_registration(self):
        self.assertIn("var hit_consumed: bool = false", self.hitbox_code)
        self.assertIn("func reset_hit() -> void:", self.hitbox_code)
        self.assertIn("func trigger_hit(hurtbox: Area2D) -> bool:", self.hitbox_code)
        self.assertIn("if hit_consumed:", self.hitbox_code)
        self.assertIn("hit_consumed = true", self.hitbox_code)

    def test_hurtbox_geometry_and_crouching(self):
        self.assertIn("const STANDING_SIZE: Vector2 = Vector2(24.0, 54.0)", self.hurtbox_code)
        self.assertIn("const STANDING_OFFSET: Vector2 = Vector2(0.0, -27.0)", self.hurtbox_code)
        self.assertIn("const CROUCHING_SIZE: Vector2 = Vector2(24.0, 32.0)", self.hurtbox_code)
        self.assertIn("const CROUCHING_OFFSET: Vector2 = Vector2(0.0, -16.0)", self.hurtbox_code)
        self.assertIn("func set_crouching(crouch: bool) -> void:", self.hurtbox_code)

    def test_attack_presets_in_hitbox(self):
        self.assertIn("const PUNCH_DAMAGE: int = 8", self.hitbox_code)
        self.assertIn("const PUNCH_HIT_STUN: int = 12", self.hitbox_code)
        self.assertIn("const PUNCH_BLOCK_STUN: int = 6", self.hitbox_code)
        self.assertIn("const PUNCH_KNOCKBACK: float = 40.0", self.hitbox_code)
        self.assertIn("const PUNCH_IS_LOW: bool = false", self.hitbox_code)

        self.assertIn("const KICK_DAMAGE: int = 14", self.hitbox_code)
        self.assertIn("const KICK_HIT_STUN: int = 18", self.hitbox_code)
        self.assertIn("const KICK_BLOCK_STUN: int = 8", self.hitbox_code)
        self.assertIn("const KICK_KNOCKBACK: float = 80.0", self.hitbox_code)
        self.assertIn("const KICK_IS_LOW: bool = true", self.hitbox_code)

    def test_signals_declared(self):
        self.assertIn("signal hit_landed(hurtbox: Area2D)", self.hitbox_code)
        self.assertIn("signal hit_received(hitbox: Area2D)", self.hurtbox_code)

    def test_bitmask_mathematical_invariants(self):
        p1_hitbox_layer = 1 << (5 - 1)   # 16
        p1_hitbox_mask = 1 << (6 - 1)    # 32
        p2_hurtbox_layer = 1 << (6 - 1)  # 32
        p1_hurtbox_layer = 1 << (4 - 1)  # 8

        p2_hitbox_layer = 1 << (7 - 1)   # 64
        p2_hitbox_mask = 1 << (4 - 1)    # 8

        # P1 hits P2
        self.assertNotEqual(p1_hitbox_mask & p2_hurtbox_layer, 0)
        # P1 does not hit P1
        self.assertEqual(p1_hitbox_mask & p1_hurtbox_layer, 0)
        # P2 hits P1
        self.assertNotEqual(p2_hitbox_mask & p1_hurtbox_layer, 0)
        # P2 does not hit P2
        self.assertEqual(p2_hitbox_mask & p2_hurtbox_layer, 0)

if __name__ == "__main__":
    unittest.main()
