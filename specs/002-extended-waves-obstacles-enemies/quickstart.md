# Quickstart & Validation Guide: Extended Multi-Wave Stages, Highway Obstacles, Articulated Enemy Silhouettes, and Destruction Lifecycle

**Feature**: `002-extended-waves-obstacles-enemies`
**Date**: 2026-10-23

## Prerequisites

- **Python 3.11+** (for static scene/script contract tests)
- **Godot Engine 4.3 (Console/Headless binary)** (for headless runtime & GWT verification)

## Running Automated Verification

1. **Run the Python Static & Contract Test Suite**:
   ```powershell
   python -m unittest discover -s tests -v
   ```
   **Expected Outcome**: All static tests pass (`OK`), including `test_extended_waves_obstacles_3d_forms_and_destruction_contract` in `tests/test_mob_control.py`.

2. **Run the Godot 4.3 Headless Runtime Suite**:
   ```powershell
   godot --headless -s res://tests/test_runner.gd
   ```
   **Expected Outcome**: All registered test suites pass (`0 failed`), including Scenarios 1–16 in `tests/test_mob_control.gd`.

## Key Validation Scenarios (Scenario 16)

- **GWT 1 (Multi-Wave Progression & Auto-Init)**: Instantiate `MobControlMain.tscn` $\rightarrow$ `current_stage_index == 0`, `giant_enemy.hp == 1200`, `current_wave == 1`, `total_waves_in_stage == 3`, and `active_obstacles.size() > 0`. Destroying Wave 1 obstacles advances `current_wave` to `2` and spawns Wave 2 obstacles.
- **GWT 2 (Gate-Charge Power Scaling & Cap)**: With 5 cannons and `bullet_power == 6`, hitting `xN` gates accumulates `gate_power_charge` and increments `bullet_power` by `+1` every `35` hits, never exceeding `MAX_BULLET_POWER = 25`.
- **GWT 3 (Three Obstacle Categories)**: Verify `WALL`, `MOVING_BLOCK` (horizontal X oscillation clamped in `[-4.5, 4.5]`), and `HAZARD` (`2x` bullet power attrition) intercept projectiles in front of the Boss.
- **GWT 4 (Articulated 3D Enemy & Boss Silhouettes)**: Verify Red `MobUnit3D` has `get_raider_part_count() >= 6` with animated limb stride during `step(delta)`, and `GiantEnemy3D` has `get_visual_part_count() >= 4`.
- **GWT 5 (Hit Flash, 3D Shatter FX, & Zero-HP Disappearance)**: Verify non-lethal damage sets `is_hit_flashing() == true`, lethal damage spawns debris in `active_destruction_fx` that cleans up after `0.45s`, obstacles/pylons/vaults are freed on `0 HP`, and `giant_enemy.visible` becomes `false` when `giant_enemy.hp == 0`.
