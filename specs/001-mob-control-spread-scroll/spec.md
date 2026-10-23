# Feature Specification: Mob Control 3D Visual Gate Duplication Spread, High-Resolution Display, and Forward Highway Motion

**Feature Branch**: `001-mob-control-spread-scroll`

**Created**: 2026-10-23

**Status**: Draft

**Input**: User description: "When the bullet is passing the x2 wall, must be duplicated. The logic is this help having more power. I want as well more resolution and the game must give the impression we are moving forward." (Refined via `docs/draft-requisites/implementation-plan.md`)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Visible Side-by-Side Projectile Multiplication at Gates (Priority: P1)

When a player fires projectiles through multiplier gates (such as `x2`, `+2`, `x3`, or `+5`), the resulting projectiles must visibly split and spread side-by-side across the highway lane rather than stacking on top of one another at the exact same spot. This allows the player to immediately see their firepower multiply into a wider, more powerful swarm front.

**Why this priority**: Core gameplay feedback in a multiplier-gate arcade game depends on seeing a single projectile turn into multiple distinct projectiles when passing through a gate; superimposed projectiles look like a bug where the gate failed to duplicate the bullet.

**Independent Test**: Fire a single player unit through a `x2` gate and a `+2` gate and verify that the resulting units appear side-by-side with clear horizontal separation while remaining inside the playable road boundaries.

**Acceptance Scenarios**:

1. **Given** an active match with a single player projectile approaching a `x2` gate, **When** the projectile passes through the gate, **Then** 2 total projectiles emerge side-by-side with a horizontal separation of at least 0.45 highway units so both are visually distinct.
2. **Given** an active match with a single player projectile approaching a `+2` gate, **When** the projectile passes through the gate, **Then** 3 total projectiles emerge in a spread formation where no two projectiles occupy the same horizontal and depth coordinates.
3. **Given** a projectile passing through a high-yield gate (such as `+5`) near the far left or far right edge of the highway, **When** the duplicated group spawns, **Then** all 6 resulting projectiles are arranged in a spread formation (using staggered rows when wider than 5 units) strictly inside the playable highway boundaries (`-4.5` to `+4.5`) without overlapping.

---

### User Story 2 - Crisp High-Resolution 3D Visuals with Clean Retro Menu Restoration (Priority: P2)

When launching the 3D highway game from the Arcade Hub, the display must automatically switch from the low-resolution retro pixel-art display (`384x224`) to a sharp, high-definition 3D display (`1152x672` with smoothed 3D edges and crisp overhead gate/enemy labels). When returning to the Arcade Hub or switching back to the 2D retro fighting game, the display must seamlessly restore the original retro pixel-art resolution without side effects.

**Why this priority**: Rendering a 3D perspective arena at `384x224` causes severe blockiness and makes distant gate numbers (`x2`, `+2`), boss health counters, and projectiles difficult to read.

**Independent Test**: Launch Mob Control 3D and verify the display resolution scales to `1152x672` with anti-aliased 3D edges and readable banners; exit back to the Arcade Hub menu and verify the `384x224` retro pixel-art mode is completely restored.

**Acceptance Scenarios**:

1. **Given** the application starts in the default `384x224` retro display mode, **When** the player enters Mob Control 3D, **Then** the display switches to `1152x672` high-resolution mode with 4x 3D edge smoothing and clearly scaled on-screen HUD banners and 3D gate/boss labels.
2. **Given** the player is in Mob Control 3D at `1152x672` resolution, **When** the player exits to the Arcade Hub menu or closes the 3D scene, **Then** the display immediately restores the `384x224` retro display mode with edge smoothing disabled so the 2D fighting game and menu behave identically to before.

---

### User Story 3 - Continuous Forward Highway Motion Illusion (Priority: P3)

While an active stage is being played, the highway surface and roadside environment must continuously scroll toward the camera to create a clear visual sensation that the player's cannon and squad are advancing forward down the road, pausing immediately when a stage ends.

**Why this priority**: A featureless static gray road makes the player's cannon feel stationary; scrolling lane markings and roadside posts provide immediate forward momentum and arcade pacing without altering combat distances.

**Independent Test**: Observe road lane dashes and roadside marker posts during active gameplay and verify they move steadily toward the camera, wrap seamlessly from the front of the screen back to the far horizon, and stop moving when the stage is cleared, won, or lost.

**Acceptance Scenarios**:

1. **Given** a stage in the active playing state, **When** simulation time advances, **Then** center/edge lane dashes and roadside marker pillars move steadily toward the camera at a constant forward scroll speed (`8.0` units per second).
2. **Given** scrolling road markers moving toward the camera, **When** any marker passes behind the camera boundary (`+12.0`), **Then** it wraps seamlessly back to the far horizon (`-52.0`) to maintain an unbroken endless highway appearance.
3. **Given** a stage transitions to Stage Clear, Campaign Victory, or Defeat, **When** simulation steps occur in that non-playing state, **Then** all highway lane dashes and roadside pillars remain stationary until gameplay resumes.

---

### Edge Cases

- **Gate passage right against the highway wall (`X = ±4.4`)**: The formation spread shifts its horizontal center inward before placing individual units so that every unit stays within `[-4.5, +4.5]` while still maintaining side-by-side separation.
- **Large multiplier yields (`+5` or higher)**: Groups exceeding 5 units in a single multiplication wrap excess units into a staggered depth row (`0.50` units behind the front row) rather than compressing horizontal spacing or exceeding highway width.
- **Global unit cap (`300` max units) reached during gate passage**: Only the allowed remaining number of clones up to the 300-unit ceiling are spawned and spread into formation.
- **Rapid scene transitions between 3D and 2D games**: Restoring the retro display contract is triggered both on explicit menu return and on scene exit so no transition path leaves the 2D game in high-resolution mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Multiplier gates (`xN` and `+N`) MUST preserve their mathematical duplication rules (`xN` produces `N - 1` clones for `N` total units; `+N` produces `N` clones for `N + 1` total units) while assigning the passing parent projectile and all spawned clones to distinct formation coordinates.
- **FR-002**: Duplicated projectile groups MUST be spaced horizontally by at least `0.52` units (specifically `0.55` units center-to-center, exceeding the `0.44` unit projectile diameter) and up to `5` units per row, with additional units placed in staggered depth rows separated by `0.50` units.
- **FR-003**: Every projectile repositioned or spawned by a multiplier gate MUST have its horizontal position clamped strictly within the playable highway corridor (`[-4.5, +4.5]`) by clamping the row center prior to slot assignment so units near the road edges do not collapse onto a single coordinate.
- **FR-004**: Entering the 3D highway game MUST dynamically configure the display to `1152x672` resolution with smooth canvas scaling and 4x 3D multi-sample anti-aliasing, and exiting or returning to the main menu MUST restore the `384x224` retro pixel-art display configuration with 3D anti-aliasing disabled.
- **FR-005**: On-screen UI banners (`VictoryBanner`, `DefeatBanner`, `ControlsHint`) and 3D overhead counters (multiplier gates, bosses, vaults, and pylons) MUST scale and filter cleanly for sharp legibility at `1152x672` resolution.
- **FR-006**: The 3D highway arena MUST display repeating visual reference markers—including center/lane dashed stripes and roadside marker pillars outside the playable corridor—that scroll toward the camera (`+Z`) at `8.0` units per second during active gameplay, wrap seamlessly across the `-52.0` to `+12.0` span, and halt immediately when gameplay is not in the active playing state.

### Key Entities *(include if feature involves data)*

- **Projectile Formation Group**: The combined set of 1 parent projectile and `allowed` cloned projectiles emerging from a single gate passage, assigned to non-overlapping `(X, Z)` formation slots within `[-4.5, +4.5]`.
- **Viewport Display Profile**: The active window scaling state switching between the **Retro Profile** (`384x224`, viewport stretch, no 3D anti-aliasing) and the **High-Resolution 3D Profile** (`1152x672`, canvas-items stretch, 4x 3D anti-aliasing).
- **Highway Scroller Marker**: Visual-only road stripes and roadside posts that translate along `+Z` during active play and wrap modularly across the highway depth span without affecting combat collision coordinates.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of projectiles passing through an active `x2` gate (below the 300-unit cap) result in 2 side-by-side projectiles separated horizontally by at least `0.45` units and contained within `[-4.5, +4.5]`.
- **SC-002**: 100% of projectiles passing through `+2`, `x3`, or `+5` gates (including at highway boundaries `X = ±4.4`) produce non-overlapping projectile coordinates with zero pairs sharing the same `(X, Z)` position and 100% containment within `[-4.5, +4.5]`.
- **SC-003**: Entering Mob Control 3D increases rendered viewport resolution 9-fold in pixel area (from `384x224` to `1152x672`, a 3x horizontal and 3x vertical increase) and restores `384x224` with 0 regressions across all existing 2D Retro Fighter and Menu automated tests.
- **SC-004**: Highway visual markers advance at exactly `8.0` units/second during active play, wrap seamlessly within `[-52.0, +12.0]`, and exhibit `0.0` displacement per tick when the game state is Stage Clear, Victory, or Defeat.

## Assumptions

- The cannon, multiplier gates, vaults, pylons, and enemy bases retain their established arena coordinates so stage pacing and combat timing invariants remain unchanged while the highway markings scroll beneath them.
- The 300-unit global cap (`MAX_MOBS = 300`) remains the upper bound for simultaneous active and pending player projectiles.
