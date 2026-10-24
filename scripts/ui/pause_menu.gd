class_name PauseMenu
extends Control

signal resume_requested
signal restart_requested
signal main_menu_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _main_menu_button: Button = %MainMenuButton

func _ready() -> void:
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause_game"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()

func show_pause() -> void:
	visible = true
	_resume_button.grab_focus()

func hide_pause() -> void:
	visible = false
