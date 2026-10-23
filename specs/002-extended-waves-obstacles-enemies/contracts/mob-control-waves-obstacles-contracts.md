# Interface & Behavioral Contracts: Extended Multi-Wave Stages, Highway Obstacles, Articulated Enemy Silhouettes, and Destruction Lifecycle

**Feature**: `002-extended-waves-obstacles-enemies`
**Date**: 2026-10-23

## 1. `MobControlMain` Public & Test-Facing Contract (`scripts/mob_control/MobControlMain.gd`)

- **Constants**:
  - `const GATE_CHARGE_THRESHOLD: int = 35`
  - `const MAX_BULLET_POWER: int = 25`
  - `const GIANT_FORTIFIED_SPEED: float = 0.18`
  - `const DESTRUCTION_FX_DURATION: float = 0.45`
- **Stage Table (`STAGES`)**:
  - Each of the 5 stage dictionaries preserves its existing keys (`stage`, `base_hp`, `highway_depth`, `highway_min_z`, `cleanup_bound`, `lock_1`, `lock_2`, `lock_3`, `vault_hp`, `unlocked_gate`, `vault_gate_mult`, `red_spawn_interval`) and includes `"waves": int` (`3`, `4`, `4`, `5`, `5`).
- **Methods**:
  - `init_stage(stage_idx: int) -> void`: Invoked automatically in `_ready()` for `stage_idx = 0`. Resets `current_wave = 1`, `total_waves_in_stage = int(cfg.get("waves", 3))`, restores `giant_enemy.visible = true`, clears old obstacles/FX, and spawns Wave 1 obstacles via `_spawn_wave_obstacles(current_stage_index, current_wave)`.
  - `spawn_obstacle(mode: int, pos: Vector3, hp_val: int, half_w: float = 1.6, osc_amp: float = 0.0, osc_spd: float = 2.2) -> GiantEnemy3DScript`: Spawns and registers a highway obstacle (`WALL`, `MOVING_BLOCK`, or `HAZARD`) in `active_obstacles`.
  - `_spawn_destruction_fx(world_pos: Vector3, extent: Vector3 = Vector3(1.5, 1.5, 1.5), base_color: Color = Color(1.0, 0.65, 0.15)) -> Node3D`: Creates a 3D shatter/explosion burst node with flying debris fragments, adds it to `active_destruction_fx`, and returns it.
  - `_step_destruction_fx(delta: float) -> void`: Advances all active debris fragments and frees expired FX nodes (`elapsed >= DESTRUCTION_FX_DURATION`).

## 2. `GiantEnemy3D` Contract (`scripts/mob_control/GiantEnemy3D.gd`)

- **Enum**:
  - `enum EntityMode { BASE, PYLON, WALL, MOVING_BLOCK, HAZARD }`
- **Methods**:
  - `is_wall() -> bool`, `is_moving_block() -> bool`, `is_hazard() -> bool`
  - `is_obstacle() -> bool`: Returns `true` when `entity_mode in [EntityMode.WALL, EntityMode.MOVING_BLOCK, EntityMode.HAZARD]`.
  - `step_obstacle(delta: float) -> void`: Updates horizontal oscillation for `MOVING_BLOCK` (`position.x` clamped within `[-4.5 + half_width, 4.5 - half_width]`) and steps `hit_flash_timer`.
  - `get_visual_part_count() -> int`: Returns the number of child `MeshInstance3D` parts in `mech_model` (`>= 4`).
  - `is_hit_flashing() -> bool`: Returns `hit_flash_timer > 0.0`.
  - `reset(p_hp: int = 150) -> void`: Restores `visible = true`, `hit_flash_timer = 0.0`, `hp = p_hp`, `max_hp = p_hp`, `position = Vector3(0.0, 1.25, -15.0)`.

## 3. `MobUnit3D` Contract (`scripts/mob_control/MobUnit3D.gd`)

- **Methods**:
  - `setup(p_team: String, p_power: int = -1) -> void`: When `p_team == "red"`, builds `raider_model` (`Node3D`) with `Head`, `Visor`, `Torso`, `LeftArmPivot`, `RightArmPivot`, `LeftLegPivot`, `RightLegPivot` and hides the bare sphere/capsule look; when `p_team == "blue"`, keeps the glowing energy sphere/capsule look and hides `raider_model`.
  - `step_visuals(delta: float) -> void`: Animates limb stride angles on `raider_model` when `team == "red"`.
  - `get_raider_part_count() -> int`: Returns the number of mesh parts in `raider_model` (`>= 6` for Red raiders).
