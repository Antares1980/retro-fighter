# Phase 1 Data Model: Always-On Auto-Fire Cannons, Uninterrupted Muzzle Volleys, & Aggressive Time-Escalating Enemy Horde

## Entities & State Properties

### 1. `Cannon3D` (`scripts/mob_control/Cannon3D.gd`)

| Property / Constant | Type | Default / Value | Constraints & Behavior |
|---|---|---|---|
| `FIRE_INTERVAL` | `float` (const) | `0.14` | Fixed time step (`s`) between consecutive cannon volleys (`~7.14` volleys/s). |
| `auto_fire` | `bool` (`@export`) | `true` | When `true`, `Cannon3D.step(delta)` advances `fire_accumulator` and emits `shoot_requested` every `0.14s` continuously without keyboard/action fire input. |
| `fire_held` | `bool` | `false` | Legacy manual fire flag; used only when `auto_fire == false` in isolated manual-cadence unit tests. |
| `fire_accumulator` | `float` | `0.0` | Accumulates `delta` while `auto_fire or fire_held` is true; decrements by `FIRE_INTERVAL` on each shot. |
| `move_input` | `float` | `0.0` | Horizontal steering input (`[-1.0, +1.0]`), combined with `A`/`D` and `Left`/`Right` Arrow keys. |

### 2. `MobControlMain` (`scripts/mob_control/MobControlMain.gd`)

| Property / Constant | Type | Default / Value | Constraints & Behavior |
|---|---|---|---|
| `MAX_MOBS` | `int` (const) | `300` | Maximum concurrent live + pending Blue Mobs on the highway. |
| `SURVIVAL_CLEANUP_BOUND_Z` | `float` (const) | `-24.5` | Upper-highway Z bound in `survival_mode` beyond which Blue Mobs immediately despawn. |
| `CANNON_UNLOCK_CHARGE_THRESHOLD` | `int` (const) | `12` | Number of `xN` gate hits required in `survival_mode` to unlock each additional cannon (`1 -> 5`). |
| `GATE_POWER_EARLY_THRESHOLD` | `int` (const) | `10` | Gate charge points (`+mult_value` per hit) required per `bullet_power` level from `1 -> 6` in `survival_mode`. |
| `GATE_CHARGE_THRESHOLD` | `int` (const) | `35` | Gate hits required per `bullet_power` level from `6 -> 25`. |
| `SOLDIER_BASE_INTERVAL` | `float` (const) | `1.1` | Initial Soldier wave spawn interval (`s`) at `t = 0s`. |
| `SOLDIER_MIN_INTERVAL` | `float` (const) | `0.18` | Minimum floor for Soldier wave spawn interval (`s`). |
| `BOSS_BASE_INTERVAL` | `float` (const) | `9.5` | Initial Boss spawn interval (`s`) at `t = 0s`. |
| `BOSS_MIN_INTERVAL` | `float` (const) | `3.2` | Minimum floor for Boss spawn interval (`s`). |
| `BOSS_BASE_HP` | `int` (const) | `160` | Base health of an advancing Survival Boss at `t = 0s`. |

### 3. Escalation Functions (`MobControlMain.gd`)

| Function Signature | Formula / Output Range | Description |
|---|---|---|
| `get_soldier_min_burst(elapsed: float) -> int` | `mini(12, 2 + int(floor(maxf(0.0, elapsed) / 12.0)))` | Minimum Soldiers spawned per wave (`2` at `0s`, `5` at `36s`, `9` at `90s`, `12` max). |
| `get_soldier_max_burst(elapsed: float) -> int` | `mini(24, 3 + int(floor(maxf(0.0, elapsed) / 6.0)))` | Maximum Soldiers spawned per wave (`3` at `0s`, `9` at `36s`, `18` at `90s`, `24` max). |
| `get_scaled_soldier_power(elapsed: float) -> int` | `mini(15, 1 + int(floor(maxf(0.0, elapsed) / 15.0)))` | Soldier `power` and `hp` (`1` at `0s`, `3` at `36s`, `7` at `90s`, `15` max). |
| `get_max_concurrent_bosses(elapsed: float) -> int` | `1` (`<20s`), `2` (`>=20s`), `3` (`>=45s`), `4` (`>=70s`), `5` (`>=100s`) | Maximum simultaneous active Bosses in `active_bosses`. |
| `get_scaled_boss_hp(elapsed: float) -> int` | `BOSS_BASE_HP + int(floor(t * 8.0 + t * t * 0.12))` | Boss HP scaling nonlinearly with survival time (`160` at `0s`, `603` at `36s`, `2052` at `90s`). |
| `_recycle_furthest_blue_mob() -> bool` | Frees live `blue_mob` with minimum `position.z` | Invoked by `_on_cannon_shoot_requested()` when `survival_mode` is at `MAX_MOBS = 300` so cannon muzzle shots never pause. |
