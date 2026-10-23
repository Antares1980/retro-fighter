---

description: "Task list for Extended Multi-Wave Stages, Highway Obstacles, Articulated Enemy Silhouettes, and Destruction Lifecycle"
---

# Tasks: Extended Multi-Wave Stages, Highway Obstacles, Articulated Enemy Silhouettes, and Destruction Lifecycle

**Input**: Design documents from `/specs/002-extended-waves-obstacles-enemies/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Automated Python static contract tests (`tests/test_mob_control.py`) and Godot 4.3 headless runtime tests (`tests/test_mob_control.gd`) are REQUIRED per Constitution Principle III.

**Organization**: Tasks are grouped by user story (`US1`–`US4`) to enable structured implementation and independent verification of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`, `[US4]`)
- Exact file paths are included in every task description

---

## Phase 1: Setup (Shared Constants & Stage Matrix)

**Purpose**: Establish shared constants, wave counts, and data structures in `MobControlMain.gd` and `GiantEnemy3D.gd`.

- [X] T001 Add `"waves"` count (`3`, `4`, `4`, `5`, `5`) to each stage dictionary in `STAGES` and define `GATE_CHARGE_THRESHOLD = 35`, `MAX_BULLET_POWER = 25`, `GIANT_FORTIFIED_SPEED = 0.18`, and `DESTRUCTION_FX_DURATION = 0.45` in `scripts/mob_control/MobControlMain.gd`
- [X] T002 [P] Extend `EntityMode` enum to `{ BASE, PYLON, WALL, MOVING_BLOCK, HAZARD }` and declare obstacle oscillation (`osc_enabled`, `osc_base_x`, `osc_amplitude`, `osc_speed`, `osc_phase`, `osc_time`), `hit_flash_timer`, and `mech_model` properties in `scripts/mob_control/GiantEnemy3D.gd`

---

## Phase 2: Foundational (Entity Lifecycle & Cleanup Hooks)

**Purpose**: Core array tracking (`active_obstacles`, `active_destruction_fx`) and stage cleanup hooks required by all user stories.

- [X] T003 Add `current_wave`, `total_waves_in_stage`, `gate_power_charge`, `active_obstacles: Array[Node3D]`, and `active_destruction_fx: Array[Node3D]` state variables plus pre-tick pruning and `cleanup_stage_entities()` cleanup in `scripts/mob_control/MobControlMain.gd`
- [X] T004 [P] Implement helper predicates `is_wall()`, `is_moving_block()`, `is_hazard()`, `is_obstacle()`, and mode-aware 3D label formatting (`WALL: %d`, `ARMOR: %d`, `HAZARD: %d`) in `scripts/mob_control/GiantEnemy3D.gd`

---

## Phase 3: User Story 1 - Extended Multi-Wave Stage Progression & Balanced Power Scaling (Priority: P1) 🎯 MVP

**Goal**: Initialize Stage 1 automatically on scene load, enforce multi-wave progression (3–5 waves per stage) with fortified Boss speed (`0.18`) while wave obstacles remain active, display wave status in the HUD, and bound `bullet_power` growth via `GATE_CHARGE_THRESHOLD = 35` and `MAX_BULLET_POWER = 25`.

**Independent Test**: Instantiate `MobControlMain.tscn`, verify `init_stage(0)` ran in `_ready()` (`giant_enemy.hp == 1200`, `current_wave == 1`, `total_waves_in_stage == 3`), verify clearing Wave 1 obstacles advances `current_wave` to `2`, and verify `bullet_power` above tier 6 requires `35` gate hits per `+1` up to `25`.

### Implementation for User Story 1

- [X] T005 [US1] Invoke `init_stage(0)` in `_ready()` and initialize `current_wave = 1` and `total_waves_in_stage = int(cfg.get("waves", 3))` in `init_stage()` in `scripts/mob_control/MobControlMain.gd`
- [X] T006 [US1] Implement `_on_bullet_hit_multiplier_gate(mult_value: int)` gate-charge accumulation (`gate_power_charge`, `GATE_CHARGE_THRESHOLD = 35`, `MAX_BULLET_POWER = 25`) after `cannons.size() == 5` and `bullet_power >= 6`, and reset `gate_power_charge = 0` in `_reset_cannons_and_power()` in `scripts/mob_control/MobControlMain.gd`
- [X] T007 [US1] Implement wave progression evaluation (`_check_wave_progression()`) and fortified Boss march speed (`GIANT_FORTIFIED_SPEED = 0.18` when `active_obstacles.size() > 0`, else `GIANT_SPEED = 1.0`) plus HUD wave status formatting in `scripts/mob_control/MobControlMain.gd`

**Checkpoint**: Stage 1 auto-initializes on scene load, stages progress across multiple waves, and bullet power scales smoothly without runaway inflation.

---

## Phase 4: User Story 2 - Diverse Highway Obstacles: Destructible Walls, Moving Blocks, and Hazards (Priority: P1)

**Goal**: Spawn wave obstacle formations (`WALL`, `MOVING_BLOCK`, `HAZARD`) on the highway, oscillate `MOVING_BLOCK` obstacles horizontally within `[-4.5, +4.5]`, and resolve projectile-obstacle collisions (including `2x` attrition on `HAZARD` barriers).

**Independent Test**: Spawn `WALL`, `MOVING_BLOCK`, and `HAZARD` obstacles via `spawn_obstacle()`, step frames to confirm `MOVING_BLOCK` X oscillation within `[-4.5, +4.5]`, and collide Blue Mobs to verify damage deduction and `2x` hazard attrition.

### Implementation for User Story 2

- [X] T008 [P] [US2] Implement `step_obstacle(delta: float)` in `scripts/mob_control/GiantEnemy3D.gd` to oscillate `MOVING_BLOCK` horizontally (`osc_base_x + sin(osc_time * osc_speed + osc_phase) * osc_amplitude`) clamped to `[-4.5 + half_width, 4.5 - half_width]`
- [X] T009 [US2] Implement `spawn_obstacle()` and `_spawn_wave_obstacles(stage_idx: int, wave_idx: int)` in `scripts/mob_control/MobControlMain.gd` to populate staggered `WALL`, `MOVING_BLOCK`, and `HAZARD` formations and wave raider squads
- [X] T010 [US2] Implement `_resolve_obstacle_contacts()` and `on_mob_hit_obstacle(blue: MobUnit3DScript, obstacle: Node3D)` (with `2x` power attrition on `HAZARD` mode) in `scripts/mob_control/MobControlMain.gd`

**Checkpoint**: Wave obstacles spawn across highway lanes, Moving Blocks oscillate within bounds, and obstacles intercept player shots in front of the Boss.

---

## Phase 5: User Story 3 - Articulated 3D Enemy Raider & Giant Mech Boss Silhouettes (Priority: P2)

**Goal**: Replace the plain red capsule/ball and flat yellow box with composite 3D humanoid/robot raider rigs (`MobUnit3D`) with walking limb stride animation and composite 3D Armored Mech/Pylon/Obstacle rigs (`GiantEnemy3D`), while keeping Blue player shots as glowing energy spheres/bolts.

**Independent Test**: Instantiate a Red `MobUnit3D` (`get_raider_part_count() >= 6`) and a `GiantEnemy3D` (`get_visual_part_count() >= 4`), step `1.0/60.0`, and verify limb rotation changes on the Red raider while Blue `MobUnit3D` keeps its energy bolt mesh.

### Implementation for User Story 3

- [X] T011 [P] [US3] Implement `_build_raider_model()`, `step_visuals(delta: float)`, and `get_raider_part_count()` in `scripts/mob_control/MobUnit3D.gd` to construct a composite 3D Robot Raider (`Head`, `Visor`, `Torso`, `LeftArmPivot`, `RightArmPivot`, `LeftLegPivot`, `RightLegPivot`) for `team == "red"` and animate counter-phase limb stride
- [X] T012 [P] [US3] Implement `_build_entity_model()` and `get_visual_part_count()` in `scripts/mob_control/GiantEnemy3D.gd` to construct multi-part 3D silhouettes for `BASE` (Armored Mech with chassis, head, visor, pauldrons, cannons), `PYLON` (Energy Spire with rings), and `WALL` / `MOVING_BLOCK` / `HAZARD` (reinforced bunker/spike geometry)
- [X] T013 [US3] Invoke `mob.step_visuals(delta)` for live Red Mobs and `obstacle.step_obstacle(delta)` / `giant_enemy.step_obstacle(delta)` during Phase 1 motion in `scripts/mob_control/MobControlMain.gd`

**Checkpoint**: Red enemies march as articulated 3D robot raiders, Bosses and obstacles display multi-part 3D mech/bunker silhouettes, and Blue shots remain glowing energy bolts.

---

## Phase 6: User Story 4 - Hit Feedback, 3D Shatter/Explosion Animation, and Zero-HP Screen Removal (Priority: P1)

**Goal**: Trigger hit-flash and recoil on non-lethal damage, spawn a 3D shatter/explosion burst of flying debris fragments (`active_destruction_fx`) over `0.45s` when any obstacle, vault, pylon, enemy, or Boss reaches `HP <= 0`, and immediately free or hide (`giant_enemy.visible = false`) the destroyed entity so nothing with `HP: 0` ever remains on screen.

**Independent Test**: Inflict non-lethal damage on `GiantEnemy3D` (`is_hit_flashing() == true`), then reduce an obstacle, vault, pylon, and `giant_enemy` to `0 HP` and verify `active_destruction_fx.size() > 0`, obstacle/vault/pylon removal, `giant_enemy.visible == false`, and `giant_enemy.visible == true` upon `reset()`.

### Implementation for User Story 4

- [X] T014 [P] [US4] Implement `hit_flash_timer` activation in `take_damage()`, emissive flash/recoil material pulsing in `step_visuals(delta)`, `is_hit_flashing()`, and `visible = true` restoration in `reset()` in `scripts/mob_control/GiantEnemy3D.gd`
- [X] T015 [US4] Implement `_spawn_destruction_fx(world_pos: Vector3, extent: Vector3, base_color: Color)` and `_step_destruction_fx(delta: float)` (stepped in both `step(delta)` and `_process(delta)`) in `scripts/mob_control/MobControlMain.gd`
- [X] T016 [US4] Trigger `_spawn_destruction_fx()` and immediate removal/hiding on `0 HP` for Obstacles (`on_mob_hit_obstacle`), Vaults (`_destroy_vault`), Pylons (`on_mob_hit_pylon`, `_check_shield_release`), Red Raiders (`on_mob_clash`), and the Giant Boss (`_evaluate_game_state` setting `giant_enemy.visible = false`) in `scripts/mob_control/MobControlMain.gd`

**Checkpoint**: Every hit flashes, every destruction explodes into 3D fragments, and no entity with `HP: 0` ever remains visible on screen.

---

## Phase 7: Polish, Automated Verification, & Cross-Cutting Concerns

**Purpose**: Comprehensive unit/integration test coverage (Scenario 16 + static contracts) and full regression verification.

- [X] T017 [P] Add `test_extended_waves_obstacles_3d_forms_and_destruction_contract` in `tests/test_mob_control.py` verifying wave constants, obstacle modes, 3D rig builders, and destruction FX methods
- [X] T018 Add `test_scenario_16_extended_waves_obstacles_3d_forms_and_destruction_fx()` in `tests/test_mob_control.gd` and register it in `run_all()` to test GWT 1–5 end-to-end
- [X] T019 Run `python -m unittest discover -s tests -v` and `godot --headless -s res://tests/test_runner.gd` to verify 100% pass rate with zero regressions

---

## Dependencies & Execution Order

- **Phase 1 (T001–T002)** $\rightarrow$ **Phase 2 (T003–T004)** $\rightarrow$ **Phase 3..6 (T005–T016)** $\rightarrow$ **Phase 7 (T017–T019)**.
- Parallel tasks `[P]` (`T002`, `T004`, `T008`, `T011`, `T012`, `T014`, `T017`) operate on independent files (`GiantEnemy3D.gd`, `MobUnit3D.gd`, `test_mob_control.py`).
