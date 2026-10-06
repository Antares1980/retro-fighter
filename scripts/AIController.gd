class_name AIController
extends Node

## AIController for Retro Fighter CPU Opponents.
## Governs decision making, spatial spacing, attack pulses, and dedicated blocking.
## Communicates with Fighter via the virtual input seam (input_dir, input_punch, input_kick, input_block).

const FighterScript = preload("res://scripts/Fighter.gd")

# Tuning constants
const DEFAULT_DECISION_INTERVAL: float = 0.35
const DEFAULT_JITTER_RANGE: float = 0.05
const FAR_THRESHOLD: float = 85.0
const CLOSE_THRESHOLD: float = 45.0

# References
var fighter = null
var opponent = null

# Configuration
var decision_interval: float = DEFAULT_DECISION_INTERVAL
var jitter_range: float = DEFAULT_JITTER_RANGE
var decision_timer: float = DEFAULT_DECISION_INTERVAL
var rng: RandomNumberGenerator = null

func _init() -> void:
	process_physics_priority = -10
	rng = RandomNumberGenerator.new()
	decision_timer = decision_interval

func _ready() -> void:
	process_physics_priority = -10
	if fighter == null and get_parent() is CharacterBody2D:
		fighter = get_parent()
	if is_instance_valid(fighter) and opponent == null and fighter.get("opponent") != null:
		opponent = fighter.opponent

## Configures the controlled fighter and target opponent.
func setup(p_fighter, p_opponent) -> void:
	fighter = p_fighter
	opponent = p_opponent
	reset()

## Resets virtual inputs and re-arms decision timer to decision_interval.
func reset() -> void:
	_zero_inputs()
	decision_timer = decision_interval

func _physics_process(delta: float) -> void:
	step(delta)

## Advances the AI controller by delta seconds.
## Step order:
## 1. Single-frame strike pulse cleanup (input_punch and input_kick reset to false).
## 2. Actionability guard: returns early and zeros inputs if stunned, knockdown, dead, frozen, or dummy.
## 3. Decision timer countdown and tick execution.
func step(delta: float) -> void:
	# Clear 1-frame attack pulses from previous physics frame
	if is_instance_valid(fighter):
		if fighter.input_punch:
			fighter.input_punch = false
		if fighter.input_kick:
			fighter.input_kick = false

	if not is_instance_valid(fighter):
		return

	if not fighter.is_cpu:
		return

	if _is_guarded():
		_zero_inputs()
		return

	decision_timer -= delta
	if decision_timer <= 0.0:
		decide()
		var jitter: float = rng.randf_range(-jitter_range, jitter_range) if rng != null else 0.0
		decision_timer = decision_interval + jitter

## Evaluates the current game state and sets virtual inputs on the controlled fighter.
func decide() -> void:
	if not is_instance_valid(fighter) or not is_instance_valid(opponent):
		return

	if not fighter.is_cpu:
		return

	if _is_guarded():
		_zero_inputs()
		return

	var dx: float = opponent.position.x - fighter.position.x
	var dist: float = absf(dx)
	var s: float = signf(dx)
	# Defensive fallback: if sign(opponent.position.x - fighter.position.x) == 0.0, fallback dir_to_opponent to -float(fighter.facing)
	var dir_to_opponent: float = -float(fighter.facing) if is_zero_approx(s) else s

	if dist > FAR_THRESHOLD:
		# FAR (> 85.0 px): Advance (input_dir = dir_to_opponent)
		fighter.input_dir = dir_to_opponent
		fighter.input_punch = false
		fighter.input_kick = false
		fighter.input_block = false
	elif dist < CLOSE_THRESHOLD:
		# CLOSE (< 45.0 px)
		var roll: float = rng.randf() if rng != null else 0.0
		if roll < 0.40:
			# Punch: 1-frame pulse
			fighter.input_punch = true
			fighter.input_kick = false
			fighter.input_block = false
			fighter.input_dir = 0.0
		elif roll < 0.70:
			# Kick: 1-frame pulse
			fighter.input_punch = false
			fighter.input_kick = true
			fighter.input_block = false
			fighter.input_dir = 0.0
		elif roll < 0.90:
			# Block: held, input_dir = 0.0
			fighter.input_punch = false
			fighter.input_kick = false
			fighter.input_block = true
			fighter.input_dir = 0.0
		else:
			# Idle Hesitation
			fighter.input_punch = false
			fighter.input_kick = false
			fighter.input_block = false
			fighter.input_dir = 0.0
	else:
		# MID-RANGE (45.0 px to 85.0 px)
		var roll: float = rng.randf() if rng != null else 0.0
		if roll < 0.60:
			# Advance
			fighter.input_dir = dir_to_opponent
			fighter.input_punch = false
			fighter.input_kick = false
			fighter.input_block = false
		elif roll < 0.90:
			# Stand Idle
			fighter.input_dir = 0.0
			fighter.input_punch = false
			fighter.input_kick = false
			fighter.input_block = false
		else:
			# Step Back
			fighter.input_dir = -dir_to_opponent
			fighter.input_punch = false
			fighter.input_kick = false
			fighter.input_block = false

## Checks if fighter is in a non-actionable state, frozen, or dummy.
func _is_guarded() -> bool:
	if not is_instance_valid(fighter):
		return true
	if fighter.inputs_frozen:
		return true
	if fighter.is_dummy:
		return true
	if fighter.state in [
		FighterScript.State.HIT_STUN,
		FighterScript.State.BLOCK_STUN,
		FighterScript.State.KNOCKDOWN,
		FighterScript.State.DEAD
	]:
		return true
	return false

## Zeroes all virtual inputs on the controlled fighter.
func _zero_inputs() -> void:
	if is_instance_valid(fighter):
		fighter.input_dir = 0.0
		fighter.input_punch = false
		fighter.input_kick = false
		fighter.input_block = false
