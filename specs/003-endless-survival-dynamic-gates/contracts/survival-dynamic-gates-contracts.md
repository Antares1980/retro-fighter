# Contracts: Endless Survival Phase, Dynamic Scrolling & Respawning Gates, Gate-Crushing Bosses, & Escalating Enemy Waves

## 1. `MobControlMain` Public & Internal Method Contracts (`scripts/mob_control/MobControlMain.gd`)

- `const GATE_SCROLL_SPEED: float = 1.8`
- `const GATE_DESPAWN_Z: float = 8.2`
- `const GATE_SPAWN_Z: float = -16.5`
- `const BOSS_BASE_SPEED: float = 2.6`
- `const BOSS_BASE_HP: int = 140`
- `var survival_mode: bool = true`
- `var dynamic_gates_enabled: bool = true`
- `var bosses_defeated: int = 0`
- `var soldiers_defeated: int = 0`
- `var active_bosses: Array[GiantEnemy3DScript] = []`
- `func init_survival_phase() -> void`: Initializes the Single Endless Survival Phase (`survival_mode = true`, `state = GameState.PLAYING`, `time_elapsed = 0.0`, `bosses_defeated = 0`, `soldiers_defeated = 0`, resets initial moving gates, hides static `giant_enemy`, spawns initial advancing Boss in `active_bosses`).
- `func spawn_random_gate(z_pos: float = GATE_SPAWN_Z) -> MultiplierGate3DScript`: Spawns a new `+N` or `xN` gate at random `X in [-2.8, 2.8]`, `Z = z_pos`, with `move_enabled = true`, `scroll_speed = GATE_SCROLL_SPEED`, and optional horizontal oscillation.
- `func spawn_boss(pos: Vector3 = Vector3.ZERO, hp_val: int = -1, speed_val: float = -1.0) -> GiantEnemy3DScript`: Spawns a lane-sized (`half_width = 1.55`) 3D Mech Boss in `active_bosses` that marches forward along `+Z`.
- `func on_boss_destroy_gate(boss: GiantEnemy3DScript, gate: MultiplierGate3DScript) -> void`: Spawns a 3D shatter effect at `gate.global_position`, locks/disables the gate, and calls `gate.queue_free()`.
- `func _resolve_boss_gate_destruction() -> void`: Checks all live Bosses against all live gates and triggers `on_boss_destroy_gate` on overlap.
- `func _resolve_boss_contacts() -> void`: Resolves Blue Mob collisions against all live Bosses in `active_bosses`, dealing `blue.power` damage and destroying/freeing Bosses when `hp <= 0` without halting `GameState.PLAYING`.
- `func get_soldier_max_burst(elapsed: float) -> int`: Returns the maximum Soldier squad burst size at `elapsed` seconds (`1 + int(floor(elapsed / 15.0))`, capped at `8`).
- `func get_max_concurrent_bosses(elapsed: float) -> int`: Returns the maximum concurrent Bosses allowed at `elapsed` seconds (`1 + int(floor(elapsed / 25.0))`, capped at `5`).
- `func get_scaled_boss_hp(elapsed: float) -> int`: Returns scaled Boss HP at `elapsed` seconds (`BOSS_BASE_HP + int(floor(elapsed * 4.5))`).

## 2. `MultiplierGate3D` Method Contracts (`scripts/mob_control/MultiplierGate3D.gd`)

- `@export var scroll_speed: float = 1.8`
- `@export var move_enabled: bool = true`
- `var osc_enabled: bool = false`
- `func step_gate(delta: float) -> void`: Advances `position.z += scroll_speed * delta` when `move_enabled` is true, and oscillates `position.x` within `[-3.2, 3.2]` when `osc_enabled` is true.

## 3. HUD & Defeat Banner Contracts

- `CannonStatusLabel.text`: Preserves `"CANNONS: %d/%d | BULLET POWER: %d"` exact format for `Scenario 15` compatibility.
- `WaveStatusLabel.text`:
  - When `survival_mode == true`: Displays `"SURVIVAL TIME: %02d:%04.1f | BOSSES: %d | KILLS: %d"`.
  - When `survival_mode == false` (legacy stage mode): Displays `"STAGE %d/%d | WAVE %d/%d"`.
- `DefeatBanner.text` in Survival Mode: Contains `"DEFEAT!"` and survival telemetry (`"SURVIVED:"` / `"PRESS R TO RESTART OR ESC FOR MENU"`).
