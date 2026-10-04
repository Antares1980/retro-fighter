# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Implemented `scenes/Fighter.tscn` and `scripts/Fighter.gd` with 13-state deterministic FSM, combat mechanics, and damage receiving:
  - 13 distinct states: `IDLE`, `WALK_FORWARD` (100 px/s), `WALK_BACKWARD` (80 px/s), `JUMP_SQUAT` (3 ticks), `JUMPING` (-420 px/s jump velocity, 980 px/s² gravity), `CROUCHING` (32 px hurtbox height), `ATTACK_PUNCH`, `ATTACK_KICK`, `BLOCKING`, `BLOCK_STUN`, `HIT_STUN`, `KNOCKDOWN`, `DEAD`.
  - Frame-accurate attack data presets for Punch (12 ticks total: 4 startup, 3 active, 5 recovery; 8 clean damage, 12 hit stun, 6 block stun, 40 px/s knockback) and Kick (19 ticks total: 7 startup, 4 active, 8 recovery; 14 clean damage, 18 hit stun, 8 block stun, 80 px/s knockback).
  - Tactical High/Low defense rules with dedicated button blocking: high attacks blockable standing or crouching; low attacks must be blocked crouching (standing block fails taking full damage and knockback).
  - 80% damage mitigation on successful blocks (`floor(damage * 0.2)`) with zero knockback.
  - One-shot hit registration via `Hitbox.hit_consumed`.
  - Layer 2 pushbox collision preventing pass-through and preserving spatial separation.
  - Stage boundary [16, 584] and camera viewport boundary [camera.left + 16, camera.right - 16] clamping.
  - Player 2 dummy toggle (`toggle_p2_dummy` / F1) with auto crouch-block and state persistence across round reset.
  - Terminal KO and round reset contract restoring 100 HP, starting positions, and state to `IDLE`.
- Added comprehensive unit and integration test coverage:
  - Headless GDScript tests in `tests/test_fighter.gd` covering all AC-01 through AC-07 and AC-10 scenarios (165 passing tests in runner).
  - Python static and contractual tests in `tests/test_fighter.py` (36 passing tests).
  - Registered `test_fighter.gd` into `tests/test_runner.gd`.
- Implemented `scripts/Hitbox.gd` with 7-layer collision bitmask, `setup(player_id)` parameterization (Layer 5 / Mask 6 for P1, Layer 7 / Mask 4 for P2), one-shot hit registration via `hit_consumed`, attack frame data presets (Punch and Kick), and facing-relative horizontal offsets.
- Implemented `scripts/Hurtbox.gd` with 7-layer collision bitmask, `setup(player_id)` parameterization (Layer 4 for P1, Layer 6 for P2), dynamic standing (24x54 px) and crouching (24x32 px) geometry sizing, hit reception, and fighter dispatch contract.
- Added comprehensive unit and integration test coverage:
  - Headless GDScript tests in `tests/test_hitbox_hurtbox.gd` covering bitmask constants, player setup, collision matrix isolation, one-shot registration, attack presets, crouching geometry, fighter dispatch, invulnerability, and signal emission.
  - Python test suite in `tests/test_hitbox_hurtbox.py` validating script contracts, class definitions, bitmasks, and mathematical invariants.
  - Integrated hitbox and hurtbox test suite into `tests/test_runner.gd`.
- Initialized `project.godot` with CPS-1 retro viewport configuration (384x224, 1152x672 window override, integer scaling, nearest-neighbor texture filtering).
- Configured deterministic 60 Hz physics ticks rate (`physics/common/physics_ticks_per_second = 60`).
- Configured 2D physics layer bitmasks (`WorldFloor`, `FighterBody`, `StageWall`, `P1_Hurtbox`, `P1_Hitbox`, `P2_Hurtbox`, `P2_Hitbox`).
- Configured comprehensive Input Action Map:
  - Player 1: `p1_left` (A), `p1_right` (D), `p1_up` (W), `p1_down` (S), `p1_punch` (J), `p1_kick` (K), `p1_block` (L).
  - Player 2: `p2_left` (Left Arrow), `p2_right` (Right Arrow), `p2_up` (Up Arrow), `p2_down` (Down Arrow), `p2_punch` (KP_1 / Comma), `p2_kick` (KP_2 / Period), `p2_block` (KP_0 / Slash).
  - Debug: `toggle_p2_dummy` (F1).
- Created minimal bootstrap scene `scenes/Main.tscn` conforming to AC-11 standalone launch readiness.
- Implemented unit and integration test suites:
  - GDScript headless test suite (`tests/test_engine_foundation.gd`, `tests/test_runner.gd`).
  - Python project configuration test suite (`tests/test_project_godot.py`).
- Added CI workflow `.github/workflows/ci.yml`.
- Added `.gitignore` for Godot 4 and Python testing artifacts.
