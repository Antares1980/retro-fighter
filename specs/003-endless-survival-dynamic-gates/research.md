# Phase 0 Research: Endless Survival Phase, Dynamic Scrolling & Respawning Gates, Gate-Crushing Bosses, & Escalating Enemy Waves

## 1. Coexistence of Default Endless Survival Mode and Legacy Stage Tests (`Scenarios 1–16`)

- **Decision**: Introduce `survival_mode: bool = true` and `init_survival_phase()` in `MobControlMain.gd` while keeping `init_stage(stage_idx: int)` for legacy multi-stage tests.
  -Wait: Let's check what `Scenario 16` checks right after `_ready()`!
  - In `tests/test_mob_control.gd` lines 1946–1952:
    `Scenario 16` instantiates `MobControlMainScene`, adds it to the tree (running `_ready()`), and checks:
    - `assert_equal(main.current_stage_index, 0)`
    - `assert_equal(main.giant_enemy.hp, 1200)`
    - `assert_equal(main.current_wave, 1)`
    - `assert_equal(main.total_waves_in_stage, 3)`
    - `assert_equal(main.active_obstacles.size(), 3)`
    - `assert_true(main.wave_status_label.text.contains("STAGE 1/5 | WAVE 1/3"))`
  - **Crucial Insight**: Look at `Scenario 16` in `tests/test_mob_control.gd`! If we update `Scenario 16` to call `main.init_stage(0)` at the start of Part 1 (just like `Scenario 3`, `Scenario 5b`, `Scenario 6`, `Scenario 11`, `Scenario 12`, `Scenario 13`, `Scenario 14`, `Scenario 15` already do!), OR if `init_survival_phase()` is called in `_ready()` and `Scenario 16` calls `main.init_stage(0)` when testing multi-wave stage mode while `Scenario 17` tests the default `_ready()` Survival Mode:
    Let's check if any test in `tests/test_mob_control.py` checks `test_scenario_16` strings:
    In `tests/test_mob_control.py`, it only checks `self.assertIn("test_scenario_16_extended_waves_obstacles_3d_forms_and_destruction_fx", self.test_gd)`.
    Wait—what if `_ready()` initializes `survival_mode = true` via `init_survival_phase()`, AND in `init_survival_phase()` we also set `current_stage_index = 0`, `current_wave = 1`, `total_waves_in_stage = 1` (or `3`), and in `Scenario 16` we call `main.init_stage(0)` at line 1945 to test the legacy multi-wave stage mode?
    Wait: what about `Scenario 2`?
    In `Scenario 2`, `main` is instantiated (`_ready()` runs), and `cannon` at `(0.0, 0.5, 9.0)` fires for `60` frames (`1.0s`). During that `1.0s`, the 7 fired bullets travel from `Z = 9.0` to `Z = 0.0` along `X = 0.0`.
    In `init_survival_phase()`:
    - The 4 initial scene gates (`gate_left_1` at `X = -2.5, Z = -2.0`, `gate_right_1` at `X = 2.5, Z = -2.0`, `gate_left_2` at `X = -2.5, Z = -8.0`, `gate_right_2` at `X = 2.5, Z = -8.0`) scroll forward at `GATE_SCROLL_SPEED = 1.8` along `X = ±2.5` (with `osc_enabled = false` on the 4 initial scene gates so they stay at `X = ±2.5`!).
    - Any initial Boss or Soldier in `init_survival_phase()` spawns at `Z <= -18.0` (so in `1.0s` at speed `2.6..4.2`, it only reaches `Z = -13.8`, nowhere near `Z = 0.0`!).
    - Therefore, during the first `1.0s` at `X = 0.0`, zero gates and zero enemies touch the center-lane bullets in `Scenario 2`, so `Scenario 2` produces `7` live blue mobs as expected!
- **Rationale**: Calling `init_survival_phase()` in `_ready()` gives players the exact Single Endless Survival Phase experience immediately upon launching Mob Control 3D from the menu, while `init_stage(stage_idx)` sets `survival_mode = false` so all stage-specific tests (`Scenarios 3–16`) run their exact deterministic stage scenarios.
- **Alternatives Considered**: Removing `STAGES` and `init_stage()` entirely (rejected because it would break Scenarios 5, 5b, 10, 11, 12, 13, 16).

## 2. Dynamic Gate Scrolling, Despawning, & Respawning Kinematics

- **Decision**:
  - Equip `MultiplierGate3D` with `scroll_speed: float = 1.8`, `move_enabled: bool = true`, `osc_enabled: bool = false`, `osc_base_x: float = 0.0`, `osc_amplitude: float = 1.4`, `osc_speed: float = 1.8`, `osc_time: float = 0.0`, and `step_gate(delta: float)`.
  - During `step(delta)` in `MobControlMain`, when `survival_mode == true` (or `dynamic_gates_enabled == true`), every live gate in `get_all_gates()` calls `gate.step_gate(delta)`, advancing `position.z += scroll_speed * delta`.
  - In Phase 4 bounds cleanup, any gate with `global_position.z >= GATE_DESPAWN_Z` (`8.2`) is removed and freed (`queue_free()`).
  - As `gate_spawn_timer` reaches `next_gate_spawn_interval` (randomized in `[2.6, 4.0]` seconds, or immediately if live gate count drops below `2`), `spawn_random_gate()` instantiates a new `MultiplierGate3D` at `Z = GATE_SPAWN_Z` (`-16.5`), random `X in [-2.8, 2.8]`, with a weighted random operation (`"+"` with value in `[2, 3, 4, 5, 6]` or `"x"` with value in `[2, 3, 4]`) and optional horizontal oscillation.
- **Rationale**: `GATE_SCROLL_SPEED = 1.8` units/s moves a gate across the 25-unit highway in ~14 seconds—fast enough for palpable forward motion while slow enough for players to aim volleys through it and for Bosses (`speed >= 2.6`) to overtake and crush gates in their lane.
- **Alternatives Considered**: Matching `ROAD_SCROLL_SPEED = 8.0` for gates (rejected because gates would cross the screen in 3 seconds and outrun Bosses).

## 3. Boss-vs-Gate Destruction Mechanics

- **Decision**:
  - In Survival Mode, Bosses (`GiantEnemy3D` in `active_bosses`) are lane-sized 3D Armored Mechs (`half_width = 1.55`, `half_depth = 1.0`, `speed >= 2.6`).
  - During Phase 2 Contact Resolution (`_resolve_boss_gate_destruction()`), after `_resolve_gate_contacts()`, iterate through all live Bosses in `active_bosses` and all live gates in `get_all_gates()`.
  - When a Boss overlaps a gate (`abs(boss.x - gate.x) <= boss.half_width + 1.8` and `abs(boss.z - gate.z) <= boss.half_depth + 0.45`), invoke `on_boss_destroy_gate(boss, gate)`:
    1. Spawn a 3D shatter burst at `gate.global_position` (`_spawn_destruction_fx(gate_pos, Vector3(2.5, 1.5, 0.8), Color(0.25, 0.75, 1.0))`).
    2. Mark `gate.is_locked = true` and `gate.queue_free()` so it disappears immediately and cannot duplicate any further bullets.
- **Rationale**: Gives Bosses a high-impact battlefield interaction that punishes ignoring them without ending the run until they reach `Z >= 9.0`.
- **Alternatives Considered**: Having regular Soldiers destroy gates on first touch (rejected because user specifically requested: *"if they are 'bosses' they must to 'destroy' the xN and +N blocks as well"*).

## 4. Escalating Random Spawner Formulas for Soldiers & Bosses

- **Decision**:
  - **Soldier Spawner**:
    - Interval: `maxf(0.25, 1.35 - (time_elapsed / 60.0) * 0.55) * rng.randf_range(0.8, 1.2)`
    - Max squad burst size: `mini(8, 1 + int(floor(time_elapsed / 15.0)))`
    - Burst count: `rng.randi_range(1, max_burst)`
    - Each soldier spawns at `X = rng.randf_range(-4.2, 4.2)`, `Z = -22.0 - float(i) * 0.5`, with `speed = RED_SPEED * clampf(1.0 + time_elapsed / 180.0, 1.0, 1.65)`.
  - **Boss Spawner**:
    - Interval: `maxf(3.5, 10.5 - (time_elapsed / 30.0) * 2.0) * rng.randf_range(0.85, 1.15)`
    - Max concurrent Bosses: `mini(5, 1 + int(floor(time_elapsed / 25.0)))`
    - Boss HP: `140 + int(floor(time_elapsed * 4.5))`
    - Boss speed: `clampf(2.6 + (time_elapsed / 120.0) * 0.8, 2.6, 3.8)`
    - Spawns at `X = rng.randf_range(-2.8, 2.8)`, `Z = -23.5`.
- **Rationale**: Provides smooth, deterministic mathematical scaling from minute 0 to minute 3+ while guaranteeing testable escalation thresholds (`SC-004`).
- **Alternatives Considered**: Fixed scripted wave tables (rejected because the user requested endless randomized escalation over time).
