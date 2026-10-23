# Feature Specification: Endless Survival Phase, Dynamic Scrolling & Respawning Gates, Gate-Crushing Bosses, & Escalating Enemy Waves

**Feature Branch**: `feat/endless-survival-dynamic-gates`

**Created**: 2026-10-23

**Status**: Approved

**Input**: User description: "The enemies must go forward. Now they are a bit static. So the escenario must change to be more dymanic. xN and +N blocks must move and disapear when they reach the bottom of the screen, apeearing more of them. Enemies must come and if they are 'bosses' they must to 'destroy' the xN and +N blocks as well. Add more. I want enemies to come in a random way. Appearing more a more 'soldiers' with the time. Similar for the bosses. Let's have just one phase for now. The purpose of the phase is to stay there the more time possible."

## Clarifications

### Session 2026-10-23

- Q: How should the single phase progression and win/lose condition work? → A: Make it a single endless Survival Phase: killing a Boss does NOT pause or end the stage; the battle continues non-stop with a live Survival Timer on the HUD until an enemy or Boss breaches the cannon line.
- Q: How should the xN and +N blocks move, respawn, and interact with advancing Bosses? → A: Gates spawn at random X lanes in the mid/upper highway and scroll down (+Z) toward the bottom (with some also sliding side-to-side), disappearing past the cannons; Bosses march forward faster than the gates' drift so Bosses catch up to and shatter (with 3D debris FX) any xN/+N gate in their path.
- Q: How should Soldiers, Bosses, and the former static obstacles work in this new dynamic survival mode? → A: Remove static roadblocks/shield-locks during survival gameplay; all enemies actively march forward (+Z). Soldiers spawn in random lanes with escalating squad sizes/frequency, and Bosses are lane-sized 3D Mechs (allowing 1 at first, then multiple simultaneous Bosses in random lanes as time goes on) that march forward and crush gates.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Single Endless Survival Phase & Continuous Combat Loop (Priority: P1)

Players enter a single continuous Survival Phase where the goal is to stay alive for as long as possible. Unlike a fixed campaign stage that pauses when a boss dies, defeating an advancing Boss in Survival Mode rewards the player with a 3D explosion and increments the Bosses Defeated counter without interrupting the action. The HUD continuously tracks elapsed Survival Time (`TIME: MM:SS.d`), Bosses Defeated, active Cannons, and Bullet Power. The run ends only when an advancing Soldier or Boss breaches the player's cannon line (`Z >= 9.0`), showing the final Survival Time and allowing an immediate retry.

**Why this priority**: This establishes the core game loop ("just one phase for now; the purpose of the phase is to stay there the more time possible") and eliminates static stage-clear interruptions.

**Independent Test**: Can be tested independently by starting the default Survival Phase, verifying no static obstacles exist, defeating an advancing Boss to confirm combat continues in `PLAYING` state while incrementing `bosses_defeated` and `time_elapsed`, and letting an enemy reach `Z >= 9.0` to verify `DEFEAT` displays the survival time and resets cleanly on retry.

**Acceptance Scenarios**:

1. **Given** a newly started Mob Control 3D session in Survival Mode, **When** gameplay progresses and an active Boss's health reaches 0, **Then** the Boss explodes into 3D debris and disappears from the screen, `bosses_defeated` increments by 1, and the game remains in `PLAYING` state without showing a stage-clear pause screen.
2. **Given** an active Survival Phase with elapsed time greater than 0, **When** any enemy Soldier or Boss reaches the player's defense line (`Z >= 9.0`), **Then** the game transitions to `DEFEAT`, displays the elapsed survival time and bosses defeated on the defeat banner, and resets `time_elapsed`, `bosses_defeated`, cannons, and gates upon pressing retry (`R`, `SPACE`, or `ENTER`).

---

### User Story 2 - Dynamic Moving, Despawning, & Respawning `xN` and `+N` Modifier Gates (Priority: P1)

Instead of remaining frozen in fixed positions, all `xN` and `+N` multiplier gates continuously move forward down the highway toward the bottom of the screen (with a portion also sliding horizontally across lanes). When a gate reaches the bottom of the screen (`Z >= 8.2`), it disappears from the scene. New `xN` and `+N` gates with randomized operations and values continuously spawn in the upper highway at random horizontal lanes so the player always has a dynamic, changing set of modifier blocks to aim through.

**Why this priority**: Moving and respawning multiplier gates transform the highway from a static shooting gallery into a dynamic, continuously shifting tactical arena.

**Independent Test**: Can be tested independently by stepping the simulation and verifying that all gates advance forward (`+Z`), gates reaching `Z >= 8.2` are removed from the scene, and new randomized `+N` and `xN` gates spawn in the upper highway over time.

**Acceptance Scenarios**:

1. **Given** active `xN` and `+N` modifier gates on the highway during `PLAYING` state, **When** the simulation steps forward in time, **Then** every active gate advances toward the bottom of the screen (`+Z`) and oscillating gates also shift horizontally within highway bounds `[-3.2, 3.2]`.
2. **Given** a moving `xN` or `+N` gate approaching the bottom of the screen, **When** its position reaches or exceeds `Z = 8.2`, **Then** the gate immediately disappears and is removed from the scene.
3. **Given** the gate spawn timer advancing during `PLAYING` state, **When** the spawn interval elapses (or active gates drop below the minimum floor), **Then** a new `+N` or `xN` gate spawns in the upper highway (`Z <= -14.0`) at a randomized lane position (`X` in `[-2.8, 2.8]`).

---

### User Story 3 - Advancing Lane-Sized Bosses That Destroy `xN` and `+N` Gates (Priority: P1)

Bosses are active, lane-sized 3D Armored Mechs that spawn in the upper highway and march steadily forward (`+Z`) toward the player's cannons faster than the drifting modifier gates. Whenever an advancing Boss touches or overlaps an `xN` or `+N` gate block, the Boss shatters and destroys that gate—spawning a 3D shatter explosion effect and removing the gate from the highway—while continuing its march toward the player.

**Why this priority**: Gate-crushing Bosses create urgent tactical stakes: if the player does not focus fire on an advancing Boss, the Boss will destroy the player's multiplier gates before reaching the cannons.

**Independent Test**: Can be tested independently by placing an advancing Boss behind or overlapping a `MultiplierGate3D`, stepping the simulation, and verifying that the Boss marches forward faster than the gate, triggers a 3D shatter effect upon contact, removes the gate from the scene, and continues advancing.

**Acceptance Scenarios**:

1. **Given** a Boss spawned in `active_bosses` and a `MultiplierGate3D` ahead of it in the same lane, **When** the simulation steps forward, **Then** the Boss advances along `+Z` at a higher speed than the gate's downward drift.
2. **Given** an advancing Boss whose 3D bounding box overlaps an active `xN` or `+N` gate, **When** contact resolution executes, **Then** the gate is immediately destroyed and removed from the screen, a 3D shatter debris effect spawns at the gate's position, and the Boss continues marching forward undamaged.

---

### User Story 4 - Randomized & Time-Escalating Soldier and Boss Waves (Priority: P2)

Enemy Soldiers (3D Robot Raiders) and Bosses (3D Armored Mechs) spawn at randomized horizontal lanes and randomized intervals. As the player survives longer (`time_elapsed` increases), the threat escalates continuously: Soldier spawn intervals shorten and squad burst sizes grow from single raiders into multi-unit platoons, while Boss spawn intervals shorten, Boss health and march speed scale upward, and the maximum number of simultaneous Bosses on the highway increases.

**Why this priority**: Continuous time-based escalation ensures that the single Survival Phase starts approachable and becomes progressively more intense the longer the player survives.

**Independent Test**: Can be tested independently by comparing spawner parameters and spawned entity counts/HP at early survival time (`t = 2s`) versus later survival time (`t = 90s`), confirming higher soldier burst counts, shorter spawn intervals, higher Boss HP, and support for multiple simultaneous Bosses.

**Acceptance Scenarios**:

1. **Given** the Survival Phase at early elapsed time (`time_elapsed < 10s`) versus extended elapsed time (`time_elapsed >= 60s`), **When** the Soldier spawner triggers, **Then** the spawn interval is shorter and the maximum squad burst size is larger at extended elapsed time, placing Soldiers at randomized `X` coordinates within `[-4.2, 4.2]`.
2. **Given** the Survival Phase at extended elapsed time (`time_elapsed >= 60s`), **When** the Boss spawner triggers, **Then** newly spawned Bosses have higher HP and faster forward speed than initial Bosses, and multiple Bosses (`>= 2`) can march down the highway simultaneously.

---

### Edge Cases

- **Boss Crushes Gate on Same Tick Blue Bullet Enters Gate**: Gate contact resolution for Blue Bullets executes before Boss-vs-Gate destruction in Phase 2, or once destroyed by a Boss the gate is immediately marked inactive/queued for deletion so no subsequent bullets duplicate on a destroyed gate.
- **Minimum Gate Floor When Bosses Crush All Gates**: If advancing Bosses destroy all gates on the highway, the gate spawner automatically replenishes a new gate in the upper highway within a short recovery interval so the player is never permanently starved of multipliers.
- **Global Mob Cap (`MAX_MOBS = 300`) & Power Cap (`MAX_BULLET_POWER = 25`)**: Even during late-game survival with rapid gate respawning, active plus pending Blue Mobs never exceed `300` and `bullet_power` never exceeds `25`.
- **Backward Compatibility with Legacy Stage Tests**: Existing automated test scenarios (`Scenarios 1–16`) that explicitly invoke `init_stage(stage_idx)` continue to function deterministically without regression.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The game MUST launch by default into a single continuous Endless Survival Phase (`survival_mode = true`) where the objective is to survive as long as possible without any enemy breaching `Z >= 9.0`.
- **FR-002**: During the Survival Phase, defeating an advancing Boss MUST spawn a 3D explosion effect, remove the Boss from the screen, increment `bosses_defeated`, and keep the game state in `GameState.PLAYING` without pausing or showing a stage-clear screen.
- **FR-003**: The HUD in Survival Mode MUST display the live elapsed survival time (`TIME`), `BOSSES` defeated count, active `CANNONS` count (`X/5`), and `BULLET POWER`.
- **FR-004**: All active `xN` and `+N` modifier gates (`MultiplierGate3D`) MUST move forward (`+Z`) down the highway during `GameState.PLAYING` at a deterministic scroll speed (`scroll_speed > 0`), with a subset of gates also oscillating horizontally (`X` within `[-3.2, 3.2]`).
- **FR-005**: Any `MultiplierGate3D` reaching the bottom of the screen (`global_position.z >= GATE_DESPAWN_Z`, where `GATE_DESPAWN_Z = 8.2`) MUST immediately disappear and be freed from the scene.
- **FR-006**: The highway MUST continuously spawn new randomized `+N` and `xN` gates in the upper highway (`Z <= -14.0`, randomized `X` in `[-2.8, 2.8]`) as `gate_spawn_timer` elapses so that disappearing or destroyed gates are replaced over time.
- **FR-007**: All enemy Soldiers (`MobUnit3D`) and Bosses (`GiantEnemy3D` in `active_bosses`) in Survival Mode MUST actively advance forward (`+Z`) toward the player's cannon line; no stationary road obstacles (`speed == 0`) may block the highway in Survival Mode.
- **FR-008**: Advancing Bosses MUST march forward (`+Z`) at a speed greater than `GATE_SCROLL_SPEED` and MUST destroy any `MultiplierGate3D` whose 3D bounding box they overlap, spawning a 3D shatter effect (`active_destruction_fx`) and removing the gate from the scene.
- **FR-009**: Soldier spawning in Survival Mode MUST randomize lane positions (`X` in `[-4.2, 4.2]`) and escalate with `time_elapsed` by reducing the spawn interval and increasing the maximum squad burst count over time.
- **FR-010**: Boss spawning in Survival Mode MUST randomize lane positions (`X` in `[-2.8, 2.8]`) and escalate with `time_elapsed` by reducing the Boss spawn interval, increasing Boss HP and march speed, and increasing the maximum number of simultaneous active Bosses on the highway.
- **FR-011**: When any Soldier or Boss reaches `Z >= 9.0`, the game MUST transition to `GameState.DEFEAT`, display the player's survival time and bosses defeated on the defeat banner, and reset the entire Survival Phase cleanly upon pressing `R`, `SPACE`, or `ENTER`.
- **FR-012**: Explicit calls to `init_stage(stage_idx)` MUST remain backward-compatible with the 5-stage configuration table (`STAGES`) so all existing automated test scenarios (`Scenarios 1–16`) pass with zero regressions.

### Key Entities

- **Survival Phase Controller (`MobControlMain`)**: Orchestrates the continuous survival timer (`time_elapsed`), dynamic gate stream, `active_bosses` list, escalating Soldier/Boss spawners, Boss-vs-Gate destruction pass, and HUD telemetry.
- **Scrolling Modifier Gate (`MultiplierGate3D`)**: 3D `+N` or `xN` block that moves down `+Z` (and optionally oscillates along `X`), duplicates passing Blue Mobs, despawns at `Z >= 8.2`, and shatters if run over by an advancing Boss.
- **Advancing Mech Boss (`GiantEnemy3D`)**: Lane-sized (`half_width = 1.55`) 3D articulated Mech that spawns in random lanes at the top of the highway, marches forward (`+Z`), crushes modifier gates on contact, flashes on hit, and explodes into 3D debris at `0 HP`.
- **Escalating Robot Soldier (`MobUnit3D`)**: 3D articulated humanoid raider that spawns in increasingly large randomized squads as survival time progresses and marches forward (`+Z`) toward the cannon line.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of active `xN` and `+N` gates in Survival Mode advance along `+Z` every frame during `PLAYING` and are freed within 1 frame of reaching `Z >= 8.2`.
- **SC-002**: 100% of `xN` and `+N` gates overlapped by an advancing Boss are destroyed on the same tick with a spawned 3D shatter animation (`active_destruction_fx.size() > 0`) and removed from the scene.
- **SC-003**: Defeating 1 or more Bosses in Survival Mode increments `bosses_defeated` while maintaining `state == GameState.PLAYING` for 100% of Boss kills (0 stage-clear interruptions).
- **SC-004**: At `time_elapsed >= 60.0s`, the Soldier spawner's maximum burst size is at least `4x` its initial value (`t = 0s`), the Boss spawner supports at least `3` concurrent Bosses, and newly spawned Boss HP is at least `2x` the initial Boss HP.
- **SC-005**: 100% of automated test suites (`python -m unittest discover -s tests` and `godot --headless -s res://tests/test_runner.gd`, including Scenarios 1–17) pass with 0 failures and 0 script errors.

## Assumptions

- The first 1.0 second of a newly instantiated `MobControlMain` scene preserves clear center-lane (`X = 0.0`) projectile travel from `Z = 9.0` to `Z = 0.0` so baseline cannon cadence tests (`Scenario 2`) remain unaffected before enemy waves reach the foreground.
- Existing 3D shatter debris physics (`_spawn_destruction_fx` and `_step_destruction_fx`) are reused for Boss-vs-Gate destruction with distinct gate-colored cyan/blue shards.
