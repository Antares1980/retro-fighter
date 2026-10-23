# Implementation Plan: Always-On Auto-Fire Cannons, Uninterrupted Muzzle Volleys, & Aggressive Time-Escalating Enemy Horde

**Branch**: `feat/auto-fire-horde-escalation` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-auto-fire-horde-escalation/spec.md`

## Summary

Enable **Always-On Automatic Cannon Firing** (`auto_fire = true` by default in `Cannon3D.gd`) so cannons shoot continuously every `0.14s` during `GameState.PLAYING` without requiring `SPACE` or `J` input, and update `UI/ControlsHint` in `MobControlMain.tscn` to `"A/D or ARROWS: STEER | ESC: MENU"`. Eliminate multi-second firing pauses at the `MAX_MOBS = 300` cap by tightening the upper-highway cleanup bound in Survival Mode to `SURVIVAL_CLEANUP_BOUND_Z = -24.5` (right past the enemy spawn line) and adding `_recycle_furthest_blue_mob()` in `_on_cannon_shoot_requested()` so the furthest-downrange blue bullet (lowest `Z`) is recycled whenever a cannon volley is emitted at the 300-mob limit. Pace Survival Mode cannon and bullet power progression (`CANNON_UNLOCK_CHARGE_THRESHOLD = 12`, `GATE_POWER_EARLY_THRESHOLD = 10`, `GATE_CHARGE_THRESHOLD = 35`), and overhaul `_step_survival_spawners(delta)` with aggressive time-escalating Soldier & Boss waves (`get_soldier_min_burst()`, `get_soldier_max_burst()`, `get_scaled_soldier_power()`, `get_max_concurrent_bosses()`, `get_scaled_boss_hp()`) while preserving 100% backward compatibility with legacy test scenarios (`Scenarios 1–17`).

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.3) + Python 3.11 (static contract test suite)

**Primary Dependencies**: Godot 4.3 Core (`Node3D`, `Area3D`, `MeshInstance3D`, `StandardMaterial3D`, `BoxMesh`, `CapsuleMesh`, `Label3D`, `RandomNumberGenerator`), Python `unittest`

**Storage**: N/A (in-memory deterministic arcade state)

**Testing**: `python -m unittest discover -s tests` and `godot --headless -s res://tests/test_runner.gd`

**Target Platform**: Desktop (Windows / Linux headless CI)

**Project Type**: 2D/3D Arcade Game Hub (Godot 4.3 project)

**Performance Goals**: 60 FPS (`physics_ticks_per_second = 60`) with `MAX_MOBS = 300` active projectiles, uninterrupted `0.14s` multi-cannon auto-fire volleys, and escalating Soldier/Boss waves

**Constraints**: Zero regression on Scenarios 1–17 and 2D Retro Fighter suites; cold-cache headless script compilation (`preload` constants, untyped `Variant` deletion guards); center lane `X = 0.0` kept clear during `t in [0.0, 1.0s]` for `Scenario 2` baseline cadence tests

**Scale/Scope**: 5 modified project files (`Cannon3D.gd`, `MobControlMain.gd`, `MobControlMain.tscn`, `test_mob_control.gd`, `test_mob_control.py`) + `.specify/memory/constitution.md`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Deterministic Step-Driven Simulation**: **PASS** — `Cannon3D` auto-fire cadence (`0.14s`), `_recycle_furthest_blue_mob()`, `SURVIVAL_CLEANUP_BOUND_Z = -24.5`, and time-escalating Soldier/Boss spawners all step deterministically inside `step(delta)`.
- **II. Cross-Game Viewport & Input Isolation**: **PASS** — Dynamic `1152x672` `CANVAS_ITEMS` viewport activation and `384x224` `VIEWPORT` restoration remain intact; `project.godot` input actions remain preserved for 2D Fighter compatibility.
- **III. Dual-Layer Automated Verification (NON-NEGOTIABLE)**: **PASS** — Both `tests/test_mob_control.py` and `tests/test_mob_control.gd` (`Scenario 18` + updated `Scenario 7` / `Scenario 17`) are updated and verified in headless CI.
- **IV. Headless & Cold-Cache Execution Safety**: **PASS** — Uses explicit `preload(...)` script constants, untyped `Variant` deletion guards, and `is_inside_tree()` checks.
- **V. Bounded Entity Caps, Power Scaling, & Spatial Clarity**: **PASS** — Enforces `MAX_MOBS = 300` with `_recycle_furthest_blue_mob()` at the muzzle and `SURVIVAL_CLEANUP_BOUND_Z = -24.5` at the top of the highway, plus paced survival upgrade thresholds (`CANNON_UNLOCK_CHARGE_THRESHOLD = 12`, `GATE_POWER_EARLY_THRESHOLD = 10`, `GATE_CHARGE_THRESHOLD = 35`) up to `MAX_BULLET_POWER = 25`.
- **VI. Articulated 3D Visuals & Zero-HP Destruction Lifecycle**: **PASS** — Scaled Red Soldiers and advancing Bosses retain composite 3D rigs, hit-flash feedback, and 3D shatter/explosion animations at `0 HP`.
- **VII. Dynamic Highway Motion, Auto-Fire Cannons, & Endless Survival Escalation**: **PASS** — Cannons auto-fire continuously without `SPACE`/`J` input, HUD displays `"A/D or ARROWS: STEER | ESC: MENU"`, and Soldier/Boss waves scale aggressively in count, frequency, and HP over `time_elapsed`.

## Project Structure

### Documentation (this feature)

```text
specs/004-auto-fire-horde-escalation/
├── plan.md                                              # This file (/speckit-plan output)
├── research.md                                          # Phase 0 output (/speckit-plan)
├── data-model.md                                        # Phase 1 output (/speckit-plan)
├── quickstart.md                                        # Phase 1 output (/speckit-plan)
├── contracts/
│   └── auto-fire-horde-escalation-contracts.md          # Phase 1 output (/speckit-plan)
├── checklists/
│   ├── requirements.md                                  # Spec quality checklist (/speckit-specify)
│   └── auto-fire-and-escalation.md                      # Domain requirements checklist (/speckit-checklist)
└── tasks.md                                             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
scenes/mob_control/
├── Cannon3D.tscn
├── GiantEnemy3D.tscn
├── MobControlMain.tscn      # Modified: Update UI/ControlsHint text to "A/D or ARROWS: STEER | ESC: MENU"
├── MobUnit3D.tscn
└── MultiplierGate3D.tscn

scripts/mob_control/
├── Cannon3D.gd              # Modified: Add auto_fire: bool = true (default true), remove SPACE/J firing dependency when auto_fire is true
├── GiantEnemy3D.gd
├── MobControlMain.gd        # Modified: SURVIVAL_CLEANUP_BOUND_Z = -24.5, _recycle_furthest_blue_mob(), paced survival upgrades, aggressive Soldier/Boss escalation (get_soldier_min_burst, get_soldier_max_burst, get_scaled_soldier_power, get_max_concurrent_bosses, get_scaled_boss_hp)
├── MobUnit3D.gd
└── MultiplierGate3D.gd

tests/
├── test_mob_control.gd      # Modified: Update Scenario 2/7/8 for auto_fire compatibility and add Scenario 18 verifying GWT 1–5
└── test_mob_control.py      # Modified: Add static contract tests for auto_fire, _recycle_furthest_blue_mob, SURVIVAL_CLEANUP_BOUND_Z, and aggressive horde escalation
```

**Structure Decision**: Single Godot 4.3 project structure preserving existing `scenes/mob_control/`, `scripts/mob_control/`, and `tests/` layout.

## Complexity Tracking

No Constitution violations. All 7 core principles pass without exception.
