class_name MultiplierGate3D
extends Area3D

## Math modifier gate for Mob Control 3D.
## Replicates passing Blue mobs based on addition (+) or multiplication (x).
## Supports Destructible Vaults (blockading high-yield gates) and Two-Way Evolution Gates.

enum GateMode { NORMAL, EVOLUTION, VAULT }

const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 15
const PROGRESS_PER_LEVEL: int = 30
const MIN_EVOLUTION_LEVEL: int = MIN_LEVEL
const MAX_EVOLUTION_LEVEL: int = MAX_LEVEL

@export var gate_id: String = ""
@export var operation: String = "+"
@export var value: int = 2
@export var gate_mode: GateMode = GateMode.NORMAL

# Vault blockade support
@export var is_locked: bool = false
@export var hp: int = 0
@export var max_hp: int = 0
var target_gate: Node3D = null
var blockaded_gate: Node3D:
	get:
		return target_gate
	set(val):
		target_gate = val
var blockading_vault: Node3D = null
var vault: Node3D:
	get:
		return blockading_vault
	set(val):
		blockading_vault = val

# Evolution Gate support
@export var is_evolution_gate: bool = false
@export var level: int = 1:
	set(val):
		level = clampi(val, MIN_LEVEL, MAX_LEVEL)
		value = level
@export var progress: int = 0

var evolution_level: int:
	get:
		return level
	set(val):
		level = val

var evolution_progress: int:
	get:
		return progress
	set(val):
		progress = val
		_recalculate_evolution()

@onready var label: Label3D = $Label3D if has_node("Label3D") else null

func _ready() -> void:
	collision_layer = 8
	collision_mask = 6
	if gate_id == "":
		gate_id = name if name != "" else str(get_instance_id())
	if gate_mode == GateMode.EVOLUTION or is_evolution_gate:
		is_evolution_gate = true
		gate_mode = GateMode.EVOLUTION
		operation = "+"
		value = level
		add_to_group("evolution_gates")
	elif gate_mode == GateMode.VAULT or is_in_group("vaults"):
		gate_mode = GateMode.VAULT
		add_to_group("vaults")
	update_label()

func is_evolution() -> bool:
	return is_evolution_gate or gate_mode == GateMode.EVOLUTION

func is_vault() -> bool:
	return gate_mode == GateMode.VAULT or is_in_group("vaults")

func update_label() -> void:
	if label == null:
		label = get_node_or_null("Label3D")
	if label != null:
		if is_vault():
			label.text = "VAULT: %d" % hp
		elif is_locked:
			label.text = "LOCKED (%s%d)" % [operation, value]
		else:
			label.text = "%s%d" % [operation, value]

func calculate_clones() -> int:
	if is_locked or not is_active():
		return 0
	if operation == "x":
		return maxi(0, value - 1)
	return maxi(0, value)

func is_active() -> bool:
	if is_locked:
		return false
	if is_instance_valid(blockading_vault) and not blockading_vault.is_queued_for_deletion():
		if "hp" in blockading_vault and blockading_vault.hp > 0:
			return false
	return true

func unlock() -> void:
	is_locked = false
	blockading_vault = null
	if is_instance_valid(target_gate):
		if "is_locked" in target_gate:
			target_gate.is_locked = false
		if target_gate.has_method("unlock"):
			target_gate.unlock()
		if target_gate.has_method("update_label"):
			target_gate.update_label()
	update_label()

func lock(p_vault: Node3D = null) -> void:
	is_locked = true
	blockading_vault = p_vault
	update_label()

func take_damage(amount: int = 1) -> void:
	hp = maxi(0, hp - amount)
	update_label()
	if hp <= 0:
		unlock()

func setup_evolution(start_level: int = 1) -> void:
	is_evolution_gate = true
	gate_mode = GateMode.EVOLUTION
	operation = "+"
	level = clampi(start_level, MIN_LEVEL, MAX_LEVEL)
	progress = (level - MIN_LEVEL) * PROGRESS_PER_LEVEL
	value = level
	add_to_group("evolution_gates")
	update_label()

func feed_blue(amount: int = 1) -> void:
	if not is_evolution():
		return
	progress += amount
	_recalculate_evolution()

func sabotage_red(amount: int = 1) -> void:
	if not is_evolution():
		return
	progress = maxi(0, progress - amount)
	_recalculate_evolution()

func _recalculate_evolution() -> void:
	var max_prog: int = (MAX_LEVEL - MIN_LEVEL) * PROGRESS_PER_LEVEL
	progress = clampi(progress, 0, max_prog)
	level = clampi(MIN_LEVEL + int(progress / PROGRESS_PER_LEVEL), MIN_LEVEL, MAX_LEVEL)
	value = level
	operation = "+"
	update_label()
