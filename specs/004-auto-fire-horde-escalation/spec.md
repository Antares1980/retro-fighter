# Feature Specification: Always-On Auto-Fire Cannons, Uninterrupted Muzzle Volleys, & Aggressive Time-Escalating Enemy Horde

**Feature Branch**: `feat/auto-fire-horde-escalation`

**Created**: 2026-10-23

**Status**: Approved

**Input**: User description: "When I leave press the space button the cannon, at some point, doesn't shoot, I have to wait a few seconds to start again. I want the cannons to shoot always. Remove the space button functionality, the cannons must shoot all the time. review the functionality of the phase to add more and more enemies (increasing the number to increase the difficulty) when the time passes."

## Clarifications

### Session 2026-10-23

- Q: Along with removing SPACE/J manual firing in Cannon3D.gd so cannons auto-fire 100% of the time, how should we ensure the cannons never pause or jam when multiplied bullets hit the 300-mob limit? → A: Enable automatic continuous firing at all times (remove SPACE/J fire controls), despawn blue bullets right past the enemy spawn line (Z < -24.5), and recycle the furthest-downrange bullets when at the 300-mob cap so the cannons never pause shooting.
- Q: How should enemy waves escalate as time passes so the screen fills with enemies and difficulty genuinely increases? → A: Aggressive Horde Escalation: rapidly increase Soldier wave sizes (guaranteed min-to-max squads up to 12–24 soldiers per wave at faster intervals), scale Soldier HP/power upward over time so single bullets don't wipe out 25 soldiers, and spawn more frequent/tougher multi-lane Bosses.
- Q: With cannons now shooting automatically 100% of the time, should we also pace out the cannon/power unlock thresholds, and how should the HUD controls hint be updated? → A: Pace cannon/power upgrades slightly (require a charge threshold to unlock each extra cannon and each power tier so progression lasts longer) and update the HUD hint to 'A/D or ARROWS: STEER | ESC: MENU'.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Always-On Automatic Cannon Firing & Removal of Space Button Fire Control (Priority: P1)

Players steer their cannon squad left and right along the highway using `A`/`D` or `Left`/`Right` Arrow keys while the cannons fire automatically and continuously at a fixed `0.14s` cadence from the moment gameplay starts. Players no longer need to hold or press `SPACE` or `J` to fire, and pressing or releasing `SPACE` or `J` during active gameplay has no effect on cannon firing. The bottom HUD controls hint clearly communicates `"A/D or ARROWS: STEER | ESC: MENU"`.

**Why this priority**: Eliminates manual button-holding fatigue and directly satisfies the core requirement that the cannons shoot at all times without `SPACE` button functionality.

**Independent Test**: Can be tested independently by instantiating the game scene in `PLAYING` state, stepping 1.0 second without any fire input pressed, verifying that 7 volleys are fired automatically, verifying that pressing/releasing `SPACE` or `J` does not stop or reset firing, and checking the HUD `ControlsHint` text.

**Acceptance Scenarios**:

1. **Given** a newly started Mob Control 3D session in `PLAYING` state with zero keyboard fire inputs active, **When** 1.0 second of simulation time elapses, **Then** the player cannon automatically emits 7 shots (1 every `0.14s`).
2. **Given** the cannon auto-firing during `PLAYING` state, **When** the player presses or releases `SPACE` or `J`, **Then** the cannon continues firing uninterrupted without resetting its firing cadence accumulator, and the HUD hint displays `"A/D or ARROWS: STEER | ESC: MENU"`.

---

### User Story 2 - Uninterrupted Muzzle Volleys at the Entity Cap & Tighter Upper-Highway Despawning (Priority: P1)

When 5 active cannons fire through multiplier gates (`x2`, `x3`, `+6`), the highway rapidly fills with up to `300` Blue Mobs (`MAX_MOBS = 300`). Instead of blocking new cannon shots at the muzzle for several seconds while waiting for downrange bullets to travel off-screen to `Z = -35.0`, blue projectiles in Survival Mode despawn immediately upon passing the enemy spawn line (`Z < -24.5`), and whenever a cannon volley is requested while `300` blue projectiles are already active, the furthest-downrange blue projectile (at the top of the highway) is recycled immediately so every active cannon fires its new shot at the muzzle without a single skipped or delayed volley.

**Why this priority**: Directly fixes the multi-second firing pause the user experienced when multiplied bullets saturated the `300`-mob cap.

**Independent Test**: Can be tested independently by pre-populating `300` live Blue Mobs along the highway in Survival Mode, triggering a cannon volley at `0.14s`, and verifying that the furthest-downrange Blue Mob is recycled and the new muzzle volley spawns at `Z = 8.0` without dropping the shot.

**Acceptance Scenarios**:

1. **Given** `300` active Blue Mobs on the highway in Survival Mode (`MAX_MOBS = 300` reached), **When** the cannon auto-fire interval (`0.14s`) triggers a new volley from `N` active cannons (`1..5`), **Then** the `N` furthest-downrange Blue Mobs (lowest `Z` positions) are immediately recycled and `N` fresh Blue Mobs spawn at the cannon muzzles while total live Blue Mobs remain bounded at `300`.
2. **Given** Blue Mobs traveling up the highway in Survival Mode, **When** a Blue Mob's position passes `Z < -24.5` (beyond the enemy spawn zone), **Then** the Blue Mob is immediately freed during bounds cleanup.

---

### User Story 3 - Aggressive Time-Escalating Enemy Horde (Soldiers & Bosses) (Priority: P1)

As survival time (`time_elapsed`) advances, enemy waves escalate aggressively in both numbers and durability so the difficulty continuously rises:
- **Soldier Waves**: Spawn intervals shrink from `1.1s` down to `0.18s`, and both the minimum and maximum squad burst sizes increase over time (from `2–3` soldiers at `0s`, to `5–9` soldiers at `36s`, up to `12–24` soldiers per wave at `90s+`) in staggered multi-lane formations. Furthermore, Soldier durability (`power`/`hp`) scales upward with elapsed time (`1 + floor(time_elapsed / 15.0)`, up to `15`) so a single `Power 25` bullet cannot wipe out 25 soldiers in a row.
- **Boss Waves**: Boss spawn intervals shrink from `9.5s` down to `3.2s`, maximum concurrent active Bosses scale from `1` (`0s`) to `2` (`20s`), `3` (`45s`), `4` (`70s`), and `5` (`100s+`), and Boss health scales with accelerating growth (`160 + floor(8 * t + 0.12 * t^2)`).

**Why this priority**: Ensures the highway does not become empty once the player unlocks 5 cannons and high bullet power, fulfilling the requirement to add more and more enemies as time passes.

**Independent Test**: Can be tested independently by evaluating the escalation functions and stepping the survival spawners at `t = 0s`, `t = 36s`, and `t = 90s`, verifying that Soldier burst bounds, Soldier HP/power, Boss concurrency limits, and Boss HP all scale upward deterministically.

**Acceptance Scenarios**:

1. **Given** the Survival Phase progressing from `t = 0s` to `t = 36s` and `t = 90s`, **When** the Soldier spawner triggers, **Then** the squad size range increases from `2..3` (`0s`) to at least `5..9` (`36s`) and `9..18` (`90s`), and each spawned Soldier's durability (`power`/`hp`) scales from `1` (`0s`) to `3` (`36s`) and `7` (`90s`).
2. **Given** a Blue Bullet with `power = 10` clashing with a scaled Red Soldier of `power = 4` (`hp = 4`), **When** clash resolution executes, **Then** the Red Soldier is defeated and the Blue Bullet's remaining `power` is reduced by `4` (to `6`) rather than only `1`.
3. **Given** the Survival Phase at `t = 45s` and `t = 100s`, **When** the Boss spawner evaluates concurrency and health, **Then** up to `3` (`45s`) and `5` (`100s`) concurrent Bosses are allowed, with Boss HP exceeding `750` at `45s` and `2100` at `100s`.

---

### User Story 4 - Paced Cannon & Bullet Power Upgrade Progression in Survival Mode (Priority: P2)

Because cannons now fire automatically 100% of the time, passing bullets through `xN` multiplier gates in Survival Mode accumulates gate charge toward unlocking additional cannons (`CANNON_UNLOCK_CHARGE_THRESHOLD = 12` hits per extra cannon up to `5/5`) and early bullet power tiers (`GATE_POWER_EARLY_THRESHOLD = 10` charge per tier up to `Power 6`, then `GATE_CHARGE_THRESHOLD = 35` hits per tier up to `Power 25`).

**Why this priority**: Prevents automatic continuous firing from unlocking all 5 cannons within the first 1 second of gameplay while preserving rewarding progression.

**Independent Test**: Can be tested independently by triggering `_on_bullet_hit_multiplier_gate` in Survival Mode and verifying that 12 gate hits unlock Cannon 2 (while preserving legacy instant cannon unlock when `survival_mode == false` for historical test compatibility).

**Acceptance Scenarios**:

1. **Given** a Survival Mode session starting with `1` cannon and `bullet_power = 1`, **When** `11` Blue Mobs pass through an `xN` gate, **Then** the cannon count remains `1` with `gate_power_charge == 11`; **When** the `12th` Blue Mob passes through an `xN` gate, **Then** a second cannon is unlocked (`cannons.size() == 2`) and `gate_power_charge` resets to `0`.

---

### Edge Cases

- **All 300 Blue Mobs Active When 5 Cannons Fire Simultaneously**: `_recycle_furthest_blue_mob()` is invoked once per cannon in the volley (`up to 5 times`), recycling the 5 furthest-downrange bullets so all 5 cannons fire simultaneously while total live Blue Mobs stay at `300`.
- **Gate Duplication at 300-Mob Cap**: While cannon muzzle shots recycle furthest-downrange bullets to guarantee uninterrupted firing, multiplier gate cloning (`on_mob_entered_gate`) continues to respect `remaining_space = MAX_MOBS - (get_live_blue_mobs_count() + pending_spawns)` so gate duplication never causes unbounded entity growth.
- **Legacy Stage Mode Compatibility (`survival_mode == false`)**: When `init_stage(stage_idx)` is called by legacy test scenarios (`Scenarios 1–16`), `survival_mode` is `false` and legacy stage cleanup bounds (`highway_min_z - 3.0`) and gate upgrade rules remain intact.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `Cannon3D` MUST fire automatically and continuously at `FIRE_INTERVAL = 0.14s` during `GameState.PLAYING` (`auto_fire = true` by default) without requiring `SPACE`, `J`, `mc_fire`, or `p1_punch` input.
- **FR-002**: Pressing or releasing `SPACE` or `J` during `GameState.PLAYING` MUST NOT stop, pause, or reset `Cannon3D.fire_accumulator` when `auto_fire` is enabled.
- **FR-003**: `UI/ControlsHint` in `MobControlMain.tscn` and `MobControlMain.gd` MUST display `"A/D or ARROWS: STEER | ESC: MENU"`.
- **FR-004**: In Survival Mode (`survival_mode == true`), `get_cleanup_bound_z()` MUST return `SURVIVAL_CLEANUP_BOUND_Z = -24.5` so Blue Mobs despawn immediately after passing the enemy spawn zone.
- **FR-005**: In Survival Mode, `_on_cannon_shoot_requested()` MUST never drop or skip a cannon muzzle shot when `get_live_blue_mobs_count() + pending_spawns >= MAX_MOBS`; instead, it MUST call `_recycle_furthest_blue_mob()` to free the live Blue Mob with the lowest `Z` coordinate before spawning the new cannon shot.
- **FR-006**: In Survival Mode, unlocking each additional cannon (`1 -> 5`) via `_on_bullet_hit_multiplier_gate()` MUST require `CANNON_UNLOCK_CHARGE_THRESHOLD = 12` gate hits, and upgrading `bullet_power` from `1 -> 6` MUST require `GATE_POWER_EARLY_THRESHOLD = 10` charge points per level before transitioning to `GATE_CHARGE_THRESHOLD = 35` for levels `6 -> 25`.
- **FR-007**: Soldier wave spawning in Survival Mode MUST scale both minimum and maximum burst sizes over `time_elapsed` via `get_soldier_min_burst(elapsed)` (reaching `>= 5` at `36s` and `>= 9` at `90s`) and `get_soldier_max_burst(elapsed)` (reaching `>= 9` at `36s` and `>= 18` at `90s`), with spawn intervals shrinking from `SOLDIER_BASE_INTERVAL = 1.1` down to `SOLDIER_MIN_INTERVAL = 0.18`.
- **FR-008**: Spawned Red Soldiers in Survival Mode MUST scale their `power` (`hp`) with `time_elapsed` via `get_scaled_soldier_power(elapsed)` (`1 + int(floor(elapsed / 15.0))`, capped at `15`) so each Soldier absorbs `red.power` points of Blue Bullet power in `on_mob_clash()`.
- **FR-009**: Boss spawning in Survival Mode MUST scale `get_max_concurrent_bosses(elapsed)` from `1` (`0s`) to `2` (`20s`), `3` (`45s`), `4` (`70s`), and `5` (`100s+`), shorten intervals from `BOSS_BASE_INTERVAL = 9.5` down to `BOSS_MIN_INTERVAL = 3.2`, and scale Boss HP via `get_scaled_boss_hp(elapsed)` (`160 + int(floor(elapsed * 8.0 + elapsed * elapsed * 0.12))`).
- **FR-010**: All legacy stage tests (`Scenarios 1–16`) and Survival Mode tests (`Scenario 17`) MUST pass with zero regressions.

### Key Entities

- **Auto-Firing Player Cannon (`Cannon3D`)**: Wheeled 3D cannon with `auto_fire: bool = true` that steers along `X` via `A`/`D` or Arrow keys and emits `shoot_requested` every `0.14s` continuously.
- **Downrange Bullet Recycler (`MobControlMain._recycle_furthest_blue_mob`)**: Ensures uninterrupted muzzle firing at `MAX_MOBS = 300` by recycling the live Blue Mob furthest down the highway (`lowest Z`).
- **Scaled Red Soldier (`MobUnit3D`)**: Articulated 3D robot raider whose squad burst size (`2..24`) and per-unit `power`/`hp` (`1..15`) scale upward with `time_elapsed`.
- **Escalating Lane Boss (`GiantEnemy3D`)**: Lane-sized 3D Armored Mech whose spawn cadence, concurrent cap (`1..5`), and health pool scale nonlinearly with `time_elapsed`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Player cannons fire continuously at `7` volleys per second (`0.14s` interval) with zero keyboard fire inputs pressed, and never experience a firing gap greater than `0.15s` even when `300` Blue Mobs are active on the highway.
- **SC-002**: In Survival Mode, 100% of Blue Mobs reaching `Z < -24.5` are despawned on the next cleanup pass, eliminating multi-second off-screen projectile accumulation.
- **SC-003**: By `36s` of survival time, Soldier wave burst capacity increases to `5–9` soldiers per wave with `3 HP` each (`15–27` total wave HP vs. `1–4` total wave HP previously), and by `90s` reaches `9–18` soldiers per wave with `7 HP` each (`63–126` total wave HP per burst).
- **SC-004**: 100% of automated test suites (`python -m unittest discover -s tests` and `godot --headless -s res://tests/test_runner.gd`) pass with 0 failures and 0 script errors.

## Assumptions

- `Cannon3D` retains `var fire_held: bool = false` so any legacy unit test that explicitly sets `cannon.auto_fire = false` to test manual start/stop cadence (`Scenario 2` release test) can still verify manual accumulator reset deterministically, while `auto_fire = true` is the default for all normal gameplay.
- Legacy multi-stage mode (`survival_mode == false` via `init_stage()`) preserves immediate cannon unlocking on `xN` gate hits so `Scenario 15` and `Scenario 16` remain 100% compatible.
