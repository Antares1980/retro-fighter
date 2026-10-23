# Phase 0 Research: Mob Control 3D Visual Gate Duplication Spread, High-Resolution Display, and Forward Highway Motion

**Feature**: `001-mob-control-spread-scroll`  
**Date**: 2026-10-23

## 1. Lateral & Staggered Gate Duplication Formation

- **Decision**: Compute deterministic lateral (`X`) and depth (`Z`) formation offsets in `MobControlMain.on_mob_entered_gate(mob, gate)` for the total group $M = 1 + \text{allowed}$ (slot `0` assigned to the entering `mob.position.x`, slots `1..allowed` assigned to spawned clones) with `CLONE_SPACING_X = 0.55`, `MAX_ROW_WIDTH = 5`, `CLONE_SPACING_Z = 0.50`, and highway lateral bounds `[-4.5, +4.5]`.
- **Rationale**:
  - Previously, `on_mob_entered_gate()` spawned every clone at `Vector3(mob.global_position.x, 0.5, gate.global_position.z - 0.6)` without offsetting `mob.position.x` or varying `X`/`Z` across clones. Because `MobUnit3D` capsules have radius `0.22` (diameter `0.44`) and move strictly along `-Z`, all clones superimposed on the same column and looked like a single unduplicated bullet.
  - Spacing units by `CLONE_SPACING_X = 0.55` guarantees `0.55 >= 0.45` horizontal separation (exceeding the `0.44` capsule diameter by `0.11` units of clear air).
  - Shifting the row center `row_center_x = clampf(center_x, -4.5 + half_span, 4.5 - half_span)` before calculating slot offsets ensures that even when a mob enters a gate at the extreme edge (`X = ±4.4`), all units in the row stay strictly inside `[-4.5, +4.5]` while preserving their full `0.55` unit separation.
  - Wrapping groups larger than 5 units (e.g., `+5` gate $\rightarrow$ $M = 6$ total units) into a second row at `z - 0.50` prevents wide formations from overflowing the `4.0`-unit gate width or highway corridor.
- **Alternatives Considered**:
  - *Random jitter around `mob.global_position.x`*: Rejected because random offsets can still randomly overlap capsules and violate Principle I (Deterministic Step-Driven Simulation).
  - *Physics pushbox separation on `MobUnit3D`*: Rejected because enabling 300-unit pairwise physics repulsion in 3D introduces frame-time spikes and nondeterministic lateral drift outside highway lanes.

## 2. Dynamic High-Resolution 3D Viewport & Retro 2D Restoration

- **Decision**: Implement `_apply_high_res_viewport()` (called in `_ready()`) and `_restore_retro_viewport()` (called in `return_to_menu()` and `_exit_tree()`) on `MobControlMain.gd` using:
  - High-Res 3D Profile: `content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS`, `content_scale_size = Vector2i(1152, 672)`, `Viewport.msaa_3d = Viewport.MSAA_4X`.
  - Retro 2D Profile: `content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT`, `content_scale_size = Vector2i(384, 224)`, `Viewport.msaa_3d = Viewport.MSAA_DISABLED`.
  - Guard all window/viewport mutations with `if is_inside_tree() and get_window() != null:` and `if get_viewport() != null:`.
- **Rationale**:
  - `project.godot` sets `viewport_width = 384`, `viewport_height = 224`, and `window/stretch/mode = "viewport"` for the 2D CPS-1 pixel-art fighter, and `tests/test_project_godot.py` / `tests/test_engine_foundation.gd` enforce those exact baseline settings.
  - Switching `Window.content_scale_mode` and `Window.content_scale_size` at runtime inside `MobControlMain` renders the 3D scene and its 2D UI overlay at full `1152x672` window resolution with 4x MSAA, then cleanly restores `384x224` `VIEWPORT` mode upon leaving `MobControlMain`.
- **Alternatives Considered**:
  - *Modifying `project.godot` globally to `1152x672`*: Rejected because it breaks the 2D CPS-1 pixel-art stretch mode, HUD layout, camera bounds (`384x224`), and existing foundation test suites (violating Principle II).
  - *Wrapping `MobControlMain` in a `SubViewportContainer`*: Rejected because it complicates input routing (`_unhandled_input`) and scene tree node paths expected by existing `test_mob_control.gd` scenarios.

## 3. Deterministic Forward Highway Scrolling Illusion

- **Decision**: Add a `RoadDecor` (`Node3D`) container in `MobControlMain.tscn` and populate it deterministically in `_setup_road_scroller()` (invoked from `_ready()`) with repeating center/lane dashed stripes (`X = 0.0`, `X = -5.2`, `X = +5.2`, `Z` every `4.0` units from `-52.0` to `+12.0`) and roadside marker pillars (`X = -6.4`, `X = +6.4`, `Z` every `6.0` units from `-52.0` to `+12.0`). Advance all markers by `+ROAD_SCROLL_SPEED * delta` (`ROAD_SCROLL_SPEED = 8.0`) during Phase 1 of `step(delta)` while `state == GameState.PLAYING`, wrapping markers when `position.z > 12.0` by subtracting `64.0` (`SCROLL_MAX_Z - SCROLL_MIN_Z`).
- **Rationale**:
  - Moving visual road markers toward the camera (`+Z`) at `8.0` units/sec creates an immediate optical flow sensation that the cannon and camera are driving forward along the highway (`-Z`), while keeping `Cannon`, `Gates`, `Vaults`, `Pylons`, and `GiantEnemy` Z-coordinates unchanged so all stage pacing and combat math remain 100% intact.
  - Updating marker positions inside `step(delta)` (after the `if state != GameState.PLAYING: return` guard) ensures scrolling is 100% deterministic in headless tests and automatically halts on `STAGE_CLEAR`, `VICTORY`, and `DEFEAT`.
- **Alternatives Considered**:
  - *Moving the actual `Cannon`, `Camera3D`, `Gates`, and `GiantEnemy` along `-Z` in world space*: Rejected because it invalidates fixed Z-threshold checks (`giant_enemy.global_position.z >= 9.0` for defeat, `z = -22.0` for red spawns, and gate Z positions in `test_mob_control.gd`).
  - *Shader UV scrolling on `Road` mesh*: Rejected because shader UV offsets cannot be inspected via node `position.z` assertions in headless GDScript unit tests and do not provide 3D parallax depth along the roadside.
