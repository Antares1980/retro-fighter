---

description: "Task list for Mob Control 3D Visual Gate Duplication Spread, High-Resolution Display, and Forward Highway Motion"
---

# Tasks: Mob Control 3D Visual Gate Duplication Spread, High-Resolution Display, and Forward Highway Motion

**Input**: Design documents from `/specs/001-mob-control-spread-scroll/`

**Prerequisites**: [plan.md](file:///c:/Users/rogal/workspaces/ws-games/retro-fighter/specs/001-mob-control-spread-scroll/plan.md), [spec.md](file:///c:/Users/rogal/workspaces/ws-games/retro-fighter/specs/001-mob-control-spread-scroll/spec.md), [research.md](file:///c:/Users/rogal/workspaces/ws-games/retro-fighter/specs/001-mob-control-spread-scroll/research.md), [data-model.md](file:///c:/Users/rogal/workspaces/ws-games/retro-fighter/specs/001-mob-control-spread-scroll/data-model.md), [mob-control-visual-contracts.md](file:///c:/Users/rogal/workspaces/ws-games/retro-fighter/specs/001-mob-control-spread-scroll/contracts/mob-control-visual-contracts.md)

**Tests**: Included per Constitution Principle III (Dual-Layer Automated Verification) and `docs/draft-requisites/implementation-plan.md`.

**Organization**: Tasks are grouped by user story (`US1`, `US2`, `US3`) to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`)
- Exact file paths and verbatim data-model constraints are included in each description

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish shared constants and scene container nodes required by the Mob Control 3D visual enhancements.

- [X] T001 Define formation, viewport, and road scroller constants (`HI_RES_SIZE = Vector2i(1152, 672)`, `RETRO_RES_SIZE = Vector2i(384, 224)`, `CLONE_SPACING_X = 0.55`, `CLONE_SPACING_Z = 0.50`, `MAX_ROW_WIDTH = 5`, `HIGHWAY_HALF_WIDTH = 4.5`, `ROAD_SCROLL_SPEED = 8.0`, `ROAD_SCROLL_MIN_Z = -52.0`, `ROAD_SCROLL_MAX_Z = 12.0`) and `road_scroller_nodes: Array[Node3D] = []` in `scripts/mob_control/MobControlMain.gd`
- [X] T002 [P] Add `RoadDecor` (`Node3D`) child container node to root `MobControlMain` in `scenes/mob_control/MobControlMain.tscn` and resolve `@onready var road_decor: Node3D` in `scripts/mob_control/MobControlMain.gd`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core helper methods in `scripts/mob_control/MobControlMain.gd` that support deterministic coordinate slot math and safe out-of-tree/in-tree lifecycle execution.

**âš ï¸ CRITICAL**: Complete before user story phases.

- [X] T003 Implement `_compute_gate_formation_slot(idx: int, total_group: int, anchor_x: float, base_z: float) -> Vector3` in `scripts/mob_control/MobControlMain.gd` enforcing `row_idx = idx / MAX_ROW_WIDTH`, `col_idx = idx % MAX_ROW_WIDTH`, `units_in_row = mini(MAX_ROW_WIDTH, total_group - row_idx * MAX_ROW_WIDTH)`, `half_span = float(units_in_row - 1) * CLONE_SPACING_X * 0.5`, `row_center_x = clampf(anchor_x, -4.5 + half_span, 4.5 - half_span)`, `slot_x = clampf(row_center_x + (float(col_idx) - float(units_in_row - 1) * 0.5) * CLONE_SPACING_X, -4.5, 4.5)`, and `slot_z = base_z - float(row_idx) * CLONE_SPACING_Z`

**Checkpoint**: Foundation ready â€” User Story 1, User Story 2, and User Story 3 can now be implemented.

---

## Phase 3: User Story 1 - Visible Side-by-Side Projectile Multiplication at Gates (Priority: P1) ðŸŽ¯ MVP

**Goal**: Spread the passing parent Blue Mob and its spawned clones into distinct side-by-side (`X`) and staggered row (`Z`) positions within `[-4.5, +4.5]` when passing through multiplier gates (`x2`, `+2`, `x3`, `+5`).

**Independent Test**: Pass 1 Blue Mob through `gate_right_1` (`x2`) and `gate_left_1` (`+2`), call `flush_pending_spawns()`, and verify resulting mobs have distinct `(X, Z)` positions separated horizontally by `>= 0.45` units (`0.55` units) and clamped within `[-4.5, +4.5]`.

### Tests for User Story 1

- [X] T004 [P] [US1] Add static contract assertions for `CLONE_SPACING_X`, `CLONE_SPACING_Z`, `MAX_ROW_WIDTH`, and `_compute_gate_formation_slot` in `tests/test_mob_control.py`
- [X] T005 [US1] Update Scenario 3 clone position assertions for lateral spread and add Scenario 14 GWT 1 & GWT 2 tests (`x2` lateral separation `>= 0.45`, `+2` pairwise distinct coordinates, and `+5` boundary clamp at `X = 4.4` within `[-4.5, +4.5]`) in `tests/test_mob_control.gd`

### Implementation for User Story 1

- [X] T006 [US1] Update `on_mob_entered_gate(mob: MobUnit3DScript, gate: MultiplierGate3DScript)` in `scripts/mob_control/MobControlMain.gd` to compute `total_group = 1 + allowed`, reposition the parent mob (`mob.position.x = parent_slot.x`) to slot `0`, and queue clones at slots `1..allowed` using `_compute_gate_formation_slot(i + 1, total_group, anchor_x, gate.global_position.z - 0.6)`

**Checkpoint**: User Story 1 is complete and independently verifiable via Scenario 3 and Scenario 14 (GWT 1â€“2).

---

## Phase 4: User Story 2 - Crisp High-Resolution 3D Visuals with Clean Retro Menu Restoration (Priority: P2)

**Goal**: Switch the window/viewport dynamically to `1152x672` (`CONTENT_SCALE_MODE_CANVAS_ITEMS`, `MSAA_4X`) when entering `MobControlMain`, scale HUD banners and `Label3D` filtering for sharp 3D readability, and restore `384x224` (`CONTENT_SCALE_MODE_VIEWPORT`, `MSAA_DISABLED`) when returning to the menu or exiting the tree.

**Independent Test**: Add `MobControlMain` to the SceneTree, verify root `Window.content_scale_size == Vector2i(1152, 672)`, `Window.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS`, and `Viewport.msaa_3d == Viewport.MSAA_4X`; invoke `return_to_menu()` or `_exit_tree()` and verify restoration to `Vector2i(384, 224)`, `Window.CONTENT_SCALE_MODE_VIEWPORT`, and `Viewport.MSAA_DISABLED`.

### Tests for User Story 2

- [X] T007 [P] [US2] Add static contract assertions for `HI_RES_SIZE`, `RETRO_RES_SIZE`, `_apply_high_res_viewport`, `_restore_retro_viewport`, `_exit_tree`, and `Label3D` `texture_filter = 5` in `tests/test_mob_control.py`
- [X] T008 [US2] Add Scenario 14 GWT 3 headless runtime assertions in `tests/test_mob_control.gd` verifying `1152x672` `CANVAS_ITEMS` + `MSAA_4X` activation on `_ready()` and `384x224` `VIEWPORT` + `MSAA_DISABLED` restoration on `return_to_menu()` and `_exit_tree()`

### Implementation for User Story 2

- [X] T009 [P] [US2] Configure `Label3D` with `texture_filter = 5` (`BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`) in `scenes/mob_control/MultiplierGate3D.tscn`
- [X] T010 [P] [US2] Configure `Label3D` with `texture_filter = 5` (`BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`) in `scenes/mob_control/GiantEnemy3D.tscn`
- [X] T011 [P] [US2] Update `UI/VictoryBanner`, `UI/DefeatBanner` (`font_size = 32`, `outline_size = 6`, offsets `-360,-70` to `360,70`), and `UI/ControlsHint` (`font_size = 22`, `outline_size = 4`, offsets `-480,-42` to `480,-10`) in `scenes/mob_control/MobControlMain.tscn`
- [X] T012 [US2] Implement `_apply_high_res_viewport()`, `_restore_retro_viewport()`, and `_exit_tree()` in `scripts/mob_control/MobControlMain.gd`, calling `_apply_high_res_viewport()` in `_ready()` and `_restore_retro_viewport()` in both `return_to_menu()` and `_exit_tree()`

**Checkpoint**: User Stories 1 and 2 are complete and independently verifiable.

---

## Phase 5: User Story 3 - Continuous Forward Highway Motion Illusion (Priority: P3)

**Goal**: Populate `RoadDecor` with repeating center/lane dashed stripes and roadside marker pillars that scroll toward the camera (`+Z`) at `ROAD_SCROLL_SPEED = 8.0` during `GameState.PLAYING`, wrap modularly from `+12.0` back to `-52.0`, and pause immediately in `STAGE_CLEAR`, `VICTORY`, or `DEFEAT`.

**Independent Test**: Step `MobControlMain` with `step(1.0 / 60.0)` while `state == GameState.PLAYING` and verify all `road_scroller_nodes` advance by `+8.0 * (1.0 / 60.0)` along `+Z` (wrapping across `[-52.0, +12.0]`), then set `state = GameState.VICTORY` (or `STAGE_CLEAR` / `DEFEAT`) and verify `0.0` displacement on subsequent `step(1.0 / 60.0)` calls.

### Tests for User Story 3

- [X] T013 [P] [US3] Add static contract assertions for `ROAD_SCROLL_SPEED`, `_setup_road_scroller`, `_step_road_scroller`, and `RoadDecor` node presence in `tests/test_mob_control.py`
- [X] T014 [US3] Add Scenario 14 GWT 4 headless runtime assertions in `tests/test_mob_control.gd` verifying forward `+Z` motion during `GameState.PLAYING`, modular wrap-around when exceeding `Z > 12.0` back to `-52.0`, and zero movement during `STAGE_CLEAR`, `VICTORY`, and `DEFEAT`

### Implementation for User Story 3

- [X] T015 [US3] Implement `_setup_road_scroller()` and `_step_road_scroller(delta: float)` in `scripts/mob_control/MobControlMain.gd`, invoking `_setup_road_scroller()` from `_ready()` and `_step_road_scroller(delta)` during Phase 1 of `step(delta)`

**Checkpoint**: All user stories (`US1`, `US2`, `US3`) are complete and independently testable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final verification across both test layers and changelog documentation.

- [X] T016 Run full Python static & contract test suite (`python -m unittest discover -s tests`) and Godot 4.3 headless test suite (`godot --headless -s res://tests/test_runner.gd`) to verify 100% pass rate per `specs/001-mob-control-spread-scroll/quickstart.md`
- [X] T017 Update `CHANGELOG.md` under `## [Unreleased]` documenting the Mob Control 3D gate duplication lateral spread, dynamic `1152x672` viewport scaling, and forward highway scroller changes

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: `T001`â€“`T002` â€” Can start immediately.
- **Foundational (Phase 2)**: `T003` â€” Depends on `T001`; blocks `US1`.
- **User Story 1 (Phase 3 - P1 MVP)**: `T004`â€“`T006` â€” Depends on Phase 2 (`T003`).
- **User Story 2 (Phase 4 - P2)**: `T007`â€“`T012` â€” Depends on Phase 1 (`T001`); scene tasks `T009`, `T010`, `T011` can run in parallel.
- **User Story 3 (Phase 5 - P3)**: `T013`â€“`T015` â€” Depends on Phase 1 (`T001`, `T002`).
- **Polish (Phase 6)**: `T016`â€“`T017` â€” Depends on completion of Phases 3, 4, and 5.

### Parallel Opportunities

- `T009` (`MultiplierGate3D.tscn`), `T010` (`GiantEnemy3D.tscn`), and `T011` (`MobControlMain.tscn`) modify separate scene files and can be executed in parallel.
- Static Python test tasks `T004`, `T007`, and `T013` in `tests/test_mob_control.py` can be authored in parallel with scene updates `T009`â€“`T011`.

---

## Parallel Example: User Story 2

```bash
# Run scene file updates for User Story 2 in parallel:
Task T009: "Configure Label3D with texture_filter = 5 in scenes/mob_control/MultiplierGate3D.tscn"
Task T010: "Configure Label3D with texture_filter = 5 in scenes/mob_control/GiantEnemy3D.tscn"
Task T011: "Update UI/VictoryBanner, UI/DefeatBanner, and UI/ControlsHint in scenes/mob_control/MobControlMain.tscn"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (`T001`â€“`T002`) and Phase 2 (`T003`).
2. Complete Phase 3 (`T004`â€“`T006` for User Story 1).
3. Validate lateral gate duplication spread in `tests/test_mob_control.gd`.

### Incremental Delivery

1. Deliver **US1** (Visible Side-by-Side Projectile Multiplication at Gates).
2. Deliver **US2** (Crisp High-Resolution `1152x672` 3D Visuals & `384x224` Retro Restoration).
3. Deliver **US3** (Continuous Forward Highway Motion Illusion).
4. Execute Phase 6 (`T016`â€“`T017`) full dual-layer regression check and `CHANGELOG.md` update.
