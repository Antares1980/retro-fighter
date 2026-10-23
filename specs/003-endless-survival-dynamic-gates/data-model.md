# Phase 1 Data Model: Endless Survival Phase, Dynamic Scrolling & Respawning Gates, Gate-Crushing Bosses, & Escalating Enemy Waves

## 1. `MobControlMain` Survival & Spawner State (`scripts/mob_control/MobControlMain.gd`)

| Property / Constant | Type | Default / Value | Constraints & Role |
|---|---|---|---|
| `GATE_SCROLL_SPEED` | `const float` | `1.8` | Forward (`+Z`) drift speed of `MultiplierGate3D` blocks (units/sec). Must be `< BOSS_BASE_SPEED`. |
| `GATE_DESPAWN_Z` | `const float` | `8.2` | Bottom-of-screen Z threshold where gates disappear and are freed (`queue_free()`). |
| `GATE_SPAWN_Z` | `const float` | `-16.5` | Upper-highway Z coordinate where newly spawned random gates appear. |
| `BOSS_BASE_SPEED` | `const float` | `2.6` | Baseline forward (`+Z`) march speed of advancing Bosses (`> GATE_SCROLL_SPEED`). |
| `BOSS_BASE_HP` | `const int` | `140` | Initial HP of a spawned survival Boss at `t = 0.0s`. |
| `survival_mode` | `bool` | `true` | True during the default Single Endless Survival Phase; set to `false` when `init_stage(idx)` is explicitly called. |
| `dynamic_gates_enabled` | `bool` | `true` | Enables gate forward scrolling, bottom despawning, and upper-highway respawning. |
| `bosses_defeated` | `int` | `0` | Number of advancing Bosses killed during the current survival run (`>= 0`). |
| `soldiers_defeated` | `int` | `0` | Number of Red Robot Soldiers killed during the current survival run (`>= 0`). |
| `best_survival_time` | `float` | `0.0` | Highest `time_elapsed` recorded across survival runs in the current session (`>= 0.0`). |
| `active_bosses` | `Array[GiantEnemy3DScript]` | `[]` | Active lane-sized 3D Mech Bosses marching down the highway. |
| `gate_spawn_timer` | `float` | `0.0` | Accumulator for spawning new random `+N` / `xN` gates (`>= 0.0`). |
| `next_gate_spawn_interval` | `float` | `3.2` | Target interval before the next random gate spawns (`in [2.4, 4.2]`). |
| `boss_spawn_timer` | `float` | `0.0` | Accumulator for spawning advancing Bosses (`>= 0.0`). |
| `next_boss_spawn_interval` | `float` | `8.5` | Target interval before the next Boss spawns (`>= 3.5`). |
| `next_soldier_spawn_interval` | `float` | `1.2` | Target interval before the next Soldier squad burst spawns (`>= 0.25`). |

## 2. `MultiplierGate3D` Motion & Oscillation State (`scripts/mob_control/MultiplierGate3D.gd`)

| Property | Type | Default | Constraints & Validation Rules |
|---|---|---|---|
| `scroll_speed` | `float` | `1.8` | Forward (`+Z`) speed in units/sec (`>= 0.0`). |
| `move_enabled` | `bool` | `true` | When true, `step_gate(delta)` advances `position.z += scroll_speed * delta`. |
| `osc_enabled` | `bool` | `false` | When true, `step_gate(delta)` oscillates `position.x` around `osc_base_x`. |
| `osc_base_x` | `float` | `0.0` | Center X coordinate for horizontal oscillation (`in [-2.8, 2.8]`). |
| `osc_amplitude` | `float` | `1.4` | Horizontal swing amplitude (`>= 0.0`), clamped so `position.x in [-3.2, 3.2]`. |
| `osc_speed` | `float` | `1.8` | Angular frequency in rad/sec for horizontal oscillation (`> 0.0`). |
| `osc_time` | `float` | `0.0` | Accumulated oscillation time (`>= 0.0`). |

## 3. `GiantEnemy3D` Advancing Boss State (`scripts/mob_control/GiantEnemy3D.gd`)

| Property | Type | Default | Constraints & Validation Rules |
|---|---|---|---|
| `entity_mode` | `EntityMode` | `EntityMode.BASE` | Uses composite 3D Armored Mech visual rig (`>= 6` parts). |
| `half_width` | `float` | `1.55` (Survival Boss) / `2.0` (Default) | Lane-sized width (`3.1` total width) for advancing Survival Bosses so multiple Bosses fit across the highway. |
| `speed` | `float` | `2.6` (Survival Boss) | Forward (`+Z`) march speed (`> GATE_SCROLL_SPEED`). |
| `anim_time` | `float` | `0.0` | Drives subtle mech marching stride/bob in `step_visuals(delta)` when `speed > 0.0`. |

## 4. State Transitions

1. **Survival Phase Start (`_ready()` / `init_survival_phase()`)**:
   - Sets `survival_mode = true`, `dynamic_gates_enabled = true`, `state = GameState.PLAYING`, `time_elapsed = 0.0`, `bosses_defeated = 0`, `soldiers_defeated = 0`.
   - Hides/disables the static full-width scene `giant_enemy` (`giant_enemy.visible = false`), clears any static `active_obstacles`, resets the 4 initial scene gates to ` (-2.5, 1.0, -2.0)`, `(2.5, 1.0, -2.0)`, `(-2.5, 1.0, -8.0)`, `(2.5, 1.0, -8.0)` with `move_enabled = true` and `scroll_speed = GATE_SCROLL_SPEED`, and spawns the first advancing Boss in `active_bosses` at `Z = -21.0`.
2. **Gate Lifecycle (`Active -> Bottom Despawn` or `Active -> Crushed by Boss`)**:
   - Every tick: `gate.step_gate(delta)` advances `gate.position.z`.
   - If `gate.global_position.z >= GATE_DESPAWN_Z` (`8.2`): removed from scene (`queue_free()`).
   - If overlapped by any Boss in `active_bosses`: `on_boss_destroy_gate(boss, gate)` spawns a 3D shatter FX (`active_destruction_fx`) and frees the gate (`queue_free()`).
3. **Boss Lifecycle (`Active -> Destroyed by Player` or `Active -> Breaches Cannon Line`)**:
   - If `boss.hp <= 0`: spawns a 3D Mech explosion FX (`active_destruction_fx`), increments `bosses_defeated += 1`, removes from `active_bosses`, frees `boss`, and keeps `state == GameState.PLAYING`.
   - If `boss.global_position.z >= 9.0` (or any live `red_mob.global_position.z >= 9.0`): transitions `state` to `GameState.DEFEAT` and shows final `time_elapsed` and `bosses_defeated` on `defeat_banner`.
