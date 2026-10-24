class_name DiscoveryPopup
extends Control
## Achievement card. It slides in from the top with a spinning star and never pauses the run; it
## closes itself or via the OK button.

signal popup_closed

const SLIDE_OFFSET: Vector2 = Vector2(0, -170)

@onready var _panel: Control = %Panel
@onready var _star: Control = %StarIcon
@onready var _title_label: Label = %TitleLabel
@onready var _wonder_label: Label = %WonderLabel
@onready var _fact_label: Label = %FactLabel
@onready var _count_label: Label = %CountLabel
@onready var _close_button: Button = %CloseButton
@onready var _close_timer: Timer = %CloseTimer

var _open: bool = false

func _ready() -> void:
	_panel.visible = false
	_close_button.pressed.connect(hide_popup)
	_close_timer.timeout.connect(hide_popup)

func is_open() -> bool:
	return _open

func show_discovery(landmark: LandmarkData, total_discovered: int) -> void:
	_title_label.text = landmark.achievement_title
	_wonder_label.text = landmark.name
	_fact_label.text = landmark.get_fact()
	_count_label.text = "Wonders discovered: %d" % total_discovered
	_open = true
	UiMotion.slide_in(_panel, SLIDE_OFFSET, 0.0, 0.6)
	_close_timer.start()
	# The star spins in as the card lands.
	await get_tree().process_frame
	_star.pivot_offset = _star.size * 0.5
	_star.rotation_degrees = -200.0
	_star.create_tween().tween_property(_star, "rotation_degrees", 0.0, 0.8) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## `notify` false is the instant, silent version used when a run restarts or ends.
func hide_popup(notify: bool = true) -> void:
	var was_open: bool = _open
	_open = false
	_close_timer.stop()
	if notify and was_open:
		UiMotion.slide_out(_panel, SLIDE_OFFSET, 0.35)
		popup_closed.emit()
	else:
		UiMotion.reset(_panel)
		_panel.visible = false
