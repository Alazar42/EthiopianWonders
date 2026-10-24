class_name PauseMenu
extends Control

signal resume_requested
signal restart_requested
signal main_menu_requested

@onready var resume_btn: Button = $CenterContainer/Panel/VBoxContainer/ResumeButton
@onready var restart_btn: Button = $CenterContainer/Panel/VBoxContainer/RestartButton
@onready var menu_btn: Button = $CenterContainer/Panel/VBoxContainer/MainMenuButton

func _ready() -> void:
	visible = false
	if resume_btn:
		resume_btn.pressed.connect(func(): resume_requested.emit())
	if restart_btn:
		restart_btn.pressed.connect(func(): restart_requested.emit())
	if menu_btn:
		menu_btn.pressed.connect(func(): main_menu_requested.emit())

func show_pause() -> void:
	visible = true

func hide_pause() -> void:
	visible = false
