class_name GameHUD
extends Control
## Hearts (full, half, empty), wonder count, distance, toast messages and a red damage flash.
## Everything animates: the panel slides in, hearts pop in and punch when lost, the wonder count
## ticks up, toasts slide. While it is on screen the mouse cursor is a crosshair.

signal pause_requested

const TOAST_OFFSET: Vector2 = Vector2(0, 40)

@export var heart_full: Texture2D
@export var heart_half: Texture2D
@export var heart_empty: Texture2D

@onready var _status_panel: Control = %StatusPanel
@onready var _hearts: Array[Node] = %Hearts.get_children()
@onready var _star: Control = %StarIcon
@onready var _wonders_label: Label = %WondersLabel
@onready var _distance_label: Label = %DistanceLabel
@onready var _toast_panel: Control = %ToastPanel
@onready var _toast_label: Label = %ToastLabel
@onready var _toast_timer: Timer = %ToastTimer
@onready var _pause_button: Button = %PauseButton
@onready var _animation: AnimationPlayer = $AnimationPlayer

var _last_halves: int = -1
var _shown_wonders: int = 0
var _toast_open: bool = false

func _ready() -> void:
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_toast_timer.timeout.connect(func() -> void:
		_toast_open = false
		UiMotion.slide_out(_toast_panel, TOAST_OFFSET, 0.3))
	UiCursor.set_crosshair()
	play_intro()

func _exit_tree() -> void:
	UiCursor.clear()

## The panel slides down, the pause button slides in and the hearts pop in one by one.
func play_intro() -> void:
	await get_tree().process_frame
	UiMotion.slide_in(_status_panel, Vector2(-30, -70), 0.1, 0.55)
	UiMotion.slide_in(_pause_button, Vector2(30, -70), 0.2, 0.55)
	for i in _hearts.size():
		UiMotion.pop_in(_hearts[i] as Control, 0.4 + 0.1 * float(i), 0.45)

## Health arrives in half hearts: each of the three icons shows 2, 1 or 0 of them.
## A heart that loses health punches and flashes red.
func update_hearts(current_halves: int, _max_halves: int) -> void:
	var previous: int = _last_halves
	_last_halves = current_halves
	for i in _hearts.size():
		var heart := _hearts[i] as TextureRect
		var halves: int = clampi(current_halves - i * 2, 0, 2)
		heart.texture = [heart_empty, heart_half, heart_full][halves]
		if previous >= 0 and halves < clampi(previous - i * 2, 0, 2):
			UiMotion.punch(heart, 1.6, 0.55)
			heart.modulate = Color(3.0, 0.5, 0.5)
			heart.create_tween().tween_property(heart, "modulate", Color.WHITE, 0.45)

func update_wonders(count: int) -> void:
	var format: Callable = func(value: int) -> String: return "%d wonder%s" % [value, "" if value == 1 else "s"]
	if count > _shown_wonders:
		UiMotion.count_up(_wonders_label, _shown_wonders, count, 0.45, format)
		UiMotion.punch(_star, 1.5, 0.5)
	else:
		_wonders_label.text = format.call(count)
	_shown_wonders = count

func update_distance(distance_m: float) -> void:
	_distance_label.text = "%d m" % int(distance_m)

func show_toast(text: String) -> void:
	_toast_label.text = text
	# A toast that is still on screen only pulses; one that is leaving (or gone) slides back in.
	if _toast_open:
		UiMotion.punch(_toast_label, 1.06, 0.3)
	else:
		UiMotion.slide_in(_toast_panel, TOAST_OFFSET, 0.0, 0.4)
	_toast_open = true
	_toast_timer.start()

func flash_damage() -> void:
	_animation.stop()
	_animation.play("flash")
