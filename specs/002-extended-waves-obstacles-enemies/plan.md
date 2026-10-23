# Implementation Plan: Extended Multi-Wave Stages, Highway Obstacles, Articulated Enemy Silhouettes, and Destruction Lifecycle

**Branch**: `feat/002-extended-waves-obstacles-enemies` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-extended-waves-obstacles-enemies/spec.md`

## Summary

Extend Mob Control 3D stages into multi-wave highway battles (~2–3+ minutes per stage) with automatic Stage 1 initialization, balanced gate-charge bullet power scaling (`GATE_CHARGE_THRESHOLD = 35`, `MAX_BULLET_POWER = 25`), three categories of destructible/oscillating/hazard 3D highway obstacles (`WALL`, `MOVING_BLOCK`, `HAZARD`), articulated 3D humanoid/robot raider forms for Red enemies (`MobUnit3D`), composite 3D Armored Mech/Fortress forms for Giant Bosses/Pylons/Obstacles (`GiantEnemy3D`), and immediate hit-flash feedback plus 3D shatter/explosion animations (`active_destruction_fx`) that completely remove or hide all `0 HP` entities from the screen.

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.3) + Python 3.11 (static contract test suite)

**Primary Dependencies**: Godot 4.3 Core (`Node3D`, `Area3D`, `MeshInstance3D`, `StandardMaterial3D`, `BoxMesh`, `CylinderMesh`, `SphereMesh`, `CapsuleMesh`, `Label3D`), Python `unittest`

**Storage**: N/A (in-memory deterministic arcade state)

**Testing**: `python -m unittest discover -s tests` and `godot --headless -s res://tests/test_runner.gd`

**Target Platform**: Desktop (Windows / Linux headless CI)

**Project Type**: 2D/3D Arcade Game Hub (Godot 4.3 project)

**Performance Goals**: 60 FPS (`physics_ticks_per_second = 60`) with up to `MAX_MOBS = 300` active projectiles, multi-part 3D enemy/obstacle rigs, and transient 3D debris bursts

**Constraints**: Zero regression on Scenarios 1–15 and 2D Retro Fighter suites; cold-cache headless script compilation (`preload` constants, untyped `Variant` deletion guards); `0 HP` entities must never remain visible on screen

**Scale/Scope**: 5 progressive campaign stages, 3–5 waves per stage, 3 obstacle archetypes, 5 modified files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Deterministic Step-Driven Simulation**: **PASS** — Wave obstacle oscillation, raider limb stride animation, gate-charge accumulation, and 3D destruction debris trajectories all step deterministically inside `step(delta)`.
- **II. Cross-Game Viewport & Input Isolation**: **PASS** — Dynamic `1152x672` `CANVAS_ITEMS` viewport activation and `384x224` `VIEWPORT` restoration remain untouched.
- **III. Dual-Layer Automated Verification (NON-NEGOTIABLE)**: **PASS** — Both `tests/test_mob_control.py` and `tests/test_mob_control.gd` (Scenario 16) are updated and executed in headless CI.
- **IV. Headless & Cold-Cache Execution Safety**: **PASS** — All 3D rigs and debris fragments use built-in procedural Godot `PrimitiveMesh` classes and `preload(...)` script constants with `is_inside_tree()` guards.
- **V. Bounded Entity Caps, Power Scaling, & Spatial Clarity**: **PASS** — Enforces `MAX_MOBS = 300`, `MAX_CANNONS = 5`, `GATE_CHARGE_THRESHOLD = 35`, and `MAX_BULLET_POWER = 25`, with moving obstacles clamped strictly to `[-4.5, +4.5]`.
- **VI. Articulated 3D Visuals & Zero-HP Destruction Lifecycle**: **PASS** — Red enemies and Bosses/Obstacles build multi-part 3D silhouettes, flash on hit, spawn 3D shatter debris on `HP <= 0`, and immediately free or hide (`giant_enemy.visible = false`) so no `HP: 0` entity ever lingers on screen.

## Project Structure

### Documentation (this feature)

```text
specs/002-extended-waves-obstacles-enemies/
├── plan.md                                              # This file (/speckit-plan output)
├── research.md                                          # Phase 0 output (/speckit-plan)
├── data-model.md                                        # Phase 1 output (/speckit-plan)
├── quickstart.md                                        # Phase 1 output (/speckit-plan)
├── contracts/
│   └── mob-control-waves-obstacles-contracts.md         # Phase 1 output (/speckit-plan)
├── checklists/
│   ├── requirements.md                                  # Spec quality checklist (/speckit-specify)
│   └── gameplay-and-visuals.md                          # Domain requirements checklist (/speckit-checklist)
└── tasks.md                                             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
scenes/mob_control/
├── Cannon3D.tscn
├── GiantEnemy3D.tscn
├── MobControlMain.tscn
├── MobUnit3D.tscn
└── MultiplierGate3D.tscn

scripts/mob_control/
├── Cannon3D.gd
├── GiantEnemy3D.gd          # Modified: EntityMode (WALL, MOVING_BLOCK, HAZARD), 3D Mech/Obstacle rigs, hit-flash, reset visibility
├── MobControlMain.gd        # Modified: Auto init_stage(0), multi-wave obstacle spawner, gate-charge cap, destruction FX, Boss hide on 0 HP
├── MobUnit3D.gd             # Modified: Composite 3D Robot Raider rig & stride animation for Red enemies
└── MultiplierGate3D.gd

tests/
├── test_mob_control.gd      # Modified: Add Scenario 16 verifying GWT 1–5
└── test_mob_control.py      # Modified: Add static contract tests for waves, obstacles, 3D rigs, and destruction FX
```

**Structure Decision**: Single Godot 4.3 project structure preserving existing `scenes/mob_control/`, `scripts/mob_control/`, and `tests/` layout.

## Complexity Tracking

No Constitution violations. All 6 core principles pass without exception.
