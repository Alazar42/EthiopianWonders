class_name MainMenu
extends Control

@export var game_scene_path: String = "res://scenes/game/game_world.tscn"

@onready var play_button: Button = $CenterContainer/Panel/VBoxContainer/PlayButton
@onready var quit_button: Button = $CenterContainer/Panel/VBoxContainer/QuitButton
@onready var bg_planet: Node3D = $SubViewportContainer/SubViewport/World3D/MenuPlanet

func _ready() -> void:
	if play_button and play_button.focus_mode != Control.FOCUS_NONE:
		play_button.grab_focus()
	if play_button:
		play_button.pressed.connect(_on_play_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		if OS.has_feature("web"):
			quit_button.visible = false

func _process(delta: float) -> void:
	if bg_planet:
		bg_planet.rotate_y(delta * 0.15)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(game_scene_path)

func _on_quit_pressed() -> void:
	get_tree().quit()
