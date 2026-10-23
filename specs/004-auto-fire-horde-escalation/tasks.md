---

description: "Task list for Always-On Auto-Fire Cannons, Uninterrupted Muzzle Volleys, & Aggressive Time-Escalating Enemy Horde"
---

# Tasks: Always-On Auto-Fire Cannons, Uninterrupted Muzzle Volleys, & Aggressive Time-Escalating Enemy Horde

**Input**: Design documents from `/specs/004-auto-fire-horde-escalation/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Automated Python static contract tests (`tests/test_mob_control.py`) and Godot 4.3 headless runtime tests (`tests/test_mob_control.gd`) are REQUIRED per Constitution Principle III.

**Organization**: Tasks are grouped by user story (`US1`–`US4`) to enable structured implementation and independent verification of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`, `[US4]`)
- Exact file paths are included in every task description

---

## Phase 1: Setup (Shared Constants & Auto-Fire Configuration)

**Purpose**: Establish auto-fire properties on `Cannon3D`, survival cleanup/recycling constants, paced upgrade thresholds, and updated escalation constants in `MobControlMain.gd`.

- [X] T001 [P] Add `@export var auto_fire: bool = true` to `scripts/mob_control/Cannon3D.gd` and ensure `reset()` preserves `auto_fire` while resetting `position = Vector3(0.0, 0.5, 9.0)`, `move_input = 0.0`, `fire_held = false`, and `fire_accumulator = 0.0`
- [X] T002 Define `SURVIVAL_CLEANUP_BOUND_Z: float = -24.5`, `CANNON_UNLOCK_CHARGE_THRESHOLD: int = 12`, `GATE_POWER_EARLY_THRESHOLD: int = 10`, `BOSS_BASE_HP: int = 160`, `SOLDIER_BASE_INTERVAL: float = 1.1`, `SOLDIER_MIN_INTERVAL: float = 0.18`, `BOSS_BASE_INTERVAL: float = 9.5`, and `BOSS_MIN_INTERVAL: float = 3.2` in `scripts/mob_control/MobControlMain.gd`

---

## Phase 2: Foundational (Legacy Test Coexistence & Stage Mode Isolation)

**Purpose**: Ensure `init_stage(stage_idx)` and `init_survival_phase()` cleanly configure cannon `auto_fire` and mode flags so all existing test scenarios (`Scenarios 1–17`) coexist with the new auto-fire and horde escalation behavior.

- [X] T003 Update `init_survival_phase()` in `scripts/mob_control/MobControlMain.gd` to ensure `cannon.auto_fire = true` and `controls_hint.text = "A/D or ARROWS: STEER | ESC: MENU"` when `controls_hint` is valid

---

## Phase 3: User Story 1 - Always-On Automatic Cannon Firing & Removal of Space Button Fire Control (Priority: P1) 🎯 MVP

**Goal**: Make `Cannon3D` fire automatically and continuously at `FIRE_INTERVAL = 0.14s` during `GameState.PLAYING` (`auto_fire = true`) without requiring `SPACE` or `J` input, ignore `SPACE`/`J` release during auto-fire, and update `UI/ControlsHint` to `"A/D or ARROWS: STEER | ESC: MENU"`.

**Independent Test**: Instantiate `MobControlMain.tscn`, step `1.0s` (`60` frames of `1/60s`) with zero fire inputs pressed, verify `7` shots are fired automatically, verify pressing/releasing `SPACE` does not reset `fire_accumulator` while `auto_fire == true`, and check `UI/ControlsHint.text`.

### Implementation for User Story 1

- [X] T004 [P] [US1] Update `step(delta: float)` in `scripts/mob_control/Cannon3D.gd` so that when `auto_fire` is `true`, `effective_fire` is always `true` (independent of `KEY_SPACE` / `KEY_J` / `mc_fire` / `p1_punch`), advancing `fire_accumulator += delta` and emitting `shoot_requested` every `0.14s` while preserving manual `fire_held` / key fallback behavior when `auto_fire == false` for isolated manual-cadence tests
- [X] T005 [P] [US1] Update `UI/ControlsHint` text in `scenes/mob_control/MobControlMain.tscn` from `"A/D or ARROWS: STEER | HOLD J or SPACE: FIRE | ESC: MENU"` to `"A/D or ARROWS: STEER | ESC: MENU"`

**Checkpoint**: Cannons fire continuously at all times without pressing `SPACE` or `J`, and the HUD controls hint reflects steering and menu navigation only.

---

## Phase 4: User Story 2 - Uninterrupted Muzzle Volleys at the Entity Cap & Tighter Upper-Highway Despawning (Priority: P1)

**Goal**: Eliminate multi-second cannon firing pauses when `MAX_MOBS = 300` is reached by despawning Blue Mobs at `Z < -24.5` in Survival Mode (`get_cleanup_bound_z()`) and recycling the furthest-downrange live Blue Mob (`_recycle_furthest_blue_mob()`) whenever a cannon volley is requested at the 300-mob cap.

**Independent Test**: Populate `300` live Blue Mobs in Survival Mode with varying `Z` positions (`-20.0` to `5.0`), emit a cannon volley from `5` active cannons, and verify the `5` furthest-downrange Blue Mobs (`lowest Z`) are freed and `5` fresh Blue Mobs spawn at the cannon muzzles (`Z = 8.0`) while `get_live_blue_mobs_count() == 300`.

### Implementation for User Story 2

- [X] T006 [US2] Update `get_cleanup_bound_z() -> float` in `scripts/mob_control/MobControlMain.gd` to return `SURVIVAL_CLEANUP_BOUND_Z` (`-24.5`) when `survival_mode == true` and `highway_min_z - 3.0` when `survival_mode == false`
- [X] T007 [US2] Implement `_recycle_furthest_blue_mob() -> bool` and invoke it in `_on_cannon_shoot_requested(muzzle_pos: Vector3)` in `scripts/mob_control/MobControlMain.gd` when `survival_mode == true` and `get_live_blue_mobs_count() + pending_spawns >= MAX_MOBS` so cannon muzzle shots are never dropped or blocked

**Checkpoint**: Cannons never pause or skip shots even when 5 cannons fire through high-multiplier gates at the 300-mob limit.

---

## Phase 5: User Story 3 - Aggressive Time-Escalating Enemy Horde (Soldiers & Bosses) (Priority: P1)

**Goal**: Scale Soldier wave burst ranges (`get_soldier_min_burst`, `get_soldier_max_burst`), Soldier HP/power (`get_scaled_soldier_power`), Boss concurrency (`get_max_concurrent_bosses` up to `5`), and accelerating Boss HP (`get_scaled_boss_hp`) over `time_elapsed` in `_step_survival_spawners(delta)`.

**Independent Test**: Evaluate `get_soldier_min_burst`, `get_soldier_max_burst`, `get_scaled_soldier_power`, `get_max_concurrent_bosses`, and `get_scaled_boss_hp` at `t = 0s`, `36s`, `45s`, `90s`, and `100s`, and step `_step_survival_spawners(delta)` to confirm multi-HP Soldiers and multi-lane Bosses spawn and absorb multiple points of bullet power in `on_mob_clash()`.

### Implementation for User Story 3

- [X] T008 [US3] Implement `get_soldier_min_burst(elapsed: float) -> int`, `get_soldier_max_burst(elapsed: float) -> int`, and `get_scaled_soldier_power(elapsed: float) -> int` in `scripts/mob_control/MobControlMain.gd`
- [X] T009 [US3] Update `get_max_concurrent_bosses(elapsed: float) -> int` (scaling `1 -> 2 -> 3 -> 4 -> 5` at `0s / 20s / 45s / 70s / 100s`) and `get_scaled_boss_hp(elapsed: float) -> int` (`BOSS_BASE_HP + int(floor(t * 8.0 + t * t * 0.12))`) in `scripts/mob_control/MobControlMain.gd`
- [X] T010 [US3] Update `_step_survival_spawners(delta: float)` in `scripts/mob_control/MobControlMain.gd` to spawn `rng.randi_range(get_soldier_min_burst(time_elapsed), get_soldier_max_burst(time_elapsed))` Soldiers with `r_mob.setup("red", get_scaled_soldier_power(time_elapsed))` in staggered multi-lane formations and faster-escalating Boss waves

**Checkpoint**: Enemy Soldier waves grow rapidly in both headcount (`up to 24 per burst`) and per-soldier HP (`up to 15`), accompanied by up to 5 concurrent high-HP Bosses.

---

## Phase 6: User Story 4 - Paced Cannon & Bullet Power Upgrade Progression in Survival Mode (Priority: P2)

**Goal**: Pace cannon unlocking (`CANNON_UNLOCK_CHARGE_THRESHOLD = 12` hits per extra cannon) and early bullet power tiers (`GATE_POWER_EARLY_THRESHOLD = 10` charge per tier for `1..6`) in `_on_bullet_hit_multiplier_gate(mult_value: int)` when `survival_mode == true`, while preserving instant unlock in legacy stage mode (`survival_mode == false`).

**Independent Test**: Call `_on_bullet_hit_multiplier_gate(2)` 12 times in `survival_mode` to verify the 2nd cannon unlocks on the 12th hit, and verify `init_stage(0)` (`survival_mode == false`) still unlocks cannons on each hit for `Scenario 15` / `Scenario 16`.

### Implementation for User Story 4

- [X] T011 [US4] Update `_on_bullet_hit_multiplier_gate(mult_value: int)` in `scripts/mob_control/MobControlMain.gd` to enforce `CANNON_UNLOCK_CHARGE_THRESHOLD = 12` and `GATE_POWER_EARLY_THRESHOLD = 10` when `survival_mode == true`

**Checkpoint**: Auto-firing cannons progress steadily through `1/5 -> 5/5` cannons and `Power 1 -> 25` over the course of survival play.

---

## Phase 7: Polish, Automated Verification, & Cross-Cutting Concerns

**Purpose**: Update Python and Godot automated test suites (`Scenario 2`, `Scenario 7`, `Scenario 8`, `Scenario 17`, and new `Scenario 18`), remove the temporary Sync Impact Report comment from `.specify/memory/constitution.md`, and verify 100% pass rate.

- [X] T012 [P] Update `test_main_scene_structure`, `test_scripts_contract`, and `test_endless_survival_dynamic_gates_and_boss_destruction_contract` in `tests/test_mob_control.py` to assert `"A/D or ARROWS: STEER | ESC: MENU"`, `var auto_fire: bool = true`, `SURVIVAL_CLEANUP_BOUND_Z = -24.5`, `_recycle_furthest_blue_mob`, `CANNON_UNLOCK_CHARGE_THRESHOLD = 12`, `get_soldier_min_burst`, and `get_scaled_soldier_power`
- [X] T013 Update `test_scenario_2_cannon_movement_cadence_and_cap()`, `test_scenario_6_enemy_breach_defeat_priority_and_reset()`, `test_scenario_7_controls_discoverability_steering_and_space_fire()`, `test_scenario_8_raw_key_fallback_and_scene_attachment()`, and `test_scenario_17_endless_survival_scrolling_gates_and_boss_gate_destruction()` in `tests/test_mob_control.gd` to reflect `"A/D or ARROWS: STEER | ESC: MENU"`, default `auto_fire = true` (toggling `auto_fire = false` only where manual release reset is specifically tested), and updated escalation assertions
- [X] T014 Add `test_scenario_18_auto_fire_downrange_recycling_and_aggressive_horde_escalation()` in `tests/test_mob_control.gd` (and register in `run_all()`) verifying GWT 1–5 end-to-end (always-on auto-fire with zero input, uninterrupted 5-cannon volleys at `MAX_MOBS = 300` via `_recycle_furthest_blue_mob()`, `Z < -24.5` despawning, paced survival cannon unlocks, and scaled Soldier HP/burst & Boss escalation)
- [X] T015 Remove the temporary Sync Impact Report HTML comment from `.specify/memory/constitution.md` and run `python -m unittest discover -s tests -v` and `godot --headless -s res://tests/test_runner.gd` to confirm 100% pass rate

---

## Dependencies & Execution Order

- **Phase 1 (T001–T002)** $\rightarrow$ **Phase 2 (T003)** $\rightarrow$ **Phase 3..6 (T004–T011)** $\rightarrow$ **Phase 7 (T012–T015)**.
- Parallel tasks `[P]` (`T001`, `T004`, `T005`, `T012`) operate on independent files (`Cannon3D.gd`, `MobControlMain.tscn`, `test_mob_control.py`).

## Parallel Example: User Story 1

```bash
Task: "T004 [P] [US1] Update step(delta) in scripts/mob_control/Cannon3D.gd for always-on auto_fire"
Task: "T005 [P] [US1] Update UI/ControlsHint text in scenes/mob_control/MobControlMain.tscn"
```

## Implementation Strategy

1. Complete Phase 1 & Phase 2 (`T001`–`T003`) to establish `auto_fire` and survival escalation constants.
2. Complete Phase 3 (`T004`–`T005`) for User Story 1 (Always-On Auto-Fire & HUD Controls Hint).
3. Complete Phase 4 (`T006`–`T007`) for User Story 2 (Upper-Highway Despawn Bound & Downrange Bullet Recycling).
4. Complete Phase 5 (`T008`–`T010`) for User Story 3 (Aggressive Time-Escalating Soldier & Boss Horde).
5. Complete Phase 6 (`T011`) for User Story 4 (Paced Survival Cannon & Power Upgrades).
6. Complete Phase 7 (`T012`–`T015`) to validate 100% pass across Python and Godot headless test suites.
