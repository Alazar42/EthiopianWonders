class_name MainMenu
extends Control

@export_file("*.tscn") var game_scene: String = "res://scenes/game/game_world.tscn"
@export var planet_spin_speed: float = 0.12

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _planet: Node3D = %MenuPlanet

func _ready() -> void:
	_play_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(game_scene))
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	_quit_button.visible = not OS.has_feature("web")
	_play_button.grab_focus()

func _process(delta: float) -> void:
	_planet.rotate_y(delta * planet_spin_speed)
