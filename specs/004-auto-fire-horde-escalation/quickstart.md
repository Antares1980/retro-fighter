# Quickstart & Validation Guide: Always-On Auto-Fire Cannons, Uninterrupted Muzzle Volleys, & Aggressive Time-Escalating Enemy Horde

## Prerequisites

- Python 3.11+
- Godot Engine 4.3 (console/headless binary on `PATH` or installed via WinGet)

## Automated Validation Commands

### 1. Run Python Static & Contract Test Suite

```powershell
python -m unittest discover -s tests -v
```

**Expected Outcome**: All unit tests in `tests/test_mob_control.py` (and sibling 2D suites) pass (`OK`), verifying:
- `UI/ControlsHint` displays `"A/D or ARROWS: STEER | ESC: MENU"`
- `Cannon3D.gd` defines `var auto_fire: bool = true`
- `MobControlMain.gd` defines `SURVIVAL_CLEANUP_BOUND_Z = -24.5`, `_recycle_furthest_blue_mob()`, `CANNON_UNLOCK_CHARGE_THRESHOLD = 12`, `get_soldier_min_burst()`, `get_soldier_max_burst()`, and `get_scaled_soldier_power()`
- Cold-cache headless compilation check passes with `0` parse/type errors

### 2. Run Godot 4.3 Headless Runtime Suite

```powershell
godot --headless -s res://tests/test_runner.gd
```

**Expected Outcome**: All registered test suites pass (`0 failed`), including `TestMobControl` `Scenarios 1–18`:
- **GWT 1**: Cannons fire automatically every `0.14s` with zero fire keys pressed, and `UI/ControlsHint` shows `"A/D or ARROWS: STEER | ESC: MENU"`.
- **GWT 2**: When `300` live Blue Mobs are on the highway in Survival Mode, `_recycle_furthest_blue_mob()` recycles the furthest-downrange bullet so cannon muzzle volleys never pause, and Blue Mobs past `Z < -24.5` despawn on cleanup.
- **GWT 3**: Soldier wave burst sizes (`get_soldier_min_burst`, `get_soldier_max_burst`) and Soldier durability (`get_scaled_soldier_power`) escalate with `time_elapsed`, and scaled Soldiers subtract their full `power` from clashing Blue Bullets.
- **GWT 4**: Boss concurrency (`get_max_concurrent_bosses` up to `5`) and quadratic Boss HP (`get_scaled_boss_hp`) scale with `time_elapsed`.
- **GWT 5**: Survival Mode paces extra cannon unlocks (`12` `xN` gate hits per cannon) while legacy stage mode (`init_stage`) preserves `Scenarios 1–16`.
