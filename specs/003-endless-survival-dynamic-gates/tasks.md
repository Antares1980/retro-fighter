---

description: "Task list for Endless Survival Phase, Dynamic Scrolling & Respawning Gates, Gate-Crushing Bosses, & Escalating Enemy Waves"
---

# Tasks: Endless Survival Phase, Dynamic Scrolling & Respawning Gates, Gate-Crushing Bosses, & Escalating Enemy Waves

**Input**: Design documents from `/specs/003-endless-survival-dynamic-gates/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Automated Python static contract tests (`tests/test_mob_control.py`) and Godot 4.3 headless runtime tests (`tests/test_mob_control.gd`) are REQUIRED per Constitution Principle III.

**Organization**: Tasks are grouped by user story (`US1`–`US4`) to enable structured implementation and independent verification of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`, `[US4]`)
- Exact file paths are included in every task description

---

## Phase 1: Setup (Shared Constants & Gate/Boss Motion Properties)

**Purpose**: Establish shared survival, gate scrolling, and advancing Boss constants and properties in `MobControlMain.gd`, `MultiplierGate3D.gd`, and `GiantEnemy3D.gd`.

- [X] T001 Define `GATE_SCROLL_SPEED = 1.8`, `GATE_DESPAWN_Z = 8.2`, `GATE_SPAWN_Z = -16.5`, `BOSS_BASE_SPEED = 2.6`, and `BOSS_BASE_HP = 140` constants plus `survival_mode`, `dynamic_gates_enabled`, `bosses_defeated`, `soldiers_defeated`, `best_survival_time`, `active_bosses: Array[Node3D]`, `gate_spawn_timer`, `next_gate_spawn_interval`, `boss_spawn_timer`, `next_boss_spawn_interval`, and `next_soldier_spawn_interval` state variables in `scripts/mob_control/MobControlMain.gd`
- [X] T002 [P] Add `@export var scroll_speed: float = 1.8`, `@export var move_enabled: bool = true`, `var osc_enabled: bool = false`, `var osc_base_x: float = 0.0`, `var osc_amplitude: float = 1.4`, `var osc_speed: float = 1.8`, and `var osc_time: float = 0.0` properties in `scripts/mob_control/MultiplierGate3D.gd`
- [X] T003 [P] Add `var anim_time: float = 0.0` and `_built_width: float = -1.0` tracking in `scripts/mob_control/GiantEnemy3D.gd` so lane-sized Bosses (`half_width = 1.55`) dynamically rebuild their 3D Mech geometry to match their exact `half_width` and animate a marching stride bob in `step_visuals(delta: float)` when `speed > 0.0`

---

## Phase 2: Foundational (Entity Lifecycle, Pruning, & Stage/Survival Coexistence)

**Purpose**: Ensure `active_bosses` and dynamically spawned `MultiplierGate3D` nodes are pruned and cleaned up properly, and preserve `init_stage(stage_idx)` backward compatibility for `Scenarios 1–16`.

- [X] T004 Add pre-tick pruning for `active_bosses` in `step(delta: float)` and cleanup of `active_bosses` and dynamically spawned gates (`is_in_group("dynamic_gates")`) in `cleanup_stage_entities()` in `scripts/mob_control/MobControlMain.gd`
- [X] T005 Ensure `init_stage(stage_idx: int)` sets `survival_mode = false` and `dynamic_gates_enabled = false` while restoring the 4 baseline scene gates (`gate_left_1`, `gate_right_1`, `gate_left_2`, `gate_right_2`) to their canonical coordinates `(-2.5, 1.0, -2.0)`, `(2.5, 1.0, -2.0)`, `(-2.5, 1.0, -8.0)`, `(2.5, 1.0, -8.0)` so legacy stage tests (`Scenarios 1–16`) run without interference in `scripts/mob_control/MobControlMain.gd`

---

## Phase 3: User Story 1 - Single Endless Survival Phase & Continuous Combat Loop (Priority: P1) 🎯 MVP

**Goal**: Launch by default into the Single Endless Survival Phase (`init_survival_phase()` in `_ready()`), keep combat uninterrupted (`state == GameState.PLAYING`) when Bosses are defeated while incrementing `bosses_defeated`, display live Survival Time and Bosses Defeated on the HUD, and trigger `GameState.DEFEAT` with survival telemetry only when a Soldier or Boss breaches `Z >= 9.0`.

**Independent Test**: Instantiate `MobControlMain.tscn`, verify `survival_mode == true` and `active_obstacles.is_empty()`, defeat an active Boss in `active_bosses` to confirm `bosses_defeated == 1` and `state == GameState.PLAYING`, and move a Soldier or Boss to `Z >= 9.0` to verify `GameState.DEFEAT` and retry reset.

### Implementation for User Story 1

- [X] T006 [US1] Implement `init_survival_phase()` in `scripts/mob_control/MobControlMain.gd` and invoke it from `_ready()` (setting `survival_mode = true`, `dynamic_gates_enabled = true`, hiding the static full-width `giant_enemy`, clearing static obstacles, resetting the 4 initial gates with `move_enabled = true`, and spawning the initial advancing Boss in `active_bosses` at `Z = -21.0`)
- [X] T007 [US1] Update `_update_cannon_status_ui()`, `_evaluate_game_state()`, `retry_stage()`, and `reset_stage()` in `scripts/mob_control/MobControlMain.gd` so Survival Mode updates `wave_status_label` with `"SURVIVAL TIME: %s | BOSSES: %d | KILLS: %d"`, triggers `GameState.DEFEAT` when any live Soldier or Boss in `active_bosses` reaches `Z >= 9.0`, formats `defeat_banner` with survival time and bosses defeated, and restarts via `init_survival_phase()` when `survival_mode` is active

**Checkpoint**: The game runs in a single continuous Survival Phase where Boss kills never pause the game and `DEFEAT` triggers only on `Z >= 9.0` breach.

---

## Phase 4: User Story 2 - Dynamic Moving, Despawning, & Respawning `xN` and `+N` Modifier Gates (Priority: P1)

**Goal**: Make all active `xN` and `+N` gates advance forward (`+Z`) down the highway (with optional `X` oscillation within `[-3.2, 3.2]`), disappear when reaching `Z >= 8.2`, and continuously respawn with randomized operations and values in the upper highway (`Z <= -14.0`).

**Independent Test**: Step `MobControlMain` in Survival Mode, verify all gates increase `position.z` by `scroll_speed * delta`, verify a gate placed at `Z = 8.25` is freed on step, and verify `spawn_random_gate()` / `gate_spawn_timer` spawns new gates at `Z = -16.5` within `X in [-2.8, 2.8]`.

### Implementation for User Story 2

- [X] T008 [P] [US2] Implement `step_gate(delta: float)` in `scripts/mob_control/MultiplierGate3D.gd` to advance `position.z += scroll_speed * delta` when `move_enabled` is true and oscillate `position.x = clampf(osc_base_x + sin(osc_time * osc_speed) * osc_amplitude, -3.2, 3.2)` when `osc_enabled` is true
- [X] T009 [US2] Implement gate stepping in Phase 1, bottom-of-screen gate despawning (`global_position.z >= GATE_DESPAWN_Z`) in Phase 4 (`_cleanup_out_of_bounds_mobs()`), and `spawn_random_gate(z_pos: float = GATE_SPAWN_Z)` driven by `gate_spawn_timer` in `scripts/mob_control/MobControlMain.gd`

**Checkpoint**: Multiplier gates continuously scroll down the highway, disappear at the bottom, and respawn with randomized `+N` and `xN` values at the top.

---

## Phase 5: User Story 3 - Advancing Lane-Sized Bosses That Destroy `xN` and `+N` Gates (Priority: P1)

**Goal**: Spawn lane-sized 3D Mech Bosses (`active_bosses`) that march forward (`+Z`) faster than drifting gates (`speed >= 2.6 > 1.8`), shatter and destroy any `xN` or `+N` gate they overlap (`on_boss_destroy_gate`), and take damage from Blue Mobs until exploding at `0 HP` (`_resolve_boss_contacts`).

**Independent Test**: Spawn an advancing Boss behind or overlapping a `MultiplierGate3D`, step `MobControlMain`, and verify the Boss marches faster than the gate, destroys the gate on contact with a 3D shatter FX (`active_destruction_fx.size() > 0`), and explodes/disappears when its HP reaches `0`.

### Implementation for User Story 3

- [X] T010 [US3] Implement `spawn_boss(pos: Vector3, hp_val: int, speed_val: float)` and Phase 1 forward movement for all Bosses in `active_bosses` (`boss.position.z += boss.speed * delta`, `boss.step_visuals(delta)`) in `scripts/mob_control/MobControlMain.gd`
- [X] T011 [US3] Implement `_resolve_boss_gate_destruction()` and `on_boss_destroy_gate(boss: GiantEnemy3DScript, gate: MultiplierGate3DScript)` in `scripts/mob_control/MobControlMain.gd` to spawn a cyan/blue 3D shatter FX (`_spawn_destruction_fx`), lock/disable the gate, and `queue_free()` the gate on Boss contact
- [X] T012 [US3] Implement `_resolve_boss_contacts()` and `on_mob_hit_boss(blue: MobUnit3DScript, boss: GiantEnemy3DScript)` in `scripts/mob_control/MobControlMain.gd` so Blue Mobs damage advancing Bosses and `0 HP` Bosses spawn a 3D explosion FX, increment `bosses_defeated`, and are removed/freed from `active_bosses`

**Checkpoint**: Advancing Bosses march down lanes, shatter any `xN`/`+N` gate in their path, and explode when killed without stopping the game.

---

## Phase 6: User Story 4 - Randomized & Time-Escalating Soldier and Boss Waves (Priority: P2)

**Goal**: Continuously escalate Soldier and Boss spawning in Survival Mode as `time_elapsed` grows—shrinking spawn intervals and increasing Soldier squad burst size (`get_soldier_max_burst`), concurrent Boss cap (`get_max_concurrent_bosses`), Boss HP (`get_scaled_boss_hp`), and march speed.

**Independent Test**: Query escalation helpers and step `_step_survival_spawners(delta)` at `time_elapsed = 0.0` vs `time_elapsed = 65.0`, confirming `get_soldier_max_burst(65.0) >= 5`, `get_max_concurrent_bosses(65.0) >= 2`, `get_scaled_boss_hp(65.0) >= 2 * BOSS_BASE_HP`, and multiple concurrent Bosses spawning in randomized lanes.

### Implementation for User Story 4

- [X] T013 [US4] Implement deterministic escalation functions `get_soldier_max_burst(elapsed: float) -> int`, `get_max_concurrent_bosses(elapsed: float) -> int`, and `get_scaled_boss_hp(elapsed: float) -> int` plus `_step_survival_spawners(delta: float)` in `scripts/mob_control/MobControlMain.gd`

**Checkpoint**: Both Soldiers and Bosses spawn randomly and scale up in number, frequency, and strength the longer the player stays alive.

---

## Phase 7: Polish, Automated Verification, & Cross-Cutting Concerns

**Purpose**: Comprehensive unit/integration test coverage (`Scenario 17` + static contracts) and full regression verification across `Scenarios 1–17`.

- [X] T014 [P] Add `test_endless_survival_dynamic_gates_and_boss_destruction_contract` in `tests/test_mob_control.py` verifying survival constants, gate scrolling properties, boss gate destruction methods, and time-escalation helpers
- [X] T015 Update `test_scenario_16_extended_waves_obstacles_3d_forms_and_destruction_fx()` in `tests/test_mob_control.gd` to explicitly call `main.init_stage(0)` at start of Part 1, and add `test_scenario_17_endless_survival_scrolling_gates_and_boss_gate_destruction()` in `tests/test_mob_control.gd` (registered in `run_all()`) testing GWT 1–5 end-to-end
- [X] T016 Remove temporary Sync Impact Report HTML comment from `.specify/memory/constitution.md` and run `python -m unittest discover -s tests -v` and `godot --headless -s res://tests/test_runner.gd` to verify 100% pass rate with zero regressions

---

## Dependencies & Execution Order

- **Phase 1 (T001–T003)** $\rightarrow$ **Phase 2 (T004–T005)** $\rightarrow$ **Phase 3..6 (T006–T013)** $\rightarrow$ **Phase 7 (T014–T016)**.
- Parallel tasks `[P]` (`T002`, `T003`, `T008`, `T014`) operate on independent files (`MultiplierGate3D.gd`, `GiantEnemy3D.gd`, `test_mob_control.py`).

## Parallel Example: User Story 2 & Setup

```bash
Task: "T002 [P] Add scroll_speed, move_enabled, and oscillation properties in scripts/mob_control/MultiplierGate3D.gd"
Task: "T003 [P] Add anim_time and _built_width tracking in scripts/mob_control/GiantEnemy3D.gd"
```

## Implementation Strategy

1. Complete Phase 1 & Phase 2 (`T001`–`T005`) to establish survival/gate/boss state and backward-compatible `init_stage()` isolation.
2. Complete Phase 3 (`T006`–`T007`) for User Story 1 (Single Endless Survival Phase MVP).
3. Complete Phase 4 (`T008`–`T009`) for User Story 2 (Dynamic Scrolling, Despawning, & Respawning Gates).
4. Complete Phase 5 (`T010`–`T012`) for User Story 3 (Advancing Bosses & Gate Destruction).
5. Complete Phase 6 (`T013`) for User Story 4 (Randomized & Time-Escalating Soldier and Boss Spawners).
6. Complete Phase 7 (`T014`–`T016`) to validate 100% pass across Python and Godot headless test suites.
