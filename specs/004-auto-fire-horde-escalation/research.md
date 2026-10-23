# Phase 0 Research: Always-On Auto-Fire Cannons, Uninterrupted Muzzle Volleys, & Aggressive Time-Escalating Enemy Horde

## 1. Root Cause of Multi-Second Cannon Firing Pauses & Auto-Fire Design

- **Decision**:
  1. Set `@export var auto_fire: bool = true` by default in `Cannon3D.gd` so `effective_fire` is always `true` during gameplay without requiring `SPACE`, `J`, `mc_fire`, or `p1_punch` input.
  2. Tighten `get_cleanup_bound_z()` in `survival_mode` from `-35.0` to `SURVIVAL_CLEANUP_BOUND_Z = -24.5` (right past the enemy spawn line at `Z = -22.0..-23.5`).
  3. Add `_recycle_furthest_blue_mob() -> bool` in `MobControlMain.gd` and invoke it inside `_on_cannon_shoot_requested()` whenever `survival_mode == true` and `get_live_blue_mobs_count() + pending_spawns >= MAX_MOBS` (`300`), freeing the live `MobUnit3D` with the lowest (most negative / furthest downrange) `position.z` so every active cannon in the squad (`1..5`) fires its new bullet at the muzzle without ever stalling.
- **Rationale**:
  - Previously, when 5 cannons shot through `x2`/`x3`/`+6` gates, `blue_mobs` hit `MAX_MOBS = 300` within ~1.5 seconds. Because `_on_cannon_shoot_requested()` broke out of its loop when `get_live_blue_mobs_count() + pending_spawns >= MAX_MOBS`, and surviving bullets had to travel all the way to `Z = -35.0` at `-9.0` units/sec before being freed, the cannons stopped shooting completely for 2–4 seconds until the old wave cleared `-35.0`.
  - Recycling the furthest-downrange bullet at the top of the screen while despawning bullets at `Z < -24.5` guarantees 100% uninterrupted muzzle firing at `MAX_MOBS = 300` with zero framerate degradation.
  - Keeping `var fire_held: bool = false` and honoring `auto_fire = false` when explicitly set by legacy tests (`Scenario 2`, `Scenario 7`, `Scenario 8`) preserves deterministic testability of manual start/stop accumulator logic when `auto_fire` is toggled off.
- **Alternatives Considered**:
  - Increasing `MAX_MOBS` to `800+`: Rejected because exponential gate multiplication (`x3` into `x4`) would still reach `800` within a few seconds while tripling scene node and collision overhead.

## 2. Aggressive Time-Escalating Enemy Horde (Soldiers & Bosses)

- **Decision**:
  - **Soldier Wave Frequency & Burst Size**:
    - `SOLDIER_BASE_INTERVAL = 1.1` (down from `1.4`), `SOLDIER_MIN_INTERVAL = 0.18` (down from `0.28`).
    - `get_soldier_min_burst(elapsed: float) -> int`: `mini(12, 2 + int(floor(maxf(0.0, elapsed) / 12.0)))` (`2` at `0s`, `5` at `36s`, `9` at `90s`, `12` at `120s+`).
    - `get_soldier_max_burst(elapsed: float) -> int`: `mini(24, 3 + int(floor(maxf(0.0, elapsed) / 6.0)))` (`3` at `0s`, `9` at `36s`, `18` at `90s`, `24` at `126s+`).
  - **Soldier Durability (`power` / `hp`) Scaling**:
    - `get_scaled_soldier_power(elapsed: float) -> int`: `mini(15, 1 + int(floor(maxf(0.0, elapsed) / 15.0)))` (`1` at `0s`, `3` at `36s`, `7` at `90s`, `15` at `210s+`).
    - Pass `get_scaled_soldier_power(time_elapsed)` into `r_mob.setup("red", s_pwr)` in `_step_survival_spawners()`. Because `on_mob_clash()` already computes `var red_hp: int = maxi(1, red.power)` and subtracts `red_hp` from `blue.power`, scaling `red.power` directly makes each Soldier absorb `s_pwr` points of bullet power!
  - **Boss Concurrency, Frequency, & Quadratic HP Scaling**:
    - `BOSS_BASE_INTERVAL = 9.5` (down from `14.0`), `BOSS_MIN_INTERVAL = 3.2` (down from `5.5`).
    - `get_max_concurrent_bosses(elapsed: float) -> int`: `1` (`<20s`), `2` (`20..44.9s`), `3` (`45..69.9s`), `4` (`70..99.9s`), `5` (`>=100s`).
    - `get_scaled_boss_hp(elapsed: float) -> int`: `BOSS_BASE_HP + int(floor(t * 8.0 + t * t * 0.12))` where `BOSS_BASE_HP = 160` (`160` at `0s`, `603` at `36s`, `2052` at `90s`).
- **Rationale**:
  - Previously, Soldiers had `1 HP` forever and spawned `1–4` at a time at `t = 36s`, so a single `Power 25` yellow bullet killed 25 Soldiers and cleared the entire highway. Scaling both squad numbers (`up to 12–24 per wave`) and Soldier `power`/`hp` (`1..15`), alongside faster multi-lane Bosses with quadratic HP growth, ensures enemy waves visually fill the highway and challenge even a maxed-out 5-cannon squad.
- **Alternatives Considered**:
  - Keeping Soldiers at `1 HP` and spawning 100+ Soldiers per second: Rejected because instantiating 100+ articulated 7-mesh 3D humanoid rigs per second causes unnecessary node churn compared to spawning `12–24` multi-HP raiders per wave.

## 3. Paced Cannon & Bullet Power Progression in Survival Mode

- **Decision**:
  - Define `CANNON_UNLOCK_CHARGE_THRESHOLD: int = 12` and `GATE_POWER_EARLY_THRESHOLD: int = 10`.
  - When `survival_mode == true`, `_on_bullet_hit_multiplier_gate(mult_value)` increments `gate_power_charge` and requires `12` hits per extra cannon (`1 -> 2 -> 3 -> 4 -> 5`), `10` charge points (`+mult_value` per hit) per early power tier (`1 -> 6`), and `35` hits per late power tier (`6 -> 25`).
  - When `survival_mode == false` (legacy `init_stage()` mode), preserve immediate cannon unlocks so `Scenario 15` and `Scenario 16` pass without modification.
- **Rationale**:
  - With `auto_fire = true` from `t = 0s`, the player fires 7 bullets/sec immediately; requiring 12 gate hits per extra cannon spaces out cannon unlocks across the first 15–25 seconds of survival play rather than unlocking all 5 cannons in the first 0.5 seconds.
