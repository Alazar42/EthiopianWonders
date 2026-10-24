class_name GameOverScreen
extends Control

signal restart_requested
signal main_menu_requested

@onready var wonders_stat: Label = $CenterContainer/Panel/VBoxContainer/WondersStat
@onready var distance_stat: Label = $CenterContainer/Panel/VBoxContainer/DistanceStat
@onready var time_stat: Label = $CenterContainer/Panel/VBoxContainer/TimeStat
@onready var restart_btn: Button = $CenterContainer/Panel/VBoxContainer/RestartButton
@onready var main_menu_btn: Button = $CenterContainer/Panel/VBoxContainer/MainMenuButton

func _ready() -> void:
	visible = false
	if restart_btn:
		restart_btn.pressed.connect(func(): restart_requested.emit())
	if main_menu_btn:
		main_menu_btn.pressed.connect(func(): main_menu_requested.emit())

func show_game_over(total_wonders: int, distance_m: float, elapsed_sec: float) -> void:
	visible = true
	if wonders_stat:
		wonders_stat.text = "Wonders Discovered: %d" % total_wonders
	if distance_stat:
		distance_stat.text = "Distance: %d meters" % int(distance_m)
	if time_stat:
		var mins = int(elapsed_sec) / 60
		var secs = int(elapsed_sec) % 60
		time_stat.text = "Time: %02d:%02d" % [mins, secs]
