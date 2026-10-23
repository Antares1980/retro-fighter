# Retro Fighter & Arcade Hub Constitution

## Core Principles

### I. Deterministic Step-Driven Simulation
All gameplay loops across 2D (`Main.gd`, `Fighter.gd`, `AIController.gd`) and 3D (`MobControlMain.gd`,
`Cannon3D.gd`, `MultiplierGate3D.gd`, `GiantEnemy3D.gd`) MUST expose deterministic, frame-decoupled
stepping methods (`step(delta)` or integer tick counters at 60 Hz). Combat resolution, always-on cannon
auto-fire cadence, multiplier gate cloning and forward scrolling, lateral formation spreading,
time-escalating enemy/boss spawners, shield lock state machines, destruction debris physics, and
environmental highway scrolling MUST execute reproducibly in headless automated tests without relying on
wall-clock timers or asynchronous physics race conditions.

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
   hierarchies, `.gd` script signatures and constants, mathematical invariants, `project.godot`
   settings, and CI/CD workflow & prompt contracts (`tests/test_claude_workflows.py`).
2. **Godot 4.3 Headless Runtime Suite** (`godot --headless -s res://tests/test_runner.gd`): Validates
   in-engine runtime behavior and Given/When/Then (GWT) acceptance criteria across all registered test
   suites.

**Rationale**: Static contract tests catch scene, script, and CI workflow wiring drift in milliseconds,
while headless Godot execution guarantees real engine runtime compliance without manual GUI intervention.

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

### V. Bounded Entity Caps, Power Scaling, & Spatial Clarity
Real-time 2D and 3D arenas MUST enforce strict entity caps, power-scaling thresholds, boundary clamps,
and visual separation invariants so gameplay pacing and on-screen feedback remain balanced:
- Active plus pending Blue Mobs in Mob Control 3D MUST never exceed `MAX_MOBS = 300`. In Survival Mode,
  blue projectiles that pass the upper-highway enemy spawn zone (`Z < SURVIVAL_CLEANUP_BOUND_Z = -24.5`)
  MUST despawn immediately, and whenever a cannon volley at the muzzle would exceed `MAX_MOBS = 300`, the
  controller MUST recycle the furthest-downrange live blue bullet (`_recycle_furthest_blue_mob()`) so
  cannon muzzle firing is never blocked or paused.
- Squad cannon count MUST be bounded (`MAX_CANNONS = 5`) and `bullet_power` progression MUST enforce
  paced gate-charge thresholds in Survival Mode (`CANNON_UNLOCK_CHARGE_THRESHOLD = 12` per additional
  cannon, `GATE_POWER_EARLY_THRESHOLD = 10` for tiers `1..6`, and `GATE_CHARGE_THRESHOLD = 35` for tiers
  `6..25`) up to `MAX_BULLET_POWER = 25` so gameplay sustains tactical progression.
- Projectiles duplicated by multiplier gates (`xN`, `+N`) MUST spread into distinct lateral (`X`) and
  staggered depth (`Z`) formation slots (`CLONE_SPACING_X >= 0.52`, exceeding capsule diameter `0.44`)
  and clamp strictly within the playable highway bounds (`X` in `[-4.5, 4.5]`) so clones never
  superimpose into a single visual unit.
- Environmental motion cues (such as scrolling highway lane dashes and roadside pillars) MUST advance
  deterministically during `GameState.PLAYING`, wrap seamlessly within highway Z-bounds, and halt
  immediately during non-playing states (`STAGE_CLEAR`, `VICTORY`, `DEFEAT`).

**Rationale**: Players rely on uninterrupted cannon feedback, controlled power curves, and immediate
spatial clarity to experience meaningful tactical progression and judge swarm firepower.

### VI. Articulated 3D Visuals & Zero-HP Destruction Lifecycle
3D enemy units, bosses, gates, and destructible highway structures MUST present distinct, readable
silhouettes and a complete visual lifecycle from impact to removal:
- Enemy units (`MobUnit3D` red raiders) and bosses/fortifications (`GiantEnemy3D` mechs, pylons, vaults,
  and obstacle walls) MUST construct composite, articulated 3D visual hierarchies (such as head, glowing
  visor, torso, limbs, or turret pauldrons) rather than bare single-primitive spheres or boxes.
- Taking non-lethal damage MUST provide immediate visual hit feedback (emissive flash or micro-recoil).
- Reaching `HP <= 0`—or when an advancing Boss crushes an `xN` / `+N` gate (`MultiplierGate3D`)—MUST
  immediately disable collision, spawn a deterministic 3D shatter or explosion animation, and completely
  remove (`queue_free()`) or hide (`visible = false`) the destroyed entity so no destroyed gate or `HP: 0`
  entity ever remains lingering on screen.

**Rationale**: Arcade combat feel depends on recognizable enemy forms, visceral hit confirmation, and
unambiguous visual removal when a gate, obstacle, enemy, or boss is destroyed.

### VII. Dynamic Highway Motion, Auto-Fire Cannons, & Endless Survival Escalation
Primary gameplay in Mob Control 3D MUST operate as a dynamic, continuous **Single Endless Survival Phase**
where cannons shoot automatically at all times and the battlefield escalates relentlessly:
- Player cannons (`Cannon3D`) MUST fire automatically and continuously at `FIRE_INTERVAL = 0.14s`
  (`auto_fire = true` by default) during `GameState.PLAYING` without requiring manual `SPACE` or `J`
  input; the HUD controls hint (`UI/ControlsHint`) MUST reflect steering and menu controls only
  (`"A/D or ARROWS: STEER | ESC: MENU"`).
- Multiplier gates (`xN` and `+N` `MultiplierGate3D` blocks) MUST actively advance forward (`+Z`) down the
  highway (with optional horizontal lane oscillation), disappear (`queue_free()`) upon reaching the
  bottom of the screen (`Z >= 8.2`), and continuously respawn with randomized modifiers in the upper highway.
- All enemy Soldiers (`MobUnit3D`) and lane-sized Mech Bosses (`GiantEnemy3D`) MUST actively march
  forward (`+Z`) from randomized horizontal lanes; advancing Bosses MUST move faster than drifting gates
  and MUST shatter and destroy any `xN` or `+N` gate they overlap.
- Spawning of Soldiers and Bosses MUST escalate aggressively over survival time (`time_elapsed`),
  shrinking spawn intervals and scaling both minimum and maximum Soldier squad burst sizes
  (`get_soldier_min_burst`, `get_soldier_max_burst`), Soldier durability (`get_scaled_soldier_power`),
  accelerating Boss HP (`get_scaled_boss_hp`), and concurrent Boss counts (`get_max_concurrent_bosses` up
  to `5`) while keeping combat uninterrupted when Bosses are killed (`state` remains `GameState.PLAYING`
  until an enemy breaches `Z >= 9.0`). Legacy stage methods (`init_stage`, `STAGES`) MUST remain
  backward-compatible so all historical regression tests pass.

**Rationale**: Automatic continuous cannon fire eliminates input fatigue and firing stalls, while
aggressive time-based scaling of enemy numbers and durability ensures survival gameplay grows genuinely
more challenging as time passes.

### VIII. Automated Claude GitHub App Governance & Exact-SHA CI Gating
Repository collaboration and Pull Request lifecycle automation MUST be governed by resilient,
non-self-cancelling Claude Opus 5.5 High (`--model claude-opus-5-5 --effort high`) GitHub Actions
workflows:
- **Interactive `@claude` Mentions (`.github/workflows/claude.yml`)**: Mentions of `@claude` across
  `issue_comment`, `pull_request_review_comment`, `pull_request_review`, and `issues` (`opened`,
  `assigned`) MUST trigger `anthropics/claude-code-action@v1` with `CLAUDE_CODE_OAUTH_TOKEN` and
  explicit `contents: write`, `pull-requests: write`, `issues: write`, `id-token: write`, and
  `actions: read` permissions.
- **Automated PR Review, In-Place Auto-Fix, & Squash-Merge (`.github/workflows/pr-review.yml` &
  `.github/workflows/prompts/pr-review.md`)**:
  - Concurrency MUST be scoped per PR (`pr-review-${{ github.event.pull_request.number || inputs.pr_number }}`)
    with `cancel-in-progress: false` so `synchronize` events from `[skip pr-review]` auto-fix commits
    never cancel an active review/merge run.
  - Pre-flight metadata checks (`steps.meta`) MUST enforce a 3-round review cap (`ROUND_CAP: 3`,
    escalating via `status:needs-po-input`) and provide a zero-LLM-token `merge_only=true` fast-path
    whenever the `HEAD` commit contains `[skip pr-review]` and the latest `<!-- pr-review-verdict -->`
    comment is `APPROVED`.
  - The review runner MUST remain lightweight (without downloading or installing the Godot binary inside
    `pr-review.yml`), executing `python3 -m unittest discover -s tests` in-place during review while
    delegating full Godot headless verification to the `CI` workflow.
  - All pipeline labels (`review:approved`, `review:changes-requested`, `needs-refactor`,
    `status:needs-po-input`, `status:ready`, `status:done`, `dev-implemented`, `tech-debt`) MUST be
    idempotently provisioned via `gh label create <name> -R "$REPO" --force` before application so
    missing labels never crash workflow execution.
  - Auto-merging (`gh pr merge --squash --delete-branch`) MUST be gated on polling the `CI` workflow
    (`CI_WORKFLOW_NAME: "CI"`) strictly matching `--commit "$CURRENT_SHA"` (`CI_PASSED="true"`),
    transitioning to `review:changes-requested` and `needs-refactor` if CI fails or times out, and
    closing the parent story (`status:done`, `dev-implemented`) when all sibling subtasks are closed.

**Rationale**: Preventing concurrency self-cancellation, provisioning labels idempotently, and gating
squash-merges on the exact target commit SHA eliminate stranded Pull Requests and race conditions.

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
- **3D Readability Standards**: 3D overhead labels (`Label3D` on gates, bosses, vaults, pylons, and
  destructible walls) MUST use linear mipmap filtering
  (`BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`) and HUD banners MUST be sized for crisp
  readability at the active viewport scale.

## Development Workflow & Quality Gates

- **Specification & Planning**: All work MUST begin from an explicit specification and implementation
  plan defining Given/When/Then (GWT) acceptance criteria, a component impact table, and INVEST-aligned
  slices (Pattern A standalone tasks target $\le 350$ LOC and $\le 6$ modified files).
- **Test-Driven Compliance**: Both `python -m unittest discover -s tests` and
  `godot --headless -s res://tests/test_runner.gd` MUST pass with 0 failures and 0 script errors prior
  to opening or merging any Pull Request.
- **Changelog & Branch Hygiene**: Every change MUST be developed on a dedicated `feat/[task-summary]`
  branch, documented under `## [Unreleased]` in `CHANGELOG.md` following the Keep a Changelog format,
  and verified against remote GitHub Actions CI checks (`test-python` and `test-godot`) and automated
  Claude PR review (`pr-review.yml`).

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
  verify compliance with Principles I–VIII before merge.

**Version**: 1.4.0 | **Ratified**: 2026-10-23 | **Last Amended**: 2026-10-23
