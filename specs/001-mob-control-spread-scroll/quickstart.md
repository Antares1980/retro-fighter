# Quickstart & Validation Guide: Mob Control 3D Visual Gate Duplication Spread, High-Resolution Display, and Forward Highway Motion

**Feature**: `001-mob-control-spread-scroll`  
**Date**: 2026-10-23

## Prerequisites

- **Python 3.11+** (for static and contract unit tests)
- **Godot Engine 4.3** (`godot` CLI available on PATH or installed locally for headless engine verification)

## Automated Verification Commands

### 1. Run Python Static & Contract Test Suite

From the repository root:

```powershell
python -m unittest discover -s tests -v
```

**Expected Outcome**:
- All Python test modules (`test_mob_control.py`, `test_menu.py`, `test_project_godot.py`, `test_fighter.py`, `test_camera.py`, `test_hitbox_hurtbox.py`, `test_stage_hud_orchestrator.py`, `test_ai_controller.py`, `test_audio_pipeline.py`) pass with `OK`.
- `test_mob_control.py` verifies the lateral formation constants (`CLONE_SPACING_X`, `CLONE_SPACING_Z`, `MAX_ROW_WIDTH`), dynamic viewport scaling methods (`_apply_high_res_viewport`, `_restore_retro_viewport`), road scroller methods (`_setup_road_scroller`, `_step_road_scroller`), and `Label3D` linear mipmap filtering.

### 2. Run Godot 4.3 Headless Runtime Test Runner

From the repository root:

```powershell
godot --headless -s res://tests/test_runner.gd
```

**Expected Outcome**:
- All registered headless GDScript test suites pass with `0 failed` and `0 SCRIPT ERROR` messages.
- Scenario 14 in `tests/test_mob_control.gd` validates:
  - **GWT 1**: Passing a single Blue Mob through `gate_right_1` (`x2`) produces 2 Blue Mobs separated horizontally by `>= 0.45` units (`0.55` units); passing through `gate_left_1` (`+2`) produces 3 Blue Mobs with pairwise distinct `(X, Z)` positions.
  - **GWT 2**: Passing a Blue Mob near the highway edge (`X = 4.4`) through a `+5` gate clamps all 6 resulting units strictly within `[-4.5, +4.5]` with zero overlapping coordinates.
  - **GWT 3**: Entering `MobControlMain` switches the root `Window` to `Vector2i(1152, 672)` (`CONTENT_SCALE_MODE_CANVAS_ITEMS`) and `Viewport` to `MSAA_4X`, and calling `return_to_menu()` / `_exit_tree()` restores `Vector2i(384, 224)` (`CONTENT_SCALE_MODE_VIEWPORT`) and `MSAA_DISABLED`.
  - **GWT 4**: Calling `step(1.0 / 60.0)` during `GameState.PLAYING` advances road scroller markers by `+ROAD_SCROLL_SPEED * (1.0 / 60.0)`, wraps markers exceeding `Z > 12.0` back to `-52.0`, and halts marker movement when `state != GameState.PLAYING`.
