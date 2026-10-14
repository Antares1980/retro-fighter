class_name Menu
extends Control

## Arcade Hub Launcher & Game Selection Menu.
## Provides game selection, navigation, audio playback, and guarded transitions.

signal game_selected(scene_path: String)
signal quit_requested

var _is_transitioning: bool = false

@onready var btn_retro_fighter: Button = $VBoxContainer/RetroFighterButton if has_node("VBoxContainer/RetroFighterButton") else null
@onready var btn_coming_soon: Button = $VBoxContainer/ComingSoonButton if has_node("VBoxContainer/ComingSoonButton") else null
@onready var btn_quit: Button = $VBoxContainer/QuitButton if has_node("VBoxContainer/QuitButton") else null
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer if has_node("BGMPlayer") else null

# Aliases for direct property access and specification compliance
var RetroFighterButton: Button:
	get:
		if btn_retro_fighter == null:
			_resolve_nodes()
		return btn_retro_fighter

var ComingSoonButton: Button:
	get:
		if btn_coming_soon == null:
			_resolve_nodes()
		return btn_coming_soon

var QuitButton: Button:
	get:
		if btn_quit == null:
			_resolve_nodes()
		return btn_quit

var BGMPlayer: AudioStreamPlayer:
	get:
		if bgm_player == null:
			_resolve_nodes()
		return bgm_player

func _ready() -> void:
	_resolve_nodes()
	_start_bgm()
	if is_instance_valid(btn_retro_fighter):
		btn_retro_fighter.grab_focus()

func _start_bgm() -> void:
	_resolve_nodes()
	if is_instance_valid(bgm_player) and bgm_player.is_inside_tree():
		if not bgm_player.playing:
			bgm_player.play()

func _resolve_nodes() -> void:
	if btn_retro_fighter == null:
		btn_retro_fighter = get_node_or_null("VBoxContainer/RetroFighterButton")
		if btn_retro_fighter == null:
			btn_retro_fighter = get_node_or_null("RetroFighterButton")
		if btn_retro_fighter == null:
			btn_retro_fighter = get_node_or_null("VBoxContainer/btn_retro_fighter")
		if btn_retro_fighter == null:
			btn_retro_fighter = get_node_or_null("btn_retro_fighter")

	if btn_coming_soon == null:
		btn_coming_soon = get_node_or_null("VBoxContainer/ComingSoonButton")
		if btn_coming_soon == null:
			btn_coming_soon = get_node_or_null("ComingSoonButton")
		if btn_coming_soon == null:
			btn_coming_soon = get_node_or_null("VBoxContainer/btn_coming_soon")
		if btn_coming_soon == null:
			btn_coming_soon = get_node_or_null("btn_coming_soon")

	if btn_quit == null:
		btn_quit = get_node_or_null("VBoxContainer/QuitButton")
		if btn_quit == null:
			btn_quit = get_node_or_null("QuitButton")
		if btn_quit == null:
			btn_quit = get_node_or_null("VBoxContainer/btn_quit")
		if btn_quit == null:
			btn_quit = get_node_or_null("btn_quit")

	if bgm_player == null:
		bgm_player = get_node_or_null("BGMPlayer")

	if is_instance_valid(btn_retro_fighter) and not btn_retro_fighter.pressed.is_connected(_on_retro_fighter_pressed):
		btn_retro_fighter.pressed.connect(_on_retro_fighter_pressed)
	if is_instance_valid(btn_coming_soon) and not btn_coming_soon.pressed.is_connected(_on_coming_soon_pressed):
		btn_coming_soon.pressed.connect(_on_coming_soon_pressed)
	if is_instance_valid(btn_quit) and not btn_quit.pressed.is_connected(_on_quit_pressed):
		btn_quit.pressed.connect(_on_quit_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("p1_down") or event.is_action_pressed("ui_down"):
		_navigate_down()
		if get_viewport():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("p1_up") or event.is_action_pressed("ui_up"):
		_navigate_up()
		if get_viewport():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("p1_punch") or event.is_action_pressed("ui_accept"):
		_activate_focused_button()
		if get_viewport():
			get_viewport().set_input_as_handled()

func _navigate_down() -> void:
	_resolve_nodes()
	if is_instance_valid(btn_retro_fighter) and btn_retro_fighter.has_focus():
		if is_instance_valid(btn_coming_soon):
			btn_coming_soon.grab_focus()
		elif is_instance_valid(btn_quit):
			btn_quit.grab_focus()
	elif is_instance_valid(btn_coming_soon) and btn_coming_soon.has_focus():
		if is_instance_valid(btn_quit):
			btn_quit.grab_focus()
		elif is_instance_valid(btn_retro_fighter):
			btn_retro_fighter.grab_focus()
	elif is_instance_valid(btn_quit) and btn_quit.has_focus():
		if is_instance_valid(btn_retro_fighter):
			btn_retro_fighter.grab_focus()
		elif is_instance_valid(btn_coming_soon):
			btn_coming_soon.grab_focus()
	else:
		if is_instance_valid(btn_retro_fighter):
			btn_retro_fighter.grab_focus()

func _navigate_up() -> void:
	_resolve_nodes()
	if is_instance_valid(btn_quit) and btn_quit.has_focus():
		if is_instance_valid(btn_coming_soon):
			btn_coming_soon.grab_focus()
		elif is_instance_valid(btn_retro_fighter):
			btn_retro_fighter.grab_focus()
	elif is_instance_valid(btn_coming_soon) and btn_coming_soon.has_focus():
		if is_instance_valid(btn_retro_fighter):
			btn_retro_fighter.grab_focus()
		elif is_instance_valid(btn_quit):
			btn_quit.grab_focus()
	elif is_instance_valid(btn_retro_fighter) and btn_retro_fighter.has_focus():
		if is_instance_valid(btn_quit):
			btn_quit.grab_focus()
		elif is_instance_valid(btn_coming_soon):
			btn_coming_soon.grab_focus()
	else:
		if is_instance_valid(btn_retro_fighter):
			btn_retro_fighter.grab_focus()

func _activate_focused_button() -> void:
	_resolve_nodes()
	if is_instance_valid(btn_quit) and btn_quit.has_focus():
		_on_quit_pressed()
	elif is_instance_valid(btn_coming_soon) and btn_coming_soon.has_focus():
		_on_coming_soon_pressed()
	elif is_instance_valid(btn_retro_fighter) and btn_retro_fighter.has_focus():
		_on_retro_fighter_pressed()
	else:
		_on_retro_fighter_pressed()

func _on_retro_fighter_pressed() -> void:
	launch_game("res://scenes/Main.tscn")

func _on_coming_soon_pressed() -> void:
	launch_game("res://scenes/mob_control/MobControlMain.tscn")

func launch_game(scene_path: String = "res://scenes/Main.tscn") -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	if is_instance_valid(bgm_player):
		bgm_player.stop()

	game_selected.emit(scene_path)

	if is_inside_tree() and get_tree() != null and (get_tree().current_scene == self or get_tree().current_scene == null):
		get_tree().change_scene_to_file(scene_path)

func _on_quit_pressed() -> void:
	quit_game()

func quit_game() -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	if is_instance_valid(bgm_player):
		bgm_player.stop()

	quit_requested.emit()

	if is_inside_tree() and get_tree() != null and get_tree().current_scene == self:
		get_tree().quit()
