# Implementation Plan: Endless Survival Phase, Dynamic Scrolling & Respawning Gates, Gate-Crushing Bosses, & Escalating Enemy Waves

**Branch**: `feat/endless-survival-dynamic-gates` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/003-endless-survival-dynamic-gates/spec.md`

## Summary

Transform Mob Control 3D's default gameplay into a single continuous **Endless Survival Phase** (`survival_mode = true`) where the objective is to survive as long as possible. All `xN` and `+N` multiplier gates (`MultiplierGate3D`) actively advance forward (`+Z`) down the highway (with optional horizontal lane oscillation), disappear upon reaching the bottom of the screen (`Z >= 8.2`), and continuously respawn with randomized operations and values in the upper highway (`Z <= -14.0`). Static road obstacles are removed in Survival Mode; all enemies—3D Robot Soldiers (`MobUnit3D`) and lane-sized 3D Mech Bosses (`GiantEnemy3D` in `active_bosses`)—actively march forward (`+Z`) from randomized horizontal lanes. Advancing Bosses move faster than drifting gates and shatter/destroy any `xN` or `+N` gate they overlap (`_spawn_destruction_fx`), while Soldier and Boss spawners escalate continuously with `time_elapsed`. Backward compatibility with `init_stage(stage_idx)` and `STAGES` is preserved so all existing automated tests (`Scenarios 1–16`) pass alongside the new `Scenario 17` suite.

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.3) + Python 3.11 (static contract test suite)

**Primary Dependencies**: Godot 4.3 Core (`Node3D`, `Area3D`, `MeshInstance3D`, `StandardMaterial3D`, `BoxMesh`, `CapsuleMesh`, `Label3D`, `RandomNumberGenerator`), Python `unittest`

**Storage**: N/A (in-memory deterministic arcade state)

**Testing**: `python -m unittest discover -s tests` and `godot --headless -s res://tests/test_runner.gd`

**Target Platform**: Desktop (Windows / Linux headless CI)

**Project Type**: 2D/3D Arcade Game Hub (Godot 4.3 project)

**Performance Goals**: 60 FPS (`physics_ticks_per_second = 60`) with up to `MAX_MOBS = 300` active projectiles, dynamic scrolling/respawning gates, multiple concurrent lane-sized 3D Mech Bosses, and transient 3D shatter debris bursts

**Constraints**: Zero regression on Scenarios 1–16 and 2D Retro Fighter suites; cold-cache headless script compilation (`preload` constants, untyped `Variant` deletion guards); center lane `X = 0.0` kept clear during `t in [0.0, 1.0s]` for `Scenario 2` baseline cadence tests

**Scale/Scope**: Single continuous survival phase + 5 legacy campaign stages preserved for test compatibility, 5 modified files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Deterministic Step-Driven Simulation**: **PASS** — Gate forward scrolling (`step_gate(delta)`), Boss forward marching, Boss-vs-Gate shatter resolution, and time-escalating Soldier/Boss spawners all step deterministically inside `step(delta)`.
- **II. Cross-Game Viewport & Input Isolation**: **PASS** — Dynamic `1152x672` `CANVAS_ITEMS` viewport activation and `384x224` `VIEWPORT` restoration remain intact.
- **III. Dual-Layer Automated Verification (NON-NEGOTIABLE)**: **PASS** — Both `tests/test_mob_control.py` and `tests/test_mob_control.gd` (`Scenario 17`) are updated and verified in headless CI.
- **IV. Headless & Cold-Cache Execution Safety**: **PASS** — Uses explicit `preload(...)` script constants, untyped `Variant` deletion guards, and `is_inside_tree()` checks.
- **V. Bounded Entity Caps, Power Scaling, & Spatial Clarity**: **PASS** — Enforces `MAX_MOBS = 300`, `MAX_CANNONS = 5`, `GATE_CHARGE_THRESHOLD = 35`, and `MAX_BULLET_POWER = 25`, with moving gates clamped strictly to `[-3.2, +3.2]` and highway entities within `[-4.5, +4.5]`.
- **VI. Articulated 3D Visuals & Zero-HP Destruction Lifecycle**: **PASS** — Bosses and Soldiers use composite 3D rigs, and both `0 HP` Bosses and Boss-crushed `MultiplierGate3D` instances spawn 3D shatter debris (`_spawn_destruction_fx`) and are immediately freed/removed from screen.
- **VII. Dynamic Highway Motion, Scrolling Gates, & Endless Survival Escalation**: **PASS** — Default gameplay runs in `survival_mode = true` with moving/despawning/respawning `xN`/`+N` gates, gate-crushing advancing Bosses, and time-escalating Soldier/Boss waves while preserving `init_stage()` for regression suites.

## Project Structure

### Documentation (this feature)

```text
specs/003-endless-survival-dynamic-gates/
├── plan.md                                              # This file (/speckit-plan output)
├── research.md                                          # Phase 0 output (/speckit-plan)
├── data-model.md                                        # Phase 1 output (/speckit-plan)
├── quickstart.md                                        # Phase 1 output (/speckit-plan)
├── contracts/
│   └── survival-dynamic-gates-contracts.md              # Phase 1 output (/speckit-plan)
├── checklists/
│   ├── requirements.md                                  # Spec quality checklist (/speckit-specify)
│   └── survival-gameplay.md                             # Domain requirements checklist (/speckit-checklist)
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
├── GiantEnemy3D.gd          # Modified: Dynamic width scaling in _build_entity_model(), mech marching stride bob in step_visuals(delta)
├── MobControlMain.gd        # Modified: Single Endless Survival Phase (init_survival_phase), scrolling/despawning/respawning gates, active_bosses spawner, Boss-vs-Gate destruction, time-escalating Soldier & Boss waves
├── MobUnit3D.gd
└── MultiplierGate3D.gd      # Modified: scroll_speed, move_enabled, horizontal lane oscillation, step_gate(delta)

tests/
├── test_mob_control.gd      # Modified: Add Scenario 17 verifying GWT 1–5 while preserving Scenarios 1–16
└── test_mob_control.py      # Modified: Add static contract tests for survival mode, gate scrolling/respawning, boss gate crushing, and escalating spawners
```

**Structure Decision**: Single Godot 4.3 project structure preserving existing `scenes/mob_control/`, `scripts/mob_control/`, and `tests/` layout.

## Complexity Tracking

No Constitution violations. All 7 core principles pass without exception.
