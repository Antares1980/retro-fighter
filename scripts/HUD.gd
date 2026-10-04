class_name HUD
extends CanvasLayer

## HUD Overlay for Retro Fighter.
## Displays yellow-to-red depleting health bars for P1 & P2,
## a 99-second countdown timer, and center announcer banners ("FIGHT!", "K.O.", "TIME UP", "DRAW").

const COLOR_HIGH_HP: Color = Color(1.0, 0.85, 0.1, 1.0) # Yellow
const COLOR_MID_HP: Color = Color(1.0, 0.5, 0.1, 1.0)   # Orange
const COLOR_LOW_HP: Color = Color(0.9, 0.15, 0.15, 1.0) # Red

@onready var p1_health_bar: ProgressBar = $P1HealthBar if has_node("P1HealthBar") else null
@onready var p2_health_bar: ProgressBar = $P2HealthBar if has_node("P2HealthBar") else null
@onready var timer_label: Label = $TimerLabel if has_node("TimerLabel") else null
@onready var announcer_label: Label = $AnnouncerLabel if has_node("AnnouncerLabel") else null

func _ready() -> void:
	_init_nodes()
	reset_hud()

func _init_nodes() -> void:
	if p1_health_bar == null and has_node("P1HealthBar"):
		p1_health_bar = $P1HealthBar
	if p2_health_bar == null and has_node("P2HealthBar"):
		p2_health_bar = $P2HealthBar
	if timer_label == null and has_node("TimerLabel"):
		timer_label = $TimerLabel
	if announcer_label == null and has_node("AnnouncerLabel"):
		announcer_label = $AnnouncerLabel

## Updates Player 1 health bar value and color.
func update_p1_health(health: int, max_hp: int = 100) -> void:
	_init_nodes()
	if p1_health_bar != null:
		p1_health_bar.max_value = max_hp
		p1_health_bar.value = health
		_update_health_bar_color(p1_health_bar, health, max_hp)

## Updates Player 2 health bar value and color.
func update_p2_health(health: int, max_hp: int = 100) -> void:
	_init_nodes()
	if p2_health_bar != null:
		p2_health_bar.max_value = max_hp
		p2_health_bar.value = health
		_update_health_bar_color(p2_health_bar, health, max_hp)

## Updates the round countdown timer display.
func update_timer(seconds: int) -> void:
	_init_nodes()
	if timer_label != null:
		timer_label.text = "%02d" % max(0, seconds)

## Displays center announcer message with banner styling.
func show_announcer(text: String) -> void:
	_init_nodes()
	if announcer_label != null:
		announcer_label.text = text
		announcer_label.visible = true

## Hides the center announcer banner.
func hide_announcer() -> void:
	_init_nodes()
	if announcer_label != null:
		announcer_label.text = ""
		announcer_label.visible = false

## Resets all HUD elements to default match starting conditions.
func reset_hud() -> void:
	update_p1_health(100, 100)
	update_p2_health(100, 100)
	update_timer(99)
	hide_announcer()

# Aliases for flexibility across callers
func set_p1_health(health: int, max_hp: int = 100) -> void:
	update_p1_health(health, max_hp)

func set_p2_health(health: int, max_hp: int = 100) -> void:
	update_p2_health(health, max_hp)

func set_timer(seconds: int) -> void:
	update_timer(seconds)

func set_announcer_text(text: String) -> void:
	if text.is_empty():
		hide_announcer()
	else:
		show_announcer(text)

func _update_health_bar_color(bar: ProgressBar, health: int, max_hp: int) -> void:
	var ratio: float = float(health) / float(max(1, max_hp))
	var c: Color = COLOR_HIGH_HP
	if ratio <= 0.25:
		c = COLOR_LOW_HP
	elif ratio <= 0.5:
		c = COLOR_MID_HP
	bar.modulate = c
