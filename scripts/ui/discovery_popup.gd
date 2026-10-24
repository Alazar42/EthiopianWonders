class_name DiscoveryPopup
extends Control
## Compact achievement card. It never pauses the run; it closes itself or via the Close button.

signal popup_closed

@onready var _panel: Control = %Panel
@onready var _achievement_label: Label = %AchievementLabel
@onready var _wonder_label: Label = %WonderLabel
@onready var _fact_label: Label = %FactLabel
@onready var _count_label: Label = %CountLabel
@onready var _close_button: Button = %CloseButton
@onready var _close_timer: Timer = %CloseTimer

func _ready() -> void:
	_panel.visible = false
	_close_button.pressed.connect(hide_popup)
	_close_timer.timeout.connect(hide_popup)

func is_open() -> bool:
	return _panel.visible

func show_discovery(landmark: LandmarkData, total_discovered: int) -> void:
	_achievement_label.text = "Achievement Unlocked: %s" % landmark.achievement_title
	_wonder_label.text = landmark.name
	_fact_label.text = landmark.get_fact()
	_count_label.text = "Wonders discovered: %d" % total_discovered
	_panel.visible = true
	_close_timer.start()

func hide_popup(notify: bool = true) -> void:
	var was_open: bool = _panel.visible
	_panel.visible = false
	_close_timer.stop()
	if was_open and notify:
		popup_closed.emit()
