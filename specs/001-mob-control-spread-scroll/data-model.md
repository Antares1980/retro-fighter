# Phase 1 Data Model: Mob Control 3D Visual Gate Duplication Spread, High-Resolution Display, and Forward Highway Motion

**Feature**: `001-mob-control-spread-scroll`  
**Date**: 2026-10-23

## 1. Formation Spread Parameters (`MobControlMain.gd`)

| Constant / Field | Type | Value | Description |
|---|---|---|---|
| `CLONE_SPACING_X` | `float` | `0.55` | Horizontal center-to-center spacing between adjacent units in a gate duplication row (exceeds `0.44` capsule diameter). |
| `CLONE_SPACING_Z` | `float` | `0.50` | Depth (`Z`) offset between staggered rows when total group size $M > 5$. |
| `MAX_ROW_WIDTH` | `int` | `5` | Maximum number of units placed side-by-side in a single horizontal row before wrapping to the next depth row. |
| `HIGHWAY_HALF_WIDTH` | `float` | `4.5` | Playable lateral boundary clamp (`X` in `[-4.5, +4.5]`). |

### Formation Slot Calculation Rules
- Total group size: $M = 1 + \text{allowed}$, where slot `idx = 0` is the entering parent Blue Mob and slots `idx = 1..allowed` are the newly queued clones.
- For each unit index $\text{idx} \in [0, M - 1]$:
  - $\text{row\_idx} = \lfloor \text{idx} / \text{MAX\_ROW\_WIDTH} \rfloor$
  - $\text{col\_idx} = \text{idx} \bmod \text{MAX\_ROW\_WIDTH}$
  - $\text{units\_in\_row} = \min(\text{MAX\_ROW\_WIDTH}, M - \text{row\_idx} \times \text{MAX\_ROW\_WIDTH})$
  - $\text{half\_span} = \frac{(\text{units\_in\_row} - 1) \times \text{CLONE\_SPACING\_X}}{2.0}$
  - $\text{row\_center\_x} = \text{clampf}(\text{anchor\_x}, -4.5 + \text{half\_span}, 4.5 - \text{half\_span})$
  - $\text{slot\_x} = \text{clampf}\left(\text{row\_center\_x} + \left(\text{col\_idx} - \frac{\text{units\_in\_row} - 1}{2.0}\right) \times \text{CLONE\_SPACING\_X}, -4.5, 4.5\right)$
  - $\text{slot\_z} = \text{gate.global\_position.z} - 0.6 - \text{float}(\text{row\_idx}) \times \text{CLONE\_SPACING\_Z}$
- Parent unit (`idx == 0`) updates `mob.position.x = slot_x` immediately; clones (`idx >= 1`) spawn at `Vector3(slot_x, 0.5, slot_z)`.

---

## 2. Dynamic Viewport Display Profile (`MobControlMain.gd`)

| Constant | Type | Value | Description |
|---|---|---|---|
| `HI_RES_SIZE` | `Vector2i` | `Vector2i(1152, 672)` | High-resolution 3D rendering target size (3x integer multiple of `384x224`). |
| `RETRO_RES_SIZE` | `Vector2i` | `Vector2i(384, 224)` | Baseline CPS-1 2D pixel-art viewport size restored on exit. |

### State Transitions
- **On `MobControlMain._ready()`** $\rightarrow$ `_apply_high_res_viewport()`:
  - `Window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS`
  - `Window.content_scale_size = HI_RES_SIZE` (`Vector2i(1152, 672)`)
  - `Viewport.msaa_3d = Viewport.MSAA_4X`
- **On `MobControlMain.return_to_menu()` or `MobControlMain._exit_tree()`** $\rightarrow$ `_restore_retro_viewport()`:
  - `Window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT`
  - `Window.content_scale_size = RETRO_RES_SIZE` (`Vector2i(384, 224)`)
  - `Viewport.msaa_3d = Viewport.MSAA_DISABLED`

---

## 3. Highway Scroller Entities (`MobControlMain.gd` & `MobControlMain.tscn`)

| Constant / Property | Type | Value | Description |
|---|---|---|---|
| `ROAD_SCROLL_SPEED` | `float` | `8.0` | Forward optical-flow speed (`+Z` units per second) of road stripes and roadside pillars during `GameState.PLAYING`. |
| `ROAD_SCROLL_MIN_Z` | `float` | `-52.0` | Far horizon Z-coordinate bound for scrolling highway markers. |
| `ROAD_SCROLL_MAX_Z` | `float` | `12.0` | Near camera Z-coordinate wrap threshold (`scroll_span = 64.0`). |
| `road_decor` | `Node3D` | `$RoadDecor` | Container node holding all visual road stripe and roadside pillar `MeshInstance3D` nodes. |
| `road_scroller_nodes` | `Array[Node3D]` | `[...]` | Deterministic list of scrolling marker nodes advanced by `_step_road_scroller(delta)`. |

### Marker Geometry
- **Center & Lane Dashed Stripes**: `MeshInstance3D` with `BoxMesh` (`Vector3(0.18, 0.02, 1.6)`) placed along $X \in \{0.0, -5.2, +5.2\}$ at $Y = 0.01$, spaced every `4.0` units along $Z \in [-52.0, +12.0)$.
- **Roadside Marker Pillars**: `MeshInstance3D` with `BoxMesh` (`Vector3(0.35, 1.2, 0.35)`) placed along $X \in \{-6.4, +6.4\}$ at $Y = 0.6$, spaced every `6.0` units along $Z \in [-52.0, +12.0)$.
- **Wrap Rule**: In `_step_road_scroller(delta)`:
  - `marker.position.z += ROAD_SCROLL_SPEED * delta`
  - While `marker.position.z > ROAD_SCROLL_MAX_Z`: `marker.position.z -= (ROAD_SCROLL_MAX_Z - ROAD_SCROLL_MIN_Z)` (`64.0`).
