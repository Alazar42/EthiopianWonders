class_name OpenWorldHUD
extends Control
## Open-world overlay: the planet's picture challenge, the artifact detector, toasts and the
## viewfinder shown while the photo camera is active. The manager tells it what to show.

signal pause_requested

const TOAST_OFFSET: Vector2 = Vector2(0, 40)
## Tints of the frame and of the panel under it: green when a picture would count, red otherwise.
const FRAMED_COLOR: Color = Color(0.4, 1.0, 0.55)
const LOOSE_COLOR: Color = Color(1.0, 0.45, 0.35)

@onready var _status_panel: Control = %StatusPanel
@onready var _planet_label: Label = %PlanetLabel
@onready var _challenge_label: Label = %ChallengeLabel
@onready var _detector_label: Label = %DetectorLabel
@onready var _pause_button: Button = %PauseButton
@onready var _prompt_panel: Control = %PromptPanel
@onready var _prompt_label: Label = %PromptLabel
@onready var _toast_panel: Control = %ToastPanel
@onready var _toast_label: Label = %ToastLabel
@onready var _toast_timer: Timer = %ToastTimer
@onready var _viewfinder: Control = %Viewfinder
@onready var _frame: Control = %Frame
@onready var _zoom_label: Label = %ZoomLabel
@onready var _framed_label: Label = %FramedLabel
@onready var _bottom_panel: Control = %BottomPanel
@onready var _flight_group: Control = %FlightGroup
@onready var _animation: AnimationPlayer = $AnimationPlayer

var _toast_open: bool = false
var _shown_captured: int = -1

func _ready() -> void:
	_pause_button.pressed.connect(func() -> void: pause_requested.emit())
	_toast_timer.timeout.connect(func() -> void:
		_toast_open = false
		UiMotion.slide_out(_toast_panel, TOAST_OFFSET, 0.3))
	_viewfinder.visible = false
	_prompt_panel.visible = false
	play_intro()

## The status panel slides in and the pause button follows.
func play_intro() -> void:
	await get_tree().process_frame
	UiMotion.slide_in(_status_panel, Vector2(-30, -70), 0.1, 0.55)
	UiMotion.slide_in(_pause_button, Vector2(30, -70), 0.2, 0.55)

func set_planet(planet_name: String, required: int) -> void:
	_planet_label.text = planet_name
	_shown_captured = -1
	set_progress(0, required)

func set_progress(captured: int, required: int) -> void:
	_challenge_label.text = "Pictures  %d / %d" % [captured, required]
	if captured > _shown_captured and _shown_captured >= 0:
		UiMotion.punch(_challenge_label, 1.4, 0.5)
	_shown_captured = captured

## `text` is the detector read-out; an empty string clears it.
func set_detector(text: String) -> void:
	_detector_label.text = text

## The call to action shown when an artifact is close enough to photograph.
func set_prompt(text: String) -> void:
	var show_it: bool = not text.is_empty()
	if show_it:
		_prompt_label.text = text
	if show_it != _prompt_panel.visible and not _viewfinder.visible:
		_prompt_panel.visible = show_it
		if show_it:
			UiMotion.pop_in(_prompt_panel, 0.0, 0.35)
	elif _viewfinder.visible:
		_prompt_panel.visible = false

func show_toast(text: String) -> void:
	_toast_label.text = text
	if _toast_open:
		UiMotion.punch(_toast_label, 1.06, 0.3)
	else:
		UiMotion.slide_in(_toast_panel, TOAST_OFFSET, 0.0, 0.4)
	_toast_open = true
	_toast_timer.start()

func is_viewfinder_open() -> bool:
	return _viewfinder.visible

## Swaps the flight overlay for the camera's viewfinder.
func show_viewfinder(open: bool) -> void:
	_viewfinder.visible = open
	_flight_group.visible = not open
	if open:
		_prompt_panel.visible = false
		UiMotion.fade_in(_viewfinder, 0.0, 0.3)
		set_framed(false, "")
		set_zoom(1.0)

## Green frame and the artifact's name when a picture would count; red otherwise.
func set_framed(framed: bool, artifact_name: String) -> void:
	_frame.modulate = FRAMED_COLOR if framed else LOOSE_COLOR
	_bottom_panel.modulate = FRAMED_COLOR if framed else LOOSE_COLOR
	_framed_label.text = ("Framed: %s  -  shoot!" % artifact_name) if framed else "Fit the whole artifact inside the frame"

func set_zoom(factor: float) -> void:
	_zoom_label.text = "Zoom  x%.1f" % factor

func flash_shutter() -> void:
	_animation.stop()
	_animation.play("shutter")

## Hides every overlay for the moment a picture is taken, so the file holds only the view.
func hide_for_capture(hidden: bool) -> void:
	visible = not hidden
