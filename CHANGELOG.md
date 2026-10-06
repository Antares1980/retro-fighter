# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Implemented modular procedural Polygon2D karateka rig and dynamic palette swapping (Issue #13):
  - Replaced placeholder `ColorRect` visual nodes (`Body`, `Head`, `AttackVisual`) in `scenes/Fighter.tscn` with a 12-node hierarchical `Polygon2D` karateka rig: `BackArm` (z -2), `BackLeg` (z -1), `TorsoGi` (z 0), `Belt` (z 1), `BeltKnot` (z 1), `Head` (z 2), `Hair` (z 3), `Headband` (z 3), `Ties` (z 2), `LeadLeg` (z 4), `LeadArm` (z 5), and `Glove` (z 5) with relative z-indexing (`z_as_relative = true`).
  - Added dynamic palette swapping via `PALETTES` dictionary in `scripts/Fighter.gd`: Player 1 white gi with crimson accents (`Color("ffffff")` / `Color("b81414")`), Player 2 navy gi with gold accents (`Color("243356")` / `Color("e6a117")`).
  - Implemented `apply_palette()` in `scripts/Fighter.gd` using safe `get_node_or_null` lookups and integrated directly into `setup(p_player_id)`.
  - Retyped `body_rect` to `torso_gi: Polygon2D` and `head_rect` to `head_poly: Polygon2D` with safe binding in `_init_nodes()`.
  - Retired `_set_attack_visual()` and removed all call sites in `scripts/Fighter.gd`.
  - Refactored `_set_visual_crouch()` to remove `offset_top` references, preserving `Visual.position` at `Vector2(0, 0)`.
  - Updated GDScript test suite in `tests/test_fighter.gd` verifying `Visual/TorsoGi`, all procedural rig nodes, and AC-1 palette application on setup.
  - Expanded Python static and scene contract tests in `tests/test_fighter.py` validating the Polygon2D rig nodes, retyped members, and palettes.

### Fixed
- Fixed `scripts/Fighter.gd` walk velocity test failures by restoring input action release checks for forward and backward walking, avoiding premature IDLE transitions when input axes are neutral.
- Fixed `scripts/Main.gd` match FSM initialization so `ROUND_INTRO` entry logic (freezing inputs, displaying `FIGHT!` announcer banner) triggers deterministically upon `_ready()` and round reset.
- Fixed headless Godot engine script parse error in `scripts/Main.gd` where `Fighter` type annotation failed during headless execution without pre-cached global script registry.
- Improved headless runner node initialization in `scripts/Main.gd` to ensure robust node resolution (`$P1`, `$P2`, `$HUD`) and lifecycle handling when executed outside an active SceneTree.
- Added headless editor import pass step (`godot --headless --editor --quit`) in CI workflow `.github/workflows/ci.yml`.

### Added
- Implemented `scenes/Stage.tscn`, `scenes/HUD.tscn`, `scenes/Main.tscn`, `scripts/HUD.gd`, and `scripts/Main.gd` with match FSM orchestrator, timer countdown, announcer banners, and observable contracts:
  - `scenes/Stage.tscn`: 600 px width gradient sunset backdrop (600x224 px), cityscape silhouette `Polygon2D`, ground collision line at Y = 190 on Layer 1 (`WorldFloor`), and stage boundaries on Layer 4 (`StageWall`).
  - `scenes/HUD.tscn` & `scripts/HUD.gd`: Retro HUD featuring yellow-to-red depleting health bars for Player 1 and Player 2 (modulating yellow >50%, orange <=50%, red <=25%), 99-second countdown timer, and prominent center announcer banners ("FIGHT!", "K.O.", "TIME UP", "DRAW").
  - `scripts/Main.gd`: Full 4-state match FSM (`ROUND_INTRO`, `IN_ROUND`, `ROUND_OVER`, `RESET`), timer countdown from 99s, KO/time-up/draw resolution, and observable signal `round_ended(winner_id: int, reason: String)` with `last_winner_id` and `last_reason`.
  - `scenes/Main.tscn`: Root game scene wiring together Stage, Camera2D, Fighter P1 (X=200, Y=190), Fighter P2 (X=400, Y=190, player_id=2), and HUD.
  - Implemented input freezing during `ROUND_INTRO` and `ROUND_OVER` in `scripts/Fighter.gd` (`inputs_frozen` flag and property) while maintaining physics and state transition integrity.
- Added comprehensive unit and integration test coverage:
  - Headless GDScript tests in `tests/test_stage_hud_orchestrator.gd` covering stage structure, HUD color transitions, main scene wiring, match FSM intro-to-round, AC-07 (KO and 3.0s auto-restart), AC-08 (timeout win determination), AC-09 (draw resolution on equal health and double KO), AC-10 (dummy mode persistence), and AC-11 (standalone launch readiness).
  - Python tests in `tests/test_stage_hud_orchestrator.py` validating files, node hierarchies, constants, signals, and match loop decision logic (14 tests).
  - Integrated `test_stage_hud_orchestrator.gd` into `tests/test_runner.gd`.
- Implemented `scenes/Camera2D.tscn` and `scripts/DynamicFightCamera.gd` with dynamic camera tracking and viewport boundary clamping:
  - Fixed zoom (1.0) pan-only framing maintaining retro 384x224 CPS-1 pixel aesthetics.
  - Deterministic horizontal midpoint tracking between Player 1 and Player 2.
  - Stage horizontal boundary clamping restricting camera center between X = 192 and X = 408 (keeping the 384 px viewport strictly within the 600 px stage bounds [0, 600]).
  - Exposes `get_view_bounds() -> Rect2`, `left_bound`, and `right_bound` properties for viewport edge calculation.
  - Integrated dynamic camera clamping in `scripts/Fighter.gd`, enforcing camera boundary clamping [camera.left + 16, camera.right - 16] and stage boundary clamping [16, 584] to prevent fighters from moving off-screen.
- Added comprehensive unit and integration test coverage:
  - Headless GDScript tests in `tests/test_camera.gd` covering scene and script instantiation, constants, fixed zoom, midpoint framing, camera clamping, view bounds calculations, automatic target resolution, single target fallback, and AC-06 fighter camera clamping integration (50 passing tests).
  - Python tests in `tests/test_camera.py` validating files, script declarations, scene structure, methods, and mathematical invariants (8 tests).
  - Registered `test_camera.gd` into `tests/test_runner.gd`.
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
