class_name Splash
extends Control
## Start-up screens: the Techawach Games logo on white, then the Melkam Studios logo full screen.
## Each fades in, holds and fades out. Any key or click skips ahead.

const TECHAWACH: Texture2D = preload("res://assets/ui/techawach.jpg")
const MELKAM: Texture2D = preload("res://assets/ui/melkam.jpg")
## The Melkam picture's dark grey edge, used behind it so any window shape looks seamless.
const MELKAM_BACKGROUND: Color = Color(0.098, 0.098, 0.098)

@export_file("*.tscn") var next_scene: String = "res://scenes/menus/main_menu.tscn"
@export var fade_time: float = 0.5
@export var hold_time: float = 1.6
## Input is ignored this long so a stray key press does not skip a logo unseen.
@export var skip_delay: float = 0.4

@onready var _background: ColorRect = %Background
@onready var _logo: TextureRect = %Logo

var _tween: Tween
var _age: float = 0.0
var _finished: bool = false
## 0 = Techawach, 1 = Melkam, 2 = done.
var index: int = 0

func _ready() -> void:
	Input.set_custom_mouse_cursor(null)
	_show_logo(0)

func _process(delta: float) -> void:
	_age += delta

func _unhandled_input(event: InputEvent) -> void:
	if _finished or _age < skip_delay or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		skip()
		get_viewport().set_input_as_handled()

## Jumps to the next logo, or to the menu after the last one.
func skip() -> void:
	if _finished:
		return
	if index >= 1:
		_finish()
	else:
		_show_logo(index + 1)

func _show_logo(i: int) -> void:
	index = i
	_age = 0.0
	if _tween:
		_tween.kill()
	if i == 0:
		_background.color = Color.WHITE
		_logo.texture = TECHAWACH
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		_background.color = MELKAM_BACKGROUND
		_logo.texture = MELKAM
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_logo.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(_logo, "modulate:a", 1.0, fade_time)
	_tween.tween_interval(hold_time)
	_tween.tween_property(_logo, "modulate:a", 0.0, fade_time)
	_tween.tween_callback(skip)

func _finish() -> void:
	_finished = true
	index = 2
	if _tween:
		_tween.kill()
	get_tree().change_scene_to_file(next_scene)
