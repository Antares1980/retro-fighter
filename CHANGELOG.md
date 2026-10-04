# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
