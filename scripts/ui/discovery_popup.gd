class_name DiscoveryPopup
extends Control

signal popup_closed

@onready var popup_panel: Panel = $CenterContainer/Panel
@onready var achievement_label: Label = $CenterContainer/Panel/VBoxContainer/AchievementLabel
@onready var wonder_name_label: Label = $CenterContainer/Panel/VBoxContainer/WonderNameLabel
@onready var fact_label: Label = $CenterContainer/Panel/VBoxContainer/FactLabel
@onready var count_label: Label = $CenterContainer/Panel/VBoxContainer/HBoxContainer/CountLabel
@onready var close_btn: Button = $CenterContainer/Panel/VBoxContainer/HBoxContainer/CloseButton

var _auto_timer: float = 0.0
var _is_open: bool = false

func _ready() -> void:
	visible = false
	if close_btn:
		close_btn.pressed.connect(hide_popup)

func _process(delta: float) -> void:
	if _is_open and _auto_timer > 0.0:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			hide_popup()

func show_discovery(landmark: LandmarkData, total_discovered: int) -> void:
	if not landmark:
		return
	
	wonder_name_label.text = landmark.name
	achievement_label.text = "Achievement Unlocked: " + landmark.achievement_title
	fact_label.text = landmark.get_fact()
	count_label.text = "Wonders Discovered: %d" % total_discovered
	
	visible = true
	_is_open = true
	_auto_timer = 5.0

func hide_popup() -> void:
	_is_open = false
	visible = false
	popup_closed.emit()
