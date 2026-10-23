# 📋 Implementation Plan & Refinement Lifecycle: Mob Control 3D — Always-On Auto-Fire Cannons, Uninterrupted Muzzle Volleys, & Aggressive Time-Escalating Enemy Horde

## 📝 Initial Draft Proposal

User Request (`/grill-me`):
> "I want you to help me writing a new requirement. When I leave press the space button the cannon, at some point, doesn't shoot, I have to wait a few seconds to start again. I want the cannons to shoot always. Remove the space button functionality, the cannons must shoot all the time. review the functionality of the phase to add more and more enemies (increasing the number to increase the difficulty) when the time passes."

### Root-Cause Diagnosis & Clarified Design Decisions (Operator `/grill-me` Interview Consensus)

1. **Always-On Automatic Cannon Firing & Removal of Space Button Fire Control:**
   - **Root Cause of Firing Pause:** In the previous implementation, when 5 cannons fired through multiplier gates (`x2`, `x3`, `+6`), live blue bullets quickly reached `MAX_MOBS = 300`. Once at 300 mobs, `_on_cannon_shoot_requested()` hit `if get_live_blue_mobs_count() + pending_spawns >= MAX_MOBS: break`, completely blocking all cannon muzzle shots for several seconds while the existing 300 bullets traveled all the way to `Z = -35.0` (far beyond the visible highway and enemy spawn line at `Z = -22.0`).
   - **Decision:**
     - **Remove Manual Fire Input (`SPACE` / `J`):** Cannons now shoot **automatically and continuously 100% of the time** during `GameState.PLAYING` (`auto_fire = true` by default in `Cannon3D.gd`) at every `FIRE_INTERVAL = 0.14s` tick without pressing `SPACE` or `J`.
     - **HUD Controls Hint Update:** Update `ControlsHint` in `MobControlMain.tscn` and `MobControlMain.gd` to `"A/D or ARROWS: STEER | ESC: MENU"`.
     - **Tighter Upper-Highway Despawn Bound:** In `survival_mode`, tighten `get_cleanup_bound_z()` from `-35.0` to `SURVIVAL_CLEANUP_BOUND_Z = -24.5` (immediately past the enemy spawn zone at `Z = -22.0..-23.5`) so bullets that clear the highway despawn right at the top edge of the screen.
     - **Downrange Bullet Recycling (Zero Muzzle Jamming):** In `_on_cannon_shoot_requested()`, cannon muzzle shots are **never blocked** by `MAX_MOBS`. Whenever spawning a cannon volley would exceed `MAX_MOBS = 300`, `_recycle_furthest_blue_mob()` immediately frees the furthest-downrange live blue bullet (lowest `Z` coordinate at the top of the road) to make room for the fresh cannon shot at the muzzle.

2. **Aggressive Time-Escalating Enemy Horde (Soldiers & Bosses):**
   - **Root Cause of Low Late-Phase Difficulty:** Previously, at `00:36` survival time, the player already had `5/5 CANNONS` and `BULLET POWER: 25` (~3,000+ DPS after gates), while the spawner only generated `1–4` Soldiers (`1 HP` each) every `~1.1s` and 1 Boss (`~300 HP`) every `~12s`. Because `on_mob_clash()` subtracts `red_hp` from `blue_pwr`, a single `Power 25` yellow bullet plowed through **25 `1-HP` Soldiers** before expiring, leaving the highway completely empty of enemies.
   - **Decision (Aggressive Horde Escalation):**
     - **Escalating Soldier Wave Size & Frequency:**
       - Decrease `SOLDIER_BASE_INTERVAL` to `1.1s` and `SOLDIER_MIN_INTERVAL` to `0.18s`.
       - Scale **both minimum and maximum** Soldier burst sizes (`get_soldier_min_burst(elapsed)` and `get_soldier_max_burst(elapsed)`) so waves grow from `2–3` soldiers at `t = 0s`, to `6–11` soldiers at `t = 36s`, up to `12–24` soldiers per burst by `t = 90s+`, spawned in multi-lane staggered formations across `X in [-3.8, +3.8]`.
     - **Escalating Soldier HP / Power (`get_scaled_soldier_power(elapsed)`):**
       - Scale Red Soldier `power` (`hp`) upward with survival time (`1 + int(floor(elapsed / 15.0))`, capped at `15`) so advancing soldiers absorb proportionally more bullet power in `on_mob_clash()` and cannot be wiped out 25-for-1 by a single bullet.
     - **Escalating Multi-Lane Bosses:**
       - Shorten Boss spawn intervals (`BOSS_BASE_INTERVAL = 9.5s` down to `BOSS_MIN_INTERVAL = 3.2s`).
       - Scale concurrent active Boss cap (`get_max_concurrent_bosses(elapsed)`) up to `5` simultaneous Bosses (`1` at `0s`, `2` at `20s`, `3` at `45s`, `4` at `70s`, `5` at `100s+`).
       - Scale Boss HP (`get_scaled_boss_hp(elapsed)`) with accelerating time growth (`160 + int(floor(elapsed * 8.0 + elapsed * elapsed * 0.12))`) so Bosses remain formidable lane threats as time passes.

3. **Paced Cannon & Bullet Power Upgrade Progression:**
   - **Decision:** Because cannons now fire non-stop from `t = 0.0s`, pace out the `xN` gate upgrade curve in `survival_mode` so the player does not unlock all `5/5 CANNONS` in the first second of play:
     - Require `CANNON_UNLOCK_CHARGE_THRESHOLD: int = 12` gate hits per additional cannon (`1 -> 2 -> 3 -> 4 -> 5`) in `survival_mode`, followed by `GATE_POWER_EARLY_THRESHOLD: int = 10` gate hits per power level for tiers `1 -> 6`, and `GATE_CHARGE_THRESHOLD: int = 35` gate hits per power level for tiers `6 -> 25`.

---

## 🎯 Final Decision Plan & User Story Specification

- **Resolution Type:** Consensus Agreement (Operator `/grill-me` Interview)
- **User Story:** As a player of **Mob Control 3D**, I want the cannons to fire automatically and continuously at all times without pressing `SPACE` or `J`, with zero firing pauses or muzzle jams even when multiplied bullets reach the highway cap, while facing an aggressively escalating horde of Soldiers and Bosses whose numbers, spawn frequency, and durability increase continuously as survival time passes.

### Architecture & Data Flow

```mermaid
flowchart TD
    subgraph AutoFireLoop["1. Always-On Auto-Fire & Uninterrupted Muzzle Volleys"]
        Step["Cannon3D.step(delta)\nSteer Left/Right via A/D or Arrows\nauto_fire == true (SPACE/J fire removed)"] --> Cadence{"fire_accumulator >= 0.14s?"}
        Cadence -->|Yes| EmitShoot["shoot_requested.emit(muzzle_pos)"]
        EmitShoot --> CapCheck{"live_blue_mobs >= MAX_MOBS (300)?"}
        CapCheck -->|Yes| Recycle["_recycle_furthest_blue_mob()\nFree blue mob with lowest Z (top of road)"]
        CapCheck -->|No| SpawnVolley["_spawn_blue_mob() for each active cannon (1..5)"]
        Recycle --> SpawnVolley
        SpawnVolley --> Cleanup["Phase 4 Bounds Cleanup:\nDespawn blue mobs at Z < -24.5 (SURVIVAL_CLEANUP_BOUND_Z)"]
    end

    subgraph PacedUpgrades["2. Paced Cannon & Bullet Power Progression"]
        GateHit["Blue bullet passes xN Gate\n_on_bullet_hit_multiplier_gate(mult_val)"] --> CannonCheck{"cannons.size() < 5?"}
        CannonCheck -->|Yes (Survival)| CannonCharge["gate_power_charge += 1\nAt >= 12 hits: _add_cannon()"]
        CannonCheck -->|No| PowerCharge["Accumulate gate_power_charge\nUpgrade bullet_power up to MAX_BULLET_POWER (25)"]
    end

    subgraph HordeEscalation["3. Aggressive Time-Escalating Enemy Horde"]
        Timer["time_elapsed advances every step(delta)"] --> SoldierWave["Soldier Spawner:\nInterval shrinks 1.1s -> 0.18s\nBurst grows from 2..3 up to 12..24 soldiers\nSoldier HP/Power scales: 1 + floor(t / 15s)"]
        Timer --> BossWave["Boss Spawner:\nInterval shrinks 9.5s -> 3.2s\nConcurrent Bosses scale 1 -> 5\nBoss HP scales: 160 + floor(8t + 0.12t²)"]
    end
```

### Technical Specifications

#### 1. Always-On Auto-Fire & Space Button Removal (`scripts/mob_control/Cannon3D.gd`, `scenes/mob_control/MobControlMain.tscn`, `scripts/mob_control/MobControlMain.gd`)
- **`Cannon3D.gd` Auto-Fire Mechanics:**
  - Add `@export var auto_fire: bool = true` to `Cannon3D` (true by default).
  - Remove `KEY_SPACE`, `KEY_J`, `mc_fire`, and `p1_punch` from triggering firing in `Cannon3D.step(delta)`.
  - In `Cannon3D.step(delta)`:
    - `var effective_fire: bool = auto_fire or fire_held`
    - When `effective_fire` is true (which is always true during normal gameplay since `auto_fire = true`), `fire_accumulator` advances by `delta` every tick and emits `shoot_requested(muzzle_pos)` every `FIRE_INTERVAL = 0.14s` using a `while fire_accumulator >= FIRE_INTERVAL:` loop so no fractional time is lost.
  - In `Cannon3D.reset()`: preserve `auto_fire = true`, reset `position = Vector3(0.0, 0.5, 9.0)`, `move_input = 0.0`, `fire_held = false`, `fire_accumulator = 0.0`.
- **HUD Controls Hint Update (`MobControlMain.tscn` & `MobControlMain.gd`):**
  - Update `UI/ControlsHint` text in `MobControlMain.tscn` (and ensure `_resolve_nodes()` / `init_survival_phase()` maintains it) to:
    `"A/D or ARROWS: STEER | ESC: MENU"`
  - On terminal banners (`GameState.DEFEAT`, `GameState.STAGE_CLEAR`, `GameState.VICTORY`), `KEY_R` and `KEY_ENTER` (and `KEY_SPACE` only for legacy stage clear/retry compatibility if required by existing tests) remain handled in `_unhandled_input(event)`, while during `GameState.PLAYING` pressing or releasing `SPACE` has zero effect on cannon firing.

#### 2. Uninterrupted Muzzle Volleys: Tighter Despawn Bound & Downrange Recycling (`scripts/mob_control/MobControlMain.gd`)
- **Upper-Highway Despawn Bound (`SURVIVAL_CLEANUP_BOUND_Z`):**
  - Define `const SURVIVAL_CLEANUP_BOUND_Z: float = -24.5`.
  - In `get_cleanup_bound_z() -> float`:
    - When `survival_mode == true`, return `SURVIVAL_CLEANUP_BOUND_Z` (`-24.5`) so blue bullets that pass the enemy spawn zone (`Z = -22.0..-23.5`) are immediately cleaned up instead of traveling off-screen to `-35.0`.
    - When `survival_mode == false` (legacy multi-stage mode), continue returning `highway_min_z - 3.0` so all legacy stage depth tests (`Scenario 10`) pass unmodified.
- **Downrange Bullet Recycling (`_recycle_furthest_blue_mob()`):**
  - Add `func _recycle_furthest_blue_mob() -> bool:` which finds the live `MobUnit3D` in `blue_mobs` with the smallest (most negative / furthest downrange) `position.z`, marks `is_consumed = true`, calls `queue_free()`, and removes it from `blue_mobs`.
  - In `_on_cannon_shoot_requested(muzzle_pos: Vector3)`:
    - When `survival_mode == true` (or when `auto_fire` is active), if `get_live_blue_mobs_count() + pending_spawns >= MAX_MOBS`, call `_recycle_furthest_blue_mob()` before spawning each cannon's shot so **every active cannon (`1..5`) always fires its bullet at the muzzle without ever stalling or waiting**.
    - (Note: If all 300 blue mobs are at the exact same Z or `blue_mobs` was artificially pre-populated at `Z = 0.0` in legacy `Scenario 2` cap test with `survival_mode == false`, preserve legacy cap behavior when `survival_mode == false` so `Scenario 2` passes 100%).

#### 3. Paced Cannon & Bullet Power Progression (`scripts/mob_control/MobControlMain.gd`)
- Define `const CANNON_UNLOCK_CHARGE_THRESHOLD: int = 12` and `const GATE_POWER_EARLY_THRESHOLD: int = 10`.
- In `_on_bullet_hit_multiplier_gate(mult_value: int)`:
  - When `survival_mode == true`:
    - If `cannons.size() < MAX_CANNONS`:
      - Increment `gate_power_charge += 1`.
      - When `gate_power_charge >= CANNON_UNLOCK_CHARGE_THRESHOLD`: subtract `CANNON_UNLOCK_CHARGE_THRESHOLD` and call `_add_cannon()`.
    - Else if `bullet_power < 6`:
      - Increment `gate_power_charge += maxi(1, mult_value)`.
      - When `gate_power_charge >= GATE_POWER_EARLY_THRESHOLD`: subtract `GATE_POWER_EARLY_THRESHOLD`, increment `bullet_power = mini(6, bullet_power + 1)`, and call `_update_cannon_status_ui()`.
    - Else if `bullet_power < MAX_BULLET_POWER`:
      - Increment `gate_power_charge += 1`.
      - When `gate_power_charge >= GATE_CHARGE_THRESHOLD`: subtract `GATE_CHARGE_THRESHOLD`, increment `bullet_power = mini(MAX_BULLET_POWER, bullet_power + 1)`, and call `_update_cannon_status_ui()`.
  - When `survival_mode == false` (legacy stage mode used by `Scenario 15` and `Scenario 16`):
    - Keep the immediate cannon unlock on `xN` hit and `+mult_value` jump to tier 6 followed by `GATE_CHARGE_THRESHOLD = 35` so `Scenario 15` and `Scenario 16` pass without regression.

#### 4. Aggressive Time-Escalating Enemy Spawners (`scripts/mob_control/MobControlMain.gd`)
- Update survival escalation constants and helper functions:
  - `const SOLDIER_BASE_INTERVAL: float = 1.1`
  - `const SOLDIER_MIN_INTERVAL: float = 0.18`
  - `const BOSS_BASE_INTERVAL: float = 9.5`
  - `const BOSS_MIN_INTERVAL: float = 3.2`
  - `func get_soldier_min_burst(elapsed: float) -> int:`
    $$\text{min\_burst} = \min\left(12,\; 2 + \lfloor \max(0.0, \text{elapsed}) / 12.0 \rfloor\right)$$
  - `func get_soldier_max_burst(elapsed: float) -> int:`
    $$\text{max\_burst} = \min\left(24,\; 3 + \lfloor \max(0.0, \text{elapsed}) / 6.0 \rfloor\right)$$
  - `func get_scaled_soldier_power(elapsed: float) -> int:`
    $$\text{soldier\_power} = \min\left(15,\; 1 + \lfloor \max(0.0, \text{elapsed}) / 15.0 \rfloor\right)$$
  - `func get_max_concurrent_bosses(elapsed: float) -> int:`
    - `elapsed >= 100.0` $\rightarrow 5$
    - `elapsed >= 70.0` $\rightarrow 4$
    - `elapsed >= 45.0` $\rightarrow 3$
    - `elapsed >= 20.0` $\rightarrow 2$
    - Otherwise $\rightarrow 1$
  - `func get_scaled_boss_hp(elapsed: float) -> int:`
    $$\text{boss\_hp} = \text{BOSS\_BASE\_HP} + \lfloor \max(0.0, \text{elapsed}) \times 8.0 + \max(0.0, \text{elapsed})^2 \times 0.12 \rfloor$$
- In `_step_survival_spawners(delta: float)`:
  - **Soldier Wave Spawning:**
    - Interval: `base_soldier_int = maxf(SOLDIER_MIN_INTERVAL, SOLDIER_BASE_INTERVAL - (time_elapsed / 45.0) * 0.65)`
    - Burst count: `rng.randi_range(get_soldier_min_burst(time_elapsed), get_soldier_max_burst(time_elapsed))`
    - Soldier durability: `var s_pwr: int = get_scaled_soldier_power(time_elapsed)` passed to `r_mob.setup("red", s_pwr)`.
    - Multi-lane formation placement: spread spawned soldiers across `X in [-3.8, +3.8]` and staggered `Z` rows (`-22.0 - float(i / 4) * 0.65`) with speed scaling up to `RED_SPEED * clampf(1.0 + time_elapsed / 120.0, 1.0, 1.85)`.
  - **Boss Wave Spawning:**
    - Interval: `base_boss_int = maxf(BOSS_MIN_INTERVAL, BOSS_BASE_INTERVAL - (time_elapsed / 25.0) * 2.2)`
    - When `active_bosses.size() < get_max_concurrent_bosses(time_elapsed)`, spawn a new Boss with `get_scaled_boss_hp(time_elapsed)` and speed `clampf(BOSS_BASE_SPEED + (time_elapsed / 90.0) * 0.9, BOSS_BASE_SPEED, 4.0)`. If `time_elapsed >= 60.0` and `active_bosses.size() + 1 < max_bosses` and `rng.randf() < 0.35`, spawn a second Boss in an opposite lane in the same wave!

---

### BDD Acceptance Criteria (Given / When / Then)

```gherkin
Feature: Always-On Auto-Fire Cannons, Uninterrupted Muzzle Volleys, and Aggressive Time-Escalating Enemy Waves

  Scenario: GWT 1 - Always-On Automatic Firing Without Space or J Input
    Given a MobControlMain instance running in GameState.PLAYING
    When step(delta) executes over 1.0 second (60 ticks of 1/60s) with zero keyboard/action fire input pressed
    Then Cannon3D automatically fires every 0.14s (producing 7 volleys in 1.0s)
    And pressing or releasing KEY_SPACE or KEY_J does not stop or reset the cannon firing cadence
    And UI/ControlsHint displays "A/D or ARROWS: STEER | ESC: MENU" without "SPACE: FIRE".

  Scenario: GWT 2 - Uninterrupted Muzzle Volleys at MAX_MOBS Cap & Upper-Highway Despawning
    Given a MobControlMain instance in survival_mode where 300 live Blue Mobs are already active on the highway (at MAX_MOBS = 300)
    When the cannon auto-fire timer reaches 0.14s and emits shoot_requested
    Then _recycle_furthest_blue_mob() recycles the furthest-downrange Blue Mob (lowest Z) and spawns the new cannon shot at the muzzle without pausing or dropping the shot
    And any Blue Mob traveling past Z < -24.5 (SURVIVAL_CLEANUP_BOUND_Z) is immediately despawned during Phase 4 cleanup.

  Scenario: GWT 3 - Aggressive Time-Escalating Soldier Horde (Wave Size, Frequency, & Soldier HP/Power)
    Given a MobControlMain instance in survival_mode
    When time_elapsed progresses from 0s to 36s to 90s
    Then get_soldier_min_burst(time_elapsed) and get_soldier_max_burst(time_elapsed) increase strictly (reaching >= 6 min / >= 9 max at 36s and >= 9 min / >= 18 max at 90s)
    And get_scaled_soldier_power(time_elapsed) increases from 1 at 0s to >= 3 at 36s and >= 7 at 90s
    And spawned Red Soldiers have power (and hp) equal to get_scaled_soldier_power(time_elapsed), absorbing multiple points of bullet power during on_mob_clash().

  Scenario: GWT 4 - Aggressive Time-Escalating Boss Waves (Frequency, Concurrent Cap, & Accelerated HP)
    Given a MobControlMain instance in survival_mode
    When time_elapsed progresses from 0s to 45s to 100s
    Then get_max_concurrent_bosses(time_elapsed) increases from 1 (0s) to 3 (45s) to 5 (100s)
    And get_scaled_boss_hp(time_elapsed) scales nonlinearly upward (e.g. > 450 HP at 36s and > 1500 HP at 90s)
    And _step_survival_spawners(delta) spawns concurrent advancing Bosses at shorter intervals.

  Scenario: GWT 5 - Paced Cannon & Bullet Power Progression in Survival Mode
    Given a MobControlMain instance in survival_mode starting with 1 cannon and bullet_power == 1
    When Blue Mobs pass through xN multiplier gates
    Then unlocking each additional cannon (up to 5) requires accumulating CANNON_UNLOCK_CHARGE_THRESHOLD (12) gate hits rather than unlocking all 5 cannons in 4 single hits.
```

---

### Component Impact Table

| File Path | Action | Description |
|---|---|---|
| `scripts/mob_control/Cannon3D.gd` | **Modify** | Add `@export var auto_fire: bool = true` (default `true`), remove `KEY_SPACE` / `KEY_J` / `mc_fire` / `p1_punch` manual fire dependency when `auto_fire` is active, and fire continuously every `0.14s`. |
| `scripts/mob_control/MobControlMain.gd` | **Modify** | Add `SURVIVAL_CLEANUP_BOUND_Z = -24.5`, `_recycle_furthest_blue_mob()` so cannon muzzle shots never pause at `MAX_MOBS = 300`, `CANNON_UNLOCK_CHARGE_THRESHOLD = 12` for paced survival upgrades, and aggressive time-escalation formulas (`get_soldier_min_burst()`, `get_soldier_max_burst()`, `get_scaled_soldier_power()`, `get_max_concurrent_bosses()`, `get_scaled_boss_hp()`) in `_step_survival_spawners()`. |
| `scenes/mob_control/MobControlMain.tscn` | **Modify** | Update `UI/ControlsHint` text to `"A/D or ARROWS: STEER | ESC: MENU"`. |
| `tests/test_mob_control.gd` | **Modify** | Update controls hint assertions in Scenario 7, and expand Scenario 17 (or add Scenario 18) to verify GWT 1–5 (always-on auto-fire without Space, zero muzzle pause at 300-mob cap via downrange recycling, paced survival cannon unlocks, and aggressive Soldier/Boss wave & HP escalation). |
| `tests/test_mob_control.py` | **Modify** | Update static contract checks for `ControlsHint`, `auto_fire`, `_recycle_furthest_blue_mob`, `get_soldier_min_burst`, `get_scaled_soldier_power`, and updated survival escalation constants. |

---

### INVEST Subtask Breakdown

- **Slice 1 (Standalone Task — Pattern A, $\le 350$ LOC, $\le 5$ files): Always-On Auto-Fire Cannons, Downrange Bullet Recycling, & Aggressive Time-Escalating Enemy Horde**
  - Update `Cannon3D.gd` and `MobControlMain.tscn` so cannons fire automatically 100% of the time without `SPACE`/`J` and display `"A/D or ARROWS: STEER | ESC: MENU"`.
  - Update `MobControlMain.gd` with `SURVIVAL_CLEANUP_BOUND_Z = -24.5`, `_recycle_furthest_blue_mob()` to guarantee uninterrupted muzzle volleys at `MAX_MOBS = 300`, paced survival cannon/power upgrades, and aggressive time-escalating Soldier & Boss waves (burst sizes, spawn intervals, Soldier HP/power scaling, and Boss HP/concurrency scaling).
  - Update unit and contract tests in `tests/test_mob_control.gd` and `tests/test_mob_control.py`.
