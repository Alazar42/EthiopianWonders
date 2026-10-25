class_name PauseMenu
extends Control
## Pause card: the dim fades in, the card pops in and its buttons follow one after another.

signal resume_requested
signal restart_requested
signal main_menu_requested
signal album_requested

## Shows the photo album button (open world only).
@export var album_enabled: bool = false

@onready var _dim: Control = %Dim
@onready var _card: Control = %Card
@onready var _resume_button: Button = %ResumeButton
@onready var _restart_button: Button = %RestartButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _album_button: Button = %AlbumButton
@onready var _music_slider: HSlider = %MusicSlider
@onready var _effects_slider: HSlider = %EffectsSlider

func _ready() -> void:
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	_album_button.visible = album_enabled
	_album_button.pressed.connect(func() -> void: album_requested.emit())
	_music_slider.value_changed.connect(func(v: float) -> void: GameSound.set_bus_volume(GameSound.MUSIC_BUS, v))
	_effects_slider.value_changed.connect(func(v: float) -> void: GameSound.set_bus_volume(GameSound.EFFECTS_BUS, v))

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause_game"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()

func show_pause() -> void:
	_music_slider.set_value_no_signal(GameSound.get_bus_volume(GameSound.MUSIC_BUS))
	_effects_slider.set_value_no_signal(GameSound.get_bus_volume(GameSound.EFFECTS_BUS))
	visible = true
	UiCursor.set_arrow()
	UiMotion.fade_in(_dim, 0.0, 0.25)
	await get_tree().process_frame
	UiMotion.pop_in(_card, 0.0, 0.4)
	var buttons: Array[Control] = [_resume_button, _restart_button, _album_button, _main_menu_button]
	for i in buttons.size():
		UiMotion.fade_in(buttons[i], 0.12 + 0.07 * float(i), 0.25)
	_resume_button.grab_focus()

## Closing is instant, so resuming feels snappy.
## Gives the keyboard focus back to the first button (after the album closes).
func grab_focus_on_resume() -> void:
	if visible:
		_resume_button.grab_focus()

func hide_pause() -> void:
	UiMotion.reset(_card)
	UiMotion.reset(_dim)
	visible = false
	UiCursor.set_crosshair()
