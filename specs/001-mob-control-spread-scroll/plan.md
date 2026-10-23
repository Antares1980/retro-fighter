# Implementation Plan: Mob Control 3D Visual Gate Duplication Spread, High-Resolution Display, and Forward Highway Motion

**Branch**: `001-mob-control-spread-scroll` | **Date**: 2026-10-23 | **Spec**: [spec.md](file:///c:/Users/rogal/workspaces/ws-games/retro-fighter/specs/001-mob-control-spread-scroll/spec.md)

**Input**: Feature specification from `/specs/001-mob-control-spread-scroll/spec.md` and `docs/draft-requisites/implementation-plan.md`

## Summary

Fix three visual and gameplay feedback issues in **Mob Control 3D**:
1. **Lateral & Staggered Gate Duplication Spread**: Offset the passing parent Blue Mob and its spawned clones into side-by-side horizontal slots (`CLONE_SPACING_X = 0.55`, up to `5` per row with `CLONE_SPACING_Z = 0.50` row staggering, clamped within `[-4.5, +4.5]`) in `MobControlMain.on_mob_entered_gate()` so duplicated projectiles visibly separate into a wider swarm rather than superimposing on a single `(X, Z)` column.
2. **Dynamic High-Resolution 3D Viewport (`1152x672`) with Retro Restoration (`384x224`)**: Dynamically switch the active `Window` / `Viewport` to `1152x672` (`CONTENT_SCALE_MODE_CANVAS_ITEMS`, `MSAA_4X`) when `MobControlMain` enters the scene tree and restore `384x224` (`CONTENT_SCALE_MODE_VIEWPORT`, `MSAA_DISABLED`) on exit or menu return, paired with high-res UI font sizes and linear-filtered `Label3D` text.
3. **Deterministic Forward Highway Scrolling Illusion**: Add a `RoadDecor` container with repeating center/lane dashed stripes and roadside marker pillars that advance toward the camera (`+Z` at `ROAD_SCROLL_SPEED = 8.0`) during `GameState.PLAYING`, wrap modularly across `[-52.0, +12.0]`, and pause immediately on `STAGE_CLEAR`, `VICTORY`, or `DEFEAT`.

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.3) & Python 3.11 (`unittest`)

**Primary Dependencies**: Godot Engine 4.3 (`Forward Plus`), Python standard library (`unittest`, `pathlib`, `re`)

**Storage**: N/A (in-memory deterministic scene state)

**Testing**: `python -m unittest discover -s tests` (static/contract suite) and `godot --headless -s res://tests/test_runner.gd` (headless engine runtime suite)

**Target Platform**: Desktop (Windows / Linux x86_64 via Godot 4.3, plus headless CI on Ubuntu)

**Project Type**: 2D/3D Arcade Game Hub (Godot 4.3 project)

**Performance Goals**: Deterministic 60 Hz physics tick rate (`physics_ticks_per_second = 60`), bounded at `MAX_MOBS = 300` active/pending Blue Mobs

**Constraints**: Preserve `project.godot` baseline (`384x224`, `stretch/mode = "viewport"`) and 100% backwards compatibility with all existing Retro Fighter 2D, Arcade Hub Menu, and Mob Control 3D Stage 1–5 progression tests; cold-cache headless execution safety (`preload` script constants, `is_inside_tree()` guards)

**Scale/Scope**: Single INVEST Pattern A slice touching 6 files (`scripts/mob_control/MobControlMain.gd`, `scenes/mob_control/MobControlMain.tscn`, `scenes/mob_control/MultiplierGate3D.tscn`, `scenes/mob_control/GiantEnemy3D.tscn`, `tests/test_mob_control.gd`, `tests/test_mob_control.py`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Deterministic Step-Driven Simulation**: **PASS** — Gate formation slot math (`_compute_gate_formation_slot`) is purely algebraic (zero randomness), and highway marker scrolling (`_step_road_scroller(delta)`) runs inside `MobControlMain.step(delta)` gated by `state == GameState.PLAYING`.
- **II. Cross-Game Viewport & Input Isolation**: **PASS** — `project.godot` remains untouched at `384x224` (`viewport` stretch mode). `MobControlMain` applies `1152x672` (`CANVAS_ITEMS`, `MSAA_4X`) in `_ready()` and restores `384x224` (`VIEWPORT`, `MSAA_DISABLED`) in both `return_to_menu()` and `_exit_tree()`.
- **III. Dual-Layer Automated Verification (NON-NEGOTIABLE)**: **PASS** — Both `tests/test_mob_control.py` and `tests/test_mob_control.gd` (Scenario 3 update + new Scenario 14 covering GWT 1–4) are updated and verified.
- **IV. Headless & Cold-Cache Execution Safety**: **PASS** — All `get_window()` and `get_viewport()` calls are guarded by `is_inside_tree()` and null checks; no new bare global `class_name` dependencies are introduced.
- **V. Bounded Entity Caps & Spatial Clarity**: **PASS** — `MAX_MOBS = 300` clamping is preserved prior to formation slot assignment; `CLONE_SPACING_X = 0.55` exceeds `0.44` capsule diameter; row center clamping guarantees `X` in `[-4.5, +4.5]`.

*Post-Phase 1 Re-Evaluation*: All 5 Constitutional Principles pass with zero violations.

## Project Structure

### Documentation (this feature)

```text
specs/001-mob-control-spread-scroll/
├── plan.md                                      # This file (/speckit-plan command output)
├── research.md                                  # Phase 0 output (/speckit-plan command)
├── data-model.md                                # Phase 1 output (/speckit-plan command)
├── quickstart.md                                # Phase 1 output (/speckit-plan command)
├── contracts/
│   └── mob-control-visual-contracts.md          # Phase 1 output (/speckit-plan command)
└── checklists/
    └── requirements.md                          # Spec quality checklist (/speckit-specify output)
```

### Source Code (repository root)

```text
scenes/
├── Menu.tscn
├── Main.tscn
└── mob_control/
    ├── MobControlMain.tscn      # [MODIFY] Add RoadDecor node; scale UI banner/hint font sizes & offsets for 1152x672
    ├── MultiplierGate3D.tscn    # [MODIFY] Set Label3D texture_filter = 5 (LINEAR_WITH_MIPMAPS)
    ├── GiantEnemy3D.tscn        # [MODIFY] Set Label3D texture_filter = 5 (LINEAR_WITH_MIPMAPS)
    ├── Cannon3D.tscn
    └── MobUnit3D.tscn

scripts/
├── Menu.gd
├── Main.gd
└── mob_control/
    ├── MobControlMain.gd        # [MODIFY] Add lateral/staggered gate spread, dynamic 1152x672 viewport switch/restore, and road scroller
    ├── MultiplierGate3D.gd
    ├── GiantEnemy3D.gd
    ├── Cannon3D.gd
    └── MobUnit3D.gd

tests/
├── test_runner.gd
├── test_mob_control.gd          # [MODIFY] Update Scenario 3 lateral spread check; add Scenario 14 (GWT 1-4)
└── test_mob_control.py          # [MODIFY] Add static contract tests for spread, viewport scaling, and road scroller
```

**Structure Decision**: Existing Godot 4.3 repository layout with isolated `scenes/mob_control/` and `scripts/mob_control/` modules and dual-layer tests in `tests/`.

## Complexity Tracking

No Constitution Check violations exist; complexity tracking table is not required.
