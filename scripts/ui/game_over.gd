class_name GameOverScreen
extends Control

signal restart_requested
signal main_menu_requested

@onready var _wonders_label: Label = %WondersLabel
@onready var _distance_label: Label = %DistanceLabel
@onready var _time_label: Label = %TimeLabel
@onready var _restart_button: Button = %RestartButton
@onready var _main_menu_button: Button = %MainMenuButton

func _ready() -> void:
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())

func show_game_over(total_wonders: int, distance_m: float, elapsed_sec: float) -> void:
	_wonders_label.text = "Wonders discovered: %d" % total_wonders
	_distance_label.text = "Distance: %d m" % int(distance_m)
	_time_label.text = "Time: %02d:%02d" % [int(elapsed_sec) / 60, int(elapsed_sec) % 60]
	visible = true
	_restart_button.grab_focus()

func hide_screen() -> void:
	visible = false
