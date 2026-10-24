class_name GameHUD
extends Control

signal pause_requested

@onready var hearts_label: Label = $TopBar/HeartsLabel
@onready var wonders_label: Label = $TopBar/WondersLabel
@onready var distance_label: Label = $TopBar/DistanceLabel
@onready var pause_button: Button = $TopBar/PauseButton
@onready var toast_label: Label = $ToastLabel

var _toast_timer: float = 0.0

func _ready() -> void:
	if pause_button:
		pause_button.pressed.connect(func(): pause_requested.emit())
	if toast_label:
		toast_label.visible = false
	update_hearts(3, 3)

func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and toast_label:
			toast_label.visible = false

func update_hearts(current: int, max_h: int) -> void:
	if not hearts_label:
		return
	var hearts_str = "Hearts: "
	for i in range(max_h):
		if i < current:
			hearts_str += "♥ "
		else:
			hearts_str += "♡ "
	hearts_label.text = hearts_str.strip_edges()

func update_wonders_count(count: int) -> void:
	if wonders_label:
		wonders_label.text = "Wonders: %d" % count

func update_distance(dist_m: float) -> void:
	if distance_label:
		distance_label.text = "Distance: %d m" % int(dist_m)

func show_toast(text: String, is_positive: bool = true) -> void:
	if not toast_label:
		return
	toast_label.text = text
	toast_label.visible = true
	_toast_timer = 2.5
