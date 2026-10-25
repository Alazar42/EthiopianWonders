class_name Splash
extends Control
## Start-up screens, played as short cinematic shots: black letterbox bars slide in, the logo
## drifts slowly toward the camera while it fades up out of a soft vignette, a thin rule draws in
## underneath, and the whole shot dissolves into the next one (the background colour blends, so
## there is never a cut to black between logos). Any key or click skips to the next shot.

const TECHAWACH: Texture2D = preload("res://assets/ui/techawach.jpg")
const MELKAM: Texture2D = preload("res://assets/ui/melkam.jpg")

## One entry per shot: the picture, the colour of its background and its height as a share of the
## window. The logos are shown fairly small so they stay sharp.
const SHOTS: Array[Dictionary] = [
	{"texture": TECHAWACH, "background": Color.WHITE, "height": 0.46, "rule": Color(0.72, 0.5, 0.18)},
	{"texture": MELKAM, "background": Color(0.098, 0.098, 0.098), "height": 0.52, "rule": Color(0.85, 0.85, 0.85)},
]
const BAR_SHARE: float = 0.11

@export_file("*.tscn") var next_scene: String = "res://scenes/menus/main_menu.tscn"
@export var shot_time: float = 3.6
@export var dissolve_time: float = 0.8
## Input is ignored this long so a stray key press does not skip a logo unseen.
@export var skip_delay: float = 0.4

@onready var _background: ColorRect = %Background
@onready var _logo: TextureRect = %Logo
@onready var _vignette: TextureRect = %Vignette
@onready var _rule: ColorRect = %Rule
@onready var _bar_top: ColorRect = %BarTop
@onready var _bar_bottom: ColorRect = %BarBottom

var _tween: Tween
var _age: float = 0.0
var _finished: bool = false
## Index of the shot on screen; SHOTS.size() once the splash is over.
var index: int = 0

func _ready() -> void:
	Input.set_custom_mouse_cursor(null)
	_background.color = SHOTS[0]["background"]
	_vignette.modulate = SHOTS[0]["background"]
	_show_shot(0)

func _process(delta: float) -> void:
	_age += delta

func _unhandled_input(event: InputEvent) -> void:
	if _finished or _age < skip_delay or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		skip()
		get_viewport().set_input_as_handled()

## Dissolves into the next shot, or into the menu after the last one.
func skip() -> void:
	if _finished:
		return
	if index + 1 >= SHOTS.size():
		_finish()
	else:
		_show_shot(index + 1)

## Size of the logo on screen for the current window.
func logo_size() -> Vector2:
	return Vector2(_logo.offset_right - _logo.offset_left, _logo.offset_bottom - _logo.offset_top)

func _show_shot(i: int) -> void:
	index = i
	_age = 0.0
	if _tween:
		_tween.kill()
	var shot: Dictionary = SHOTS[i]
	var texture: Texture2D = shot["texture"]
	var height: float = get_viewport_rect().size.y * float(shot["height"])
	var half := Vector2(height * texture.get_width() / texture.get_height(), height) * 0.5
	_logo.texture = texture
	_logo.offset_left = -half.x
	_logo.offset_right = half.x
	_logo.offset_top = -half.y
	_logo.offset_bottom = half.y
	_logo.pivot_offset = half
	_logo.scale = Vector2(0.9, 0.9)
	_logo.modulate.a = 0.0
	_rule.color = shot["rule"]
	_rule.modulate.a = 0.0
	_rule.scale = Vector2(0.1, 1.0)
	_rule.pivot_offset = Vector2(90, 1)
	var fade: float = 0.0 if i == 0 else dissolve_time
	_tween = create_tween().set_parallel(true)
	# The background blends into this shot's colour while the previous logo is already gone.
	_tween.tween_property(_background, "color", shot["background"], fade)
	_tween.tween_property(_vignette, "modulate", shot["background"], fade)
	# Letterbox bars close in for the shot.
	_tween.tween_property(_bar_top, "anchor_bottom", BAR_SHARE, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_bar_bottom, "anchor_top", 1.0 - BAR_SHARE, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# A slow push toward the logo for the whole shot, fading up and then away.
	_tween.tween_property(_logo, "scale", Vector2(1.04, 1.04), shot_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_logo, "modulate:a", 1.0, 1.0).set_delay(0.2 + fade * 0.5)
	_tween.tween_property(_rule, "modulate:a", 1.0, 0.6).set_delay(1.0)
	_tween.tween_property(_rule, "scale:x", 1.0, 0.9).set_delay(1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_logo, "modulate:a", 0.0, dissolve_time).set_delay(shot_time - dissolve_time)
	_tween.tween_property(_rule, "modulate:a", 0.0, dissolve_time * 0.6).set_delay(shot_time - dissolve_time)
	_tween.chain().tween_callback(skip)

func _finish() -> void:
	_finished = true
	index = SHOTS.size()
	if _tween:
		_tween.kill()
	# Fade the last frame to black so the menu's own fade-in continues from it.
	var out := create_tween().set_parallel(true)
	out.tween_property(_background, "color", Color.BLACK, 0.35)
	out.tween_property(_vignette, "modulate", Color.BLACK, 0.35)
	await out.finished
	get_tree().change_scene_to_file(next_scene)
