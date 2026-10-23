# Quickstart & Validation Guide: Endless Survival Phase, Dynamic Scrolling & Respawning Gates, Gate-Crushing Bosses, & Escalating Enemy Waves

## Prerequisites

- **Godot Engine 4.3** (console/headless binary on `PATH` or installed via WinGet)
- **Python 3.11+**

## Running Automated Verification Suites

### 1. Python Static & Contract Test Suite

From the repository root (`c:\Users\rogal\workspaces\ws-games\retro-fighter`), run:

```powershell
python -m unittest discover -s tests -v
```

**Expected Outcome**: All static contract tests across `test_mob_control.py` and sibling suites pass (`OK`), confirming:
- Survival phase constants and methods (`GATE_SCROLL_SPEED`, `GATE_DESPAWN_Z`, `init_survival_phase`, `spawn_random_gate`, `spawn_boss`, `on_boss_destroy_gate`, `_resolve_boss_gate_destruction`) exist in `MobControlMain.gd`.
- Gate scrolling and oscillation (`scroll_speed`, `move_enabled`, `step_gate`) exist in `MultiplierGate3D.gd`.
- Escalating Soldier and Boss spawner helpers (`get_soldier_max_burst`, `get_max_concurrent_bosses`, `get_scaled_boss_hp`) exist and satisfy scaling invariants.

### 2. Godot 4.3 Headless Runtime Suite

From the repository root, run:

```powershell
godot --headless -s res://tests/test_runner.gd
```

**Expected Outcome**: All registered test suites including `TestMobControl` (`Scenarios 1–17`) pass with `0 failed` and `0` script errors, validating:
- **GWT 1**: Default `survival_mode` keeps `state == GameState.PLAYING` when a Boss in `active_bosses` reaches `0 HP`, spawns 3D explosion debris, removes the Boss, and increments `bosses_defeated`.
- **GWT 2**: Active `MultiplierGate3D` blocks move forward (`+Z`) every frame during `PLAYING`, disappear at `Z >= 8.2`, and respawn in the upper highway (`Z <= -14.0`).
- **GWT 3**: Advancing Bosses move faster than drifting gates and shatter/destroy any `MultiplierGate3D` they overlap on contact.
- **GWT 4**: Soldier and Boss spawner formulas scale squad burst size, concurrent Boss count, and Boss HP upward as `time_elapsed` increases.
- **GWT 5**: Enemy breach at `Z >= 9.0` triggers `GameState.DEFEAT` and pressing `R` / `SPACE` / `ENTER` resets the survival phase cleanly.
