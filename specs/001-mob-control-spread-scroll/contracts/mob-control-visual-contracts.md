# Phase 1 Interface & Scene Contracts: Mob Control 3D Visuals

**Feature**: `001-mob-control-spread-scroll`  
**Date**: 2026-10-23

## 1. Script Method & Constant Contracts (`scripts/mob_control/MobControlMain.gd`)

```gdscript
const HI_RES_SIZE: Vector2i = Vector2i(1152, 672)
const RETRO_RES_SIZE: Vector2i = Vector2i(384, 224)
const CLONE_SPACING_X: float = 0.55
const CLONE_SPACING_Z: float = 0.50
const MAX_ROW_WIDTH: int = 5
const ROAD_SCROLL_SPEED: float = 8.0
const ROAD_SCROLL_MIN_Z: float = -52.0
const ROAD_SCROLL_MAX_Z: float = 12.0

var road_scroller_nodes: Array[Node3D] = []

func _apply_high_res_viewport() -> void
func _restore_retro_viewport() -> void
func _exit_tree() -> void
func _setup_road_scroller() -> void
func _step_road_scroller(delta: float) -> void
func _compute_gate_formation_slot(idx: int, total_group: int, anchor_x: float, base_z: float) -> Vector3
```

## 2. Scene Node Contracts

### `scenes/mob_control/MobControlMain.tscn`
- Root `MobControlMain` (`Node3D`) contains child `RoadDecor` (`Node3D`) for highway visual markers.
- `UI/VictoryBanner` (`Label`): `font_size = 32`, `outline_size = 6`, offsets `(-360, -70)` to `(360, 70)`.
- `UI/DefeatBanner` (`Label`): `font_size = 32`, `outline_size = 6`, offsets `(-360, -70)` to `(360, 70)`.
- `UI/ControlsHint` (`Label`): `font_size = 22`, `outline_size = 4`, offsets `(-480, -42)` to `(480, -10)`, preserving exact text `"A/D or ARROWS: STEER | HOLD J or SPACE: FIRE | ESC: MENU"`.

### `scenes/mob_control/MultiplierGate3D.tscn` & `scenes/mob_control/GiantEnemy3D.tscn`
- `Label3D` node configured with `texture_filter = 5` (`BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`) for crisp anti-aliased 3D text rendering at `1152x672`.
