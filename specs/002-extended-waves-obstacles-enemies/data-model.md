# Phase 1 Data Model: Extended Multi-Wave Stages, Highway Obstacles, Articulated Enemy Silhouettes, and Destruction Lifecycle

**Feature**: `002-extended-waves-obstacles-enemies`
**Date**: 2026-10-23

## 1. `MobControlMain` Wave, Obstacle, Power, & FX State (`scripts/mob_control/MobControlMain.gd`)

| Field / Constant | Type | Default / Value | Constraints & Invariants |
|---|---|---|---|
| `GATE_CHARGE_THRESHOLD` | `const int` | `35` | Number of `xN` gate hits required for each `+1` `bullet_power` upgrade once `cannons.size() == 5` and `bullet_power >= 6`. |
| `MAX_BULLET_POWER` | `const int` | `25` | Strict upper bound on `bullet_power` (`1 <= bullet_power <= 25`). |
| `GIANT_FORTIFIED_SPEED` | `const float` | `0.18` | Reduced forward march speed of `giant_enemy` while `active_obstacles` is non-empty. |
| `DESTRUCTION_FX_DURATION` | `const float` | `0.45` | Lifetime in seconds of each 3D shatter/explosion effect in `active_destruction_fx`. |
| `current_wave` | `int` | `1` | Current wave index (`1 <= current_wave <= total_waves_in_stage`). |
| `total_waves_in_stage` | `int` | `3..5` | Configured per stage in `STAGES` (`3` for Stage 1, `4` for Stages 2–3, `5` for Stages 4–5). |
| `gate_power_charge` | `int` | `0` | Accumulated `xN` gate hits toward the next `+1` `bullet_power` tier above `6`. Reset to `0` in `_reset_cannons_and_power()`. |
| `active_obstacles` | `Array[Node3D]` | `[]` | Live wave obstacles (`WALL`, `MOVING_BLOCK`, `HAZARD`) on the highway. Pruned of freed/0-HP instances each tick and cleared in `cleanup_stage_entities()`. |
| `active_destruction_fx` | `Array[Node3D]` | `[]` | Active 3D shatter/explosion bursts. Stepped in `step(delta)` and `_process(delta)`, freed when `elapsed >= DESTRUCTION_FX_DURATION` or in `cleanup_stage_entities()`. |

## 2. `GiantEnemy3D` Entity Modes, Obstacle Kinematics, & Mech Rig (`scripts/mob_control/GiantEnemy3D.gd`)

| Field / Enum | Type | Default / Value | Constraints & Invariants |
|---|---|---|---|
| `EntityMode` | `enum` | `{ BASE, PYLON, WALL, MOVING_BLOCK, HAZARD }` | Defines visual rig, label prefix (`HP:`, `PYLON:`, `VAULT:`, `WALL:`, `ARMOR:`, `HAZARD:`), and combat behavior. |
| `osc_enabled` | `bool` | `false` | True for `EntityMode.MOVING_BLOCK`. |
| `osc_base_x` | `float` | `0.0` | Center X coordinate for horizontal oscillation. |
| `osc_amplitude` | `float` | `2.0` | Horizontal swing amplitude; final X clamped to `[-4.5 + half_width, 4.5 - half_width]`. |
| `osc_speed` | `float` | `2.2` | Angular oscillation speed in rad/s. |
| `osc_phase` | `float` | `0.0` | Initial phase offset in radians. |
| `osc_time` | `float` | `0.0` | Accumulated oscillation time in seconds. |
| `hit_flash_timer` | `float` | `0.0` | Set to `0.10` on `take_damage()`, counts down to `0.0` in `step_visuals(delta)`. |
| `mech_model` | `Node3D` | `null` | Procedural multi-part 3D visual hierarchy (`MechModel3D`) containing `>= 4` child `MeshInstance3D` nodes. |

## 3. `MobUnit3D` Articulated 3D Robot Raider Rig (`scripts/mob_control/MobUnit3D.gd`)

| Field | Type | Default / Value | Constraints & Invariants |
|---|---|---|---|
| `raider_model` | `Node3D` | `null` | Constructed when `team == "red"`; contains `Head`, `Visor`, `Torso`, `LeftArmPivot`, `RightArmPivot`, `LeftLegPivot`, `RightLegPivot` child meshes. |
| `anim_time` | `float` | `0.0` | Advances by `delta` in `step_visuals(delta)` to drive counter-phase arm/leg stride rotation (`sin(anim_time * 12.0)`). |

## 4. State Transitions

1. **Wave Progression**:
   - `init_stage(stage_idx)` $\rightarrow$ `current_wave = 1`, `total_waves_in_stage = cfg.get("waves", 3)`, spawns Wave 1 obstacles in `active_obstacles`.
   - During `step(delta)`, when `active_obstacles.is_empty()` and `current_wave < total_waves_in_stage` and `giant_enemy.hp > 0` $\rightarrow$ `current_wave += 1`, spawns Wave `current_wave` obstacles and a raider squad.
2. **Obstacle & Boss Destruction**:
   - `obstacle.hp <= 0` $\rightarrow$ remove from `active_obstacles`, `_spawn_destruction_fx(...)`, `obstacle.queue_free()`.
   - `pylon.hp <= 0` $\rightarrow$ remove from `active_pylons`, `_spawn_destruction_fx(...)`, `pylon.queue_free()`.
   - `vault.hp <= 0` $\rightarrow$ unlock gate, remove from `active_vaults`, `_spawn_destruction_fx(...)`, `vault.queue_free()`.
   - `giant_enemy.hp <= 0` $\rightarrow$ `giant_enemy.visible = false`, `_spawn_destruction_fx(...)`, transition `state` to `STAGE_CLEAR` or `VICTORY`.
   - `giant_enemy.reset(p_hp)` $\rightarrow$ `giant_enemy.visible = true`, `hit_flash_timer = 0.0`.
