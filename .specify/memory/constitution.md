# Retro Fighter & Arcade Hub Constitution

## Core Principles

### I. Deterministic Step-Driven Simulation
All gameplay loops across 2D (`Main.gd`, `Fighter.gd`, `AIController.gd`) and 3D (`MobControlMain.gd`,
`Cannon3D.gd`) MUST expose deterministic, frame-decoupled stepping methods (`step(delta)` or integer
tick counters at 60 Hz). Combat resolution, multiplier gate cloning, lateral formation spreading,
shield lock state machines, and environmental highway scrolling MUST execute reproducibly in headless
automated tests without relying on wall-clock timers or asynchronous physics race conditions.

**Rationale**: Frame-accurate fighting mechanics and high-density 3D swarm simulations require
deterministic state transitions so that every Behavior-Driven Development (Given/When/Then) scenario
can be verified reliably in headless CI.

### II. Cross-Game Viewport & Input Isolation
Arcade Hub games MUST isolate their rendering and input configurations without regressing sibling
titles. The project baseline in `project.godot` MUST preserve the CPS-1 2D pixel-art contract
(`viewport_width = 384`, `viewport_height = 224`, `window/stretch/mode = "viewport"`, nearest-neighbor
canvas texture filtering, and `p1_*` / `p2_*` input mappings). Any 3D game mode (such as
`MobControlMain`) requiring high-resolution rendering (`Vector2i(1152, 672)`,
`Window.CONTENT_SCALE_MODE_CANVAS_ITEMS`, `Viewport.MSAA_4X`) MUST apply those overrides dynamically
when entering the scene tree (`_ready()`) and MUST restore the `384x224` `VIEWPORT` mode and
`MSAA_DISABLED` contract when exiting (`return_to_menu()` and `_exit_tree()`).

**Rationale**: Sharing a single Godot project between a 2D CPS-1 pixel-art fighter and a 3D highway
arcade game requires strict lifecycle isolation so high-resolution 3D rendering never breaks 2D
pixel-art layout or engine foundation tests.

### III. Dual-Layer Automated Verification (NON-NEGOTIABLE)
Every feature, slice, or bug fix MUST be verified by both automated test layers before completion:
1. **Python Static & Contract Suite** (`python -m unittest discover -s tests`): Validates `.tscn` node
   hierarchies, `.gd` script signatures and constants, mathematical invariants, and `project.godot`
   settings.
2. **Godot 4.3 Headless Runtime Suite** (`godot --headless -s res://tests/test_runner.gd`): Validates
   in-engine runtime behavior and Given/When/Then (GWT) acceptance criteria across all registered test
   suites.

**Rationale**: Static contract tests catch scene/script wiring drift in milliseconds, while headless
Godot execution guarantees real engine runtime compliance without manual GUI intervention.

### IV. Headless & Cold-Cache Execution Safety
All GDScript files MUST parse, compile, and run cleanly in cold headless environments
(`godot --headless`) without requiring a pre-existing `.godot/global_script_class_cache.cfg`. Scripts
MUST use explicit `preload(...)` script constants instead of bare global `class_name` identifiers for
cross-script type annotations, casts, and `is` checks. Functions that inspect node validity across
deletion boundaries (such as `is_live(mob: Variant)`) MUST accept `Variant` parameters to prevent
GDScript call-boundary type errors on synchronously freed (`free()`) or deletion-pending
(`queue_free()`) instances. All `Window`, `Viewport`, `SceneTree`, and `AudioStreamPlayer` operations
MUST be guarded with `is_inside_tree()` and null checks for out-of-tree test execution safety.

**Rationale**: CI runners and headless test harnesses frequently instantiate scenes outside a full
windowed editor session; defensive typing and tree guards eliminate environment-specific crashes.

### V. Bounded Entity Caps & Spatial Clarity
Real-time 2D and 3D arenas MUST enforce strict entity caps, boundary clamps, and visual separation
invariants so on-screen visual feedback accurately reflects underlying simulation state:
- Active plus pending Blue Mobs in Mob Control 3D MUST never exceed `MAX_MOBS = 300`.
- Projectiles duplicated by multiplier gates (`xN`, `+N`) MUST spread into distinct lateral (`X`) and
  staggered depth (`Z`) formation slots (`CLONE_SPACING_X >= 0.52`, exceeding capsule diameter `0.44`)
  and clamp strictly within the playable highway bounds (`X` in `[-4.5, 4.5]`) so clones never
  superimpose into a single visual unit.
- Environmental motion cues (such as scrolling highway lane dashes and roadside pillars) MUST advance
  deterministically during `GameState.PLAYING`, wrap seamlessly within highway Z-bounds, and halt
  immediately during non-playing states (`STAGE_CLEAR`, `VICTORY`, `DEFEAT`).

**Rationale**: Players rely on immediate visual clarity to judge swarm firepower, gate multiplication,
and forward momentum.

## Technical Stack & Engine Constraints

- **Engine & Renderer**: Godot Engine 4.3 (`Forward Plus`), 60 Hz deterministic physics tick rate
  (`physics/common/physics_ticks_per_second = 60`).
- **Boot & Navigation Contract**: `res://scenes/Menu.tscn` is the canonical boot entry point
  (`run/main_scene`), launching `res://scenes/Main.tscn` (Retro Fighter 2D) and
  `res://scenes/mob_control/MobControlMain.tscn` (Mob Control 3D), with `ESC` (`ui_cancel`) returning
  cleanly to the Arcade Hub menu.
- **Audio Architecture**: All audio streams MUST route through `res://default_bus_layout.tres`
  (`Master`, `Music`, `SFX`) with `autoplay = false` on scene nodes and guarded programmatic playback
  initiation.
- **3D Readability Standards**: 3D overhead labels (`Label3D` on gates, bosses, vaults, and pylons)
  MUST use linear mipmap filtering (`BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`) and HUD
  banners MUST be sized for crisp readability at the active viewport scale.

## Development Workflow & Quality Gates

- **Specification & Planning**: All work MUST begin from an explicit specification and implementation
  plan defining Given/When/Then (GWT) acceptance criteria, a component impact table, and INVEST-aligned
  slices (Pattern A standalone tasks target $\le 300$ LOC and $\le 6$ modified files).
- **Test-Driven Compliance**: Both `python -m unittest discover -s tests` and
  `godot --headless -s res://tests/test_runner.gd` MUST pass with 0 failures and 0 script errors prior
  to opening or merging any Pull Request.
- **Changelog & Branch Hygiene**: Every change MUST be developed on a dedicated `feat/[task-summary]`
  branch, documented under `## [Unreleased]` in `CHANGELOG.md` following the Keep a Changelog format,
  and verified against remote GitHub Actions CI checks (`test-python` and `test-godot`).

## Governance

This Constitution is the highest-priority architectural and governance document for the `retro-fighter`
repository and supersedes conflicting ad-hoc practices.

- **Amendment Procedure**: Any amendment to this Constitution MUST be made via `.specify/memory/constitution.md`,
  include an updated Sync Impact Report during review, document the rationale for principle changes,
  and verify compatibility with existing test suites.
- **Versioning Policy**: `CONSTITUTION_VERSION` follows Semantic Versioning (`MAJOR.MINOR.PATCH`):
  - `MAJOR`: Backward-incompatible principle removals or fundamental governance redefinitions.
  - `MINOR`: Addition of a new core principle, section, or materially expanded technical constraint.
  - `PATCH`: Wording clarifications, formatting fixes, or non-semantic refinements.
- **Compliance Review**: Every feature specification (`/speckit-specify`), implementation plan
  (`/speckit-plan`), task list (`/speckit-tasks`), and code implementation (`/speckit-implement`) MUST
  verify compliance with Principles I–V before merge.

**Version**: 1.0.0 | **Ratified**: 2026-10-23 | **Last Amended**: 2026-10-23
