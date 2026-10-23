# Contracts: Always-On Auto-Fire Cannons, Uninterrupted Muzzle Volleys, & Aggressive Time-Escalating Enemy Horde

## 1. Scene & UI Contract (`scenes/mob_control/MobControlMain.tscn`)

- `UI/ControlsHint` (`Label`):
  - `text = "A/D or ARROWS: STEER | ESC: MENU"`
  - Must not instruct the player to hold `SPACE` or `J` to fire.

## 2. Cannon Auto-Fire Contract (`scripts/mob_control/Cannon3D.gd`)

- `@export var auto_fire: bool = true`
- `func step(delta: float) -> void`:
  - Computes `var effective_fire: bool = auto_fire or fire_held or ...` (when `auto_fire == true`, fires continuously every `FIRE_INTERVAL = 0.14` seconds without any key press).
  - Releasing or pressing `KEY_SPACE` or `KEY_J` while `auto_fire == true` does NOT reset `fire_accumulator` to `0.0`.
- `func reset() -> void`:
  - Resets `position = Vector3(0.0, 0.5, 9.0)`, `move_input = 0.0`, `fire_held = false`, `fire_accumulator = 0.0`.

## 3. Uninterrupted Muzzle Volley & Bounds Cleanup Contract (`scripts/mob_control/MobControlMain.gd`)

- `const SURVIVAL_CLEANUP_BOUND_Z: float = -24.5`
- `func get_cleanup_bound_z() -> float`:
  - Returns `SURVIVAL_CLEANUP_BOUND_Z` (`-24.5`) when `survival_mode == true`, and `highway_min_z - 3.0` when `survival_mode == false`.
- `func _recycle_furthest_blue_mob() -> bool`:
  - Scans `blue_mobs` for the live `MobUnit3D` with the minimum (most negative) `position.z`, marks `is_consumed = true`, calls `queue_free()`, removes it from `blue_mobs`, and returns `true`.
- `func _on_cannon_shoot_requested(muzzle_pos: Vector3) -> void`:
  - When `survival_mode == true` and `get_live_blue_mobs_count() + pending_spawns >= MAX_MOBS`, calls `_recycle_furthest_blue_mob()` before spawning each cannon's shot so all active cannons (`1..5`) fire every `0.14s` without interruption.

## 4. Paced Upgrade & Aggressive Horde Escalation Contract (`scripts/mob_control/MobControlMain.gd`)

- `const CANNON_UNLOCK_CHARGE_THRESHOLD: int = 12`
- `const GATE_POWER_EARLY_THRESHOLD: int = 10`
- `const SOLDIER_BASE_INTERVAL: float = 1.1`
- `const SOLDIER_MIN_INTERVAL: float = 0.18`
- `const BOSS_BASE_INTERVAL: float = 9.5`
- `const BOSS_MIN_INTERVAL: float = 3.2`
- `const BOSS_BASE_HP: int = 160`
- `func get_soldier_min_burst(elapsed: float) -> int`
- `func get_soldier_max_burst(elapsed: float) -> int`
- `func get_scaled_soldier_power(elapsed: float) -> int`
- `func get_max_concurrent_bosses(elapsed: float) -> int`
- `func get_scaled_boss_hp(elapsed: float) -> int`
