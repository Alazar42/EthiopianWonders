class_name GameHUD
extends Control

signal pause_requested

const LOST_HEART: Color = Color(0.25, 0.25, 0.25, 0.6)

@onready var _hearts: Array[Node] = %Hearts.get_children()
@onready var _wonders_label: Label = %WondersLabel
@onready var _distance_label: Label = %DistanceLabel
@onready var _toast_panel: Control = %ToastPanel
@onready var _toast_label: Label = %ToastLabel
@onready var _toast_timer: Timer = %ToastTimer
@onready var _pause_button: Button = %PauseButton

func _ready() -> void:
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_toast_timer.timeout.connect(func() -> void: _toast_panel.visible = false)

func update_hearts(current: int, _max_hearts: int) -> void:
	for i in _hearts.size():
		(_hearts[i] as TextureRect).modulate = Color.WHITE if i < current else LOST_HEART

func update_wonders(count: int) -> void:
	_wonders_label.text = "   Wonders: %d" % count

func update_distance(distance_m: float) -> void:
	_distance_label.text = "   Distance: %d m" % int(distance_m)

func show_toast(text: String) -> void:
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_timer.start()
