# Phase 0 Research: Extended Multi-Wave Stages, Highway Obstacles, Articulated Enemy Silhouettes, and Destruction Lifecycle

**Feature**: `002-extended-waves-obstacles-enemies`
**Date**: 2026-10-23

## 1. Multi-Wave Stage Progression & Backward-Compatible Test Architecture

- **Decision**:
  - Call `init_stage(0)` in `MobControlMain._ready()` so Stage 1 always initializes its full stage table (`base_hp = 1200`, `waves = 3`), wave state (`current_wave = 1`, `total_waves_in_stage`), and Wave 1 obstacles (`active_obstacles`).
  - Track wave obstacles in a dedicated `active_obstacles: Array[Node3D] = []` array (separate from `active_vaults` and `active_pylons`) positioned in the mid-highway zone (`Z in [-4.5, -12.5]`).
  - While `active_obstacles` is non-empty, `giant_enemy` advances at `GIANT_FORTIFIED_SPEED: float = 0.18` (instead of `1.0`), giving players time to break through Wave 1..N obstacles before the Boss reaches the front line. When all obstacles in Wave $Y < \text{total\_waves\_in\_stage}$ are destroyed, `current_wave` increments to $Y+1$ and spawns the next obstacle formation and raider squad.
- **Rationale**:
  - Keeping `active_obstacles` separate from `active_vaults` and `active_pylons` guarantees that existing unit tests (`test_scenario_10`, `test_scenario_11`, `test_scenario_12`) that assert `active_vaults.size() == 0` or `active_pylons.size() == 0` immediately after `init_stage(0)` pass without modification.
  - Furthermore, existing unit tests that spawn test Blue Mobs directly at `giant_enemy.global_position.z` (`-15.0`) bypass obstacles in `Z in [-4.5, -12.5]` and damage `giant_enemy` directly, keeping Scenarios 1–15 100% green while real gameplay shots fired from `Z = +8.0` must fight through all obstacle waves.
- **Alternatives Considered**:
  - *Despawning `giant_enemy` during Waves 1..N-1*: Rejected because Scenarios 3, 5b, 6, 10, 11, and 15 inspect `main.giant_enemy.hp` and `main.giant_enemy.position` immediately after `init_stage()`.

## 2. Gate-Charge Power Scaling & Upper Cap (`bullet_power`)

- **Decision**:
  - Preserve the exact early upgrade behavior verified in `test_scenario_15`: hits 1–4 on `xN` gates unlock cannons `2..5` (`MAX_CANNONS = 5`), hit 5 on `x2` upgrades `bullet_power` (`1 -> 3`), and hit 6 on `x3` upgrades `bullet_power` (`3 -> 6`).
  - Once `cannons.size() >= MAX_CANNONS` and `bullet_power >= 6`, accumulate `gate_power_charge += 1` per `xN` gate hit and increment `bullet_power += 1` only every `GATE_CHARGE_THRESHOLD: int = 35` hits, clamped at `MAX_BULLET_POWER: int = 25`.
- **Rationale**:
  - Eliminates the runaway snowball where `bullet_power` reached `479+` in seconds while keeping `test_scenario_15` 100% intact.
- **Alternatives Considered**:
  - *Removing `bullet_power` scaling from `xN` gates entirely*: Rejected because it would break `test_scenario_15` and remove the core progression reward of steering shots into multiplication gates.

## 3. Procedural 3D Articulated Enemy Raider & Mech Boss Rigs

- **Decision**:
  - Construct composite 3D visual hierarchies procedurally inside `MobUnit3D.gd` (`_build_raider_model()`) when `team == "red"` and inside `GiantEnemy3D.gd` (`_build_entity_model()`) based on `entity_mode`.
  - Preserve the root `MeshInstance3D` (`CapsuleMesh`) and `CollisionShape3D` (`CapsuleShape3D`) in `MobUnit3D.tscn` and `BoxShape3D` (`Vector3(9.5, 2.5, 2.5)`) in `GiantEnemy3D.tscn` so `test_mob_control.py` static scene structure assertions pass unchanged.
  - For Red `MobUnit3D` units, hide or scale the base capsule into the core torso and attach a `RaiderModel3D` (`Node3D`) with child `MeshInstance3D` nodes (`Head`, `Visor`, `Torso`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg`) that animate a walking stride in `step_visuals(delta)`.
  - For `GiantEnemy3D`, attach a `MechModel3D` (`Node3D`) with distinct multi-part geometry per `EntityMode` (`BASE` Mech with chassis, head, glowing visor, shoulder pauldrons, and twin cannons; `PYLON` energy spire with rings; `WALL` armored bunker blocks; `MOVING_BLOCK` hover-barrier with chevrons; `HAZARD` crimson spiked barrier).
- **Rationale**:
  - Procedural `MeshInstance3D` composition requires zero external `.glb`/`.fbx` binary assets, works deterministically in headless Godot CI, and satisfies all existing `.tscn` static contract checks.
- **Alternatives Considered**:
  - *External Blender `.glb` imports*: Rejected because binary mesh imports require `.godot/imported/` cache generation and complicate headless cold-cache verification.

## 4. Hit Feedback, Deterministic 3D Shatter FX, & Zero-HP Screen Removal

- **Decision**:
  - Add `_hit_flash_timer: float` to `GiantEnemy3D` (`0.10s` duration on `take_damage()`) that brightens material emission and applies a subtle scale/recoil pulse, stepped deterministically via `step_visuals(delta)`.
  - Implement `_spawn_destruction_fx(world_pos: Vector3, extent: Vector3, base_color: Color)` in `MobControlMain.gd`, creating a `Node3D` burst with `12` outward-flying 3D debris fragments (`MeshInstance3D` shards with velocity, gravity, and angular velocity) tracked in `active_destruction_fx: Array[Node3D]`.
  - Step `active_destruction_fx` in both `step(delta)` (for headless test verification) and `_process(delta)` (so the Boss destruction explosion continues animating smoothly after `state` transitions to `STAGE_CLEAR` or `VICTORY`).
  - When `giant_enemy.hp <= 0` in `_evaluate_game_state()`, immediately set `giant_enemy.visible = false` and spawn a Boss destruction burst if not already hidden, and restore `giant_enemy.visible = true` in `GiantEnemy3D.reset()`.
- **Rationale**:
  - Guarantees that no entity with `HP: 0` ever remains visible on screen (fixing the exact screenshot issue) while keeping state transitions instantaneous and deterministic for unit tests.
- **Alternatives Considered**:
  - *Delaying `STAGE_CLEAR` state transition until a 0.5s timer finishes*: Rejected because existing tests (`test_scenario_5`, `test_scenario_5b`, `test_scenario_11`, `test_scenario_13`) assert `main.state == GameState.STAGE_CLEAR` on the exact `step()` tick where `giant_enemy.hp` reaches `0`.
