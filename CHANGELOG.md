# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
