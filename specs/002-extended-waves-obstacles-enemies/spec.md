# Feature Specification: Extended Multi-Wave Stages, Highway Obstacles, Articulated Enemy Silhouettes, and Destruction Lifecycle

**Feature Branch**: `feat/002-extended-waves-obstacles-enemies`

**Created**: 2026-10-23

**Status**: Approved

**Input**: User description: "Phases must be much much much more longer. Add more obtacles and the enemies must have a form, not only be a ball. When a wall or something big is hit and "destroyed", add an animation. After that the enemy, wall, ... must dissapear from the screen."

## Clarifications

### Session 2026-10-23

- Q: How should we structure the phases so they feel much, much longer instead of ending in seconds? → A: Multi-wave highway progression (~2–3 min per stage) where players fight through scrolling waves of walls, obstacles, and enemy squads before the Final Boss appears, combined with rebalanced cannon/bullet power scaling so stages aren't melted in seconds.
- Q: What types of obstacles should appear on the highway during each phase's waves? → A: A mix of three obstacle categories: (1) Destructible HP Walls/Barricades (segmented lane walls with HP numbers that absorb shots), (2) Moving/Sliding Armored Blocks & Pillars (shift left/right across lanes to force steering), and (3) Active Gate Vaults & Hazard Barriers (lock high-tier gates or sap incoming shots on contact).
- Q: Instead of a plain capsule/ball or flat yellow brick, what 3D form should enemies and bosses have? → A: Articulated 3D character/mech silhouettes out of composite meshes: Red enemies as distinct 3D humanoid/robot raiders (head with glowing visor, torso, arms, legs with a marching stride animation), Giant Bosses as multi-part armored Mechs/Fortresses (head/turret, core body, shoulder pauldrons), while keeping player shots as energy spheres/bolts.
- Q: How should the hit feedback, destruction animation, and removal from the screen work when a wall, vault, pylon, enemy, or Giant Boss is destroyed? → A: On every hit: flash & micro-shake. On destruction (HP = 0): immediately disable collision, play a 3D shatter/explosion burst (debris fragments flying outward + rapid collapse/fade over ~0.45s), and completely remove/hide the entity (including the Stage Boss, Walls, Vaults, Pylons, and Enemies) so nothing with 0 HP ever remains on screen.
- Q: How should we balance Cannon/Power upgrades across a longer multi-wave stage? → A: Gate-charge progression + Wave HUD: require a charge threshold of `xN` gate hits (e.g., 35 gate hits per upgrade above initial tiers) to unlock each +1 Bullet Power tier up to a balanced cap (25), initialize Stage 1 automatically on scene load, and display a `STAGE X — WAVE Y/Z` progress indicator in the HUD.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Extended Multi-Wave Stage Progression & Balanced Power Scaling (Priority: P1)

When a player launches Mob Control 3D or advances to a new stage, the stage initializes its full multi-wave campaign structure rather than ending in a few seconds. The player battles through 3 to 5 sequential defense waves of obstacles and enemy raiders while the backline Boss remains fortified. Weapon upgrades scale through a controlled gate-charge threshold and cap so firepower grows steadily across a 2–3+ minute battle instead of snowballing into instant one-shot kills.

**Why this priority**: Without multi-wave pacing, automatic Stage 1 initialization, and controlled power scaling, stages end in under 10 seconds and none of the obstacle or boss mechanics can be meaningfully experienced.

**Independent Test**: Can be independently tested by launching the game mode, verifying that Stage 1 starts at its full configured health with Wave 1/3 active, clearing Wave 1 obstacles to trigger Wave 2, and firing through multiplier gates to confirm that bullet power increments via the gate-charge threshold up to the maximum cap.

**Acceptance Scenarios**:

1. **Given** the player enters the 3D highway mode from the menu, **When** the stage starts, **Then** Stage 1 initializes with its full base health (1,200 HP), Wave 1 of 3 is active on the highway, and the HUD displays the current stage, wave progress, cannon count, and bullet power.
2. **Given** an active stage with frontline wave obstacles present, **When** the player destroys all obstacles in the current wave and more waves remain, **Then** the stage advances to the next wave and spawns a new formation of obstacles and enemy raiders.
3. **Given** the player has unlocked all 5 squad cannons and reached initial bullet power tier 6, **When** additional player shots pass through multiplication gates, **Then** bullet power increases by +1 only after accumulating 35 gate charges and never exceeds the maximum cap of 25.

---

### User Story 2 - Diverse Highway Obstacles: Destructible Walls, Moving Blocks, and Hazards (Priority: P1)

As the player fires down the highway, each wave presents a tactical combination of segmented Destructible Walls with live health counters, horizontally oscillating Moving Armored Blocks that force the player to steer left and right, and spiked Hazard Barriers that penalize shots hitting the wrong lane.

**Why this priority**: Diverse obstacles transform the highway from an empty shooting gallery into an active steering and target-prioritization challenge.

**Independent Test**: Can be independently tested by spawning each of the three obstacle types on the highway, stepping simulation frames, and verifying horizontal lane oscillation for Moving Blocks, damage absorption for Walls, and higher attrition penalty for Hazard Barriers.

**Acceptance Scenarios**:

1. **Given** a wave containing a Destructible Wall, a Moving Armored Block, and a Hazard Barrier positioned between the multiplier gates and the backline Boss, **When** simulation frames advance, **Then** the Moving Armored Block oscillates horizontally within the playable highway bounds (`[-4.5, +4.5]`) while the Wall holds its lane position.
2. **Given** player projectiles traveling down a lane occupied by an active obstacle, **When** a projectile collides with the obstacle, **Then** the projectile inflicts its power as damage to the obstacle's health counter and is consumed before reaching the Boss behind it.
3. **Given** a multi-power projectile colliding with a Hazard Barrier, **When** contact is resolved, **Then** the Hazard Barrier inflicts a 2x attrition penalty on the projectile's power while taking damage until shattered.

---

### User Story 3 - Articulated 3D Enemy Raider & Giant Mech Boss Silhouettes (Priority: P2)

Instead of facing plain red balls/capsules and a flat yellow rectangle, the player faces recognizable 3D enemy forms: Red enemy units march toward the player as articulated 3D humanoid/robot raiders with a head, glowing visor, armored torso, and swinging arms and legs, while Giant Bosses, Pylons, and Obstacles render as multi-part 3D Mechs, energy spires, and reinforced bunkers. Player shots remain crisp glowing energy spheres/bolts.

**Why this priority**: Distinct 3D character and mech silhouettes provide clear visual identity and arcade immersion while keeping player projectiles visually distinct from enemies.

**Independent Test**: Can be independently tested by instantiating a Red enemy unit and a Giant Boss in the scene tree, stepping the simulation, and verifying that their multi-part 3D visual hierarchies exist and animate limb stride during movement.

**Acceptance Scenarios**:

1. **Given** a Red enemy unit spawned on the highway, **When** it is initialized and advances forward during gameplay, **Then** it displays an articulated 3D robot raider form (head, glowing visor, torso, left/right arms, left/right legs) whose limbs swing in a walking stride animation.
2. **Given** a Blue player unit fired from a cannon, **When** it travels down the highway, **Then** it retains its energy sphere/bolt form that scales and tints according to its bullet power.
3. **Given** a Giant Boss, Shield Pylon, or Highway Obstacle in the arena, **When** rendered on screen, **Then** it displays a multi-part 3D silhouette matching its role (Armored Mech with head/visor/pauldrons/cannons for the Boss, Energy Spire for Pylons, and Reinforced Bunker/Hazard geometry for Obstacles).

---

### User Story 4 - Hit Feedback, 3D Shatter/Explosion Animation, and Zero-HP Screen Removal (Priority: P1)

Whenever a wall, moving block, hazard, vault, shield pylon, enemy, or the Giant Boss takes damage, it flashes and recoils to confirm the hit. When its health reaches 0, its collision is immediately disabled, a 3D shatter/explosion burst of flying debris fragments plays over ~0.45 seconds, and the destroyed object completely disappears from the screen so no entity reading `HP: 0` ever remains visible.

**Why this priority**: Directly resolves the visual defect shown in the user's screenshot where the defeated Boss remained sitting on screen at `HP: 0` during `STAGE CLEAR!`, and adds visceral arcade destruction feedback.

**Independent Test**: Can be independently tested by dealing non-lethal damage to an obstacle/boss to verify hit-flash state, then reducing its HP to 0 to verify immediate collision removal, active debris fragment spawning, and complete visual disappearance (`visible == false` or node freed).

**Acceptance Scenarios**:

1. **Given** any obstacle, vault, pylon, or Boss with health greater than 0, **When** it takes non-lethal damage from a player projectile, **Then** it displays a brief visual hit-flash and micro-recoil.
2. **Given** a Wall, Moving Block, Hazard, Vault, or Shield Pylon whose health reaches 0, **When** contact resolution completes, **Then** it immediately stops blocking projectiles, spawns a 3D shatter/explosion burst of flying fragments that decay over ~0.45 seconds, and is removed from the scene.
3. **Given** the Stage Boss (`GiantEnemy`) reaches 0 HP to trigger `STAGE CLEAR!` or `CAMPAIGN VICTORY!`, **When** state evaluation completes, **Then** a multi-burst Boss explosion animation plays and the Boss immediately disappears from the screen (`visible = false`), leaving no `HP: 0` block on the highway; advancing or retrying restores Boss visibility for the next stage.

---

### Edge Cases

- **Simultaneous Overkill Volleys on Obstacles**: When 5 cannons fire high-power volleys that hit a low-HP wall in the same frame, the first lethal hit destroys the wall and disables its collision immediately so remaining projectiles in the volley continue downrange without being wasted on a `0 HP` corpse.
- **Stage Transition During Active Destruction FX**: If the player presses Space/Enter to advance or R to retry while 3D explosion debris fragments are still flying, all active destruction FX nodes are cleanly freed during stage cleanup with zero orphan nodes.
- **Moving Obstacle Boundary Clamping**: Horizontally oscillating Moving Blocks clamp their center position so their outer edges never protrude outside the playable highway corridor (`[-4.5, +4.5]`).
- **Direct Boss Damage in Existing Automated Tests**: Existing automated test scenarios that spawn test projectiles directly at the Boss's Z-coordinate (`giant_enemy.global_position.z`) bypass frontline wave obstacles and damage the Boss directly, preserving 100% backward compatibility with all prior test suites.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST automatically initialize Stage 1 (`init_stage(0)`) when the 3D highway scene loads so that stage health, highway depth, and wave state are active immediately.
- **FR-002**: Each stage MUST be structured into multiple sequential waves (`3` waves in Stage 1, `4` waves in Stages 2–3, `5` waves in Stages 4–5), advancing to the next wave when all active wave obstacles are destroyed.
- **FR-003**: While frontline wave obstacles remain active in the current stage, the backline Boss MUST advance at a fortified crawl speed (`0.18` units/s) before resuming normal assault speed (`1.0` units/s) once all wave obstacles are cleared.
- **FR-004**: The HUD MUST display the current stage and wave progress alongside cannon count and bullet power (`STAGE X/5 (WAVE Y/Z) | CANNONS: C/5 | BULLET POWER: P`).
- **FR-005**: Once all 5 cannons are unlocked and `bullet_power` reaches tier 6, subsequent multiplication gate hits MUST accumulate into a gate-charge counter that increments `bullet_power` by `+1` every `35` gate hits, up to a strict maximum cap of `25`.
- **FR-006**: Each stage wave MUST spawn a combination of destructible highway obstacles in `active_obstacles`, supporting three distinct obstacle modes: stationary segmented Destructible Walls (`WALL`), horizontally oscillating Moving Armored Blocks (`MOVING_BLOCK`), and high-attrition Hazard Barriers (`HAZARD`).
- **FR-007**: Moving Armored Blocks (`MOVING_BLOCK`) MUST oscillate horizontally along the X-axis during `GameState.PLAYING` while staying clamped within the highway bounds `[-4.5, +4.5]`.
- **FR-008**: Active obstacles MUST intercept colliding player projectiles, deducting projectile damage from the obstacle's health (`HP`) and consuming the projectile (`2x` power attrition on `HAZARD` barriers).
- **FR-009**: Red enemy units (`team == "red"`) MUST construct and display a multi-part 3D humanoid/robot raider visual hierarchy (head, glowing visor, torso, left/right arms, left/right legs) and animate a walking limb stride during `GameState.PLAYING`.
- **FR-010**: Blue player units (`team == "blue"`) MUST retain their glowing energy sphere/bolt form that scales and tints with projectile power.
- **FR-011**: Giant Bosses, Shield Pylons, Vaults, and Highway Obstacles MUST construct and display composite 3D visual hierarchies appropriate to their entity mode (Armored Mech with head/visor/pauldrons/cannons for `BASE`, Energy Spire for `PYLON`, and Reinforced Bunker/Hazard models for obstacles).
- **FR-012**: Taking non-lethal damage (`HP > 0`) on any Boss, Pylon, Vault, or Obstacle MUST trigger a brief visual hit-flash and recoil effect.
- **FR-013**: Whenever any Wall, Moving Block, Hazard Barrier, Vault, Shield Pylon, Red Raider, or Giant Boss reaches `HP <= 0`, the system MUST spawn a 3D shatter/explosion animation (`active_destruction_fx`) consisting of flying 3D debris fragments that expand, tumble, and scale down over `~0.45` seconds before self-cleaning.
- **FR-014**: Destroyed Walls, Moving Blocks, Hazard Barriers, Vaults, Shield Pylons, and Red Raiders MUST be immediately removed from active collision arrays and freed from the scene upon reaching `HP <= 0`.
- **FR-015**: When the Giant Boss reaches `HP <= 0`, it MUST immediately set `visible = false` after spawning its destruction animation so no `HP: 0` model remains on screen during `STAGE_CLEAR` or `VICTORY`, and MUST restore `visible = true` when `reset()` is called for the next stage or retry.

### Key Entities

- **Stage Wave Controller (`MobControlMain`)**: Tracks `current_wave`, `total_waves_in_stage`, `active_obstacles`, `active_destruction_fx`, and `gate_power_charge` across the 5-stage campaign.
- **Highway Obstacle / Boss Entity (`GiantEnemy3D`)**: Supports `EntityMode { BASE, PYLON, WALL, MOVING_BLOCK, HAZARD }`, composite 3D Mech/Bunker visual rig, horizontal oscillation parameters (`osc_base_x`, `osc_amp`, `osc_speed`, `osc_phase`), hit-flash timer, and live 3D health bar/label.
- **Articulated Enemy Raider (`MobUnit3D`)**: Supports `team == "red"` composite 3D robot raider rig (`RaiderModel3D` with head, visor, torso, arms, legs) and deterministic stride animation, while preserving `team == "blue"` energy bolt visuals.
- **Destruction FX Burst (`DestructionFX3D` / `active_destruction_fx`)**: Transient 3D visual burst node containing outward-flying debris fragments that animate deterministically and free themselves after `0.45` seconds.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every stage initializes with `3` to `5` sequential obstacle waves and requires clearing frontline waves before the Boss can be finished via normal down-lane fire, sustaining a pacing lower bound of $\ge 180$ seconds per stage.
- **SC-002**: Bullet power progression is bounded to a maximum of `25` (`MAX_BULLET_POWER = 25`), eliminating runaway 3-digit power inflation during continuous firing.
- **SC-003**: 100% of Red enemy units and Giant Boss/Obstacle entities display multi-part 3D visual hierarchies (`>= 4` distinct child mesh parts) rather than a single primitive mesh.
- **SC-004**: 100% of destroyed entities (Walls, Moving Blocks, Hazards, Vaults, Pylons, Enemies, and the Stage Boss) spawn a 3D destruction effect and disappear from the screen (`visible == false` or freed) on the exact frame their HP reaches `0`.
- **SC-005**: 100% of existing automated tests (Scenarios 1–15) and new acceptance tests (Scenario 16) pass with 0 failures and 0 script errors in both Python static contract and Godot headless test suites.

## Assumptions

- Player projectiles (`team == "blue"`) intentionally remain spherical/capsule energy bolts per operator confirmation so they contrast clearly against the articulated 3D robot enemies and armored obstacles.
- Destruction animations run visually via deterministic per-frame stepping (`step(delta)` and `_process(delta)`) without delaying logical state transitions (`STAGE_CLEAR`, `VICTORY`, or gate unlocking), ensuring zero latency for player inputs and deterministic unit tests.
