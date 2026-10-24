class_name UiMotion
extends RefCounted
## Smooth UI animation helpers built on Tweens.
##
## Every animation owns one tween per control and channel, so starting a new one replaces the
## old one instead of fighting it. Tweens keep running while the game is paused (menus animate),
## and every animation ends on an exact, clean state so a control is never left hidden or scaled.
##
## Note: Containers reset the scale of their children when they re-sort, so animate children of
## containers after layout has settled (await one frame) and prefer fades for them.

const SPRING_HOVER: float = 1.06
const SPRING_PRESS: float = 0.94

static func _tween(control: Control, channel: String = "motion") -> Tween:
	var key: String = "_tween_" + channel
	if control.has_meta(key):
		var old: Variant = control.get_meta(key)
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	var tween: Tween = control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	control.set_meta(key, tween)
	return tween

## Where a control rests. While a slide is still running its remembered home is reused, so
## re-triggering a slide mid-motion never drifts the control.
static func _home(control: Control) -> Vector2:
	var running: bool = false
	if control.has_meta("_tween_motion"):
		var old: Variant = control.get_meta("_tween_motion")
		running = old is Tween and (old as Tween).is_running()
	if not running or not control.has_meta("_home"):
		control.set_meta("_home", control.position)
	return control.get_meta("_home")

## Stops every animation on a control and puts it back at rest (home position, opaque, unscaled).
static func reset(control: Control) -> void:
	for channel in ["motion", "punch", "wobble", "spring", "count"]:
		var key: String = "_tween_" + channel
		if control.has_meta(key):
			var old: Variant = control.get_meta(key)
			if old is Tween and (old as Tween).is_valid():
				(old as Tween).kill()
	if control.has_meta("_home"):
		control.position = control.get_meta("_home")
	control.modulate.a = 1.0
	control.scale = Vector2.ONE
	control.rotation_degrees = 0.0

static func center_pivot(control: Control) -> void:
	control.pivot_offset = control.size * 0.5

## Scales up from a little smaller while fading in, with a gentle overshoot.
static func pop_in(control: Control, delay: float = 0.0, duration: float = 0.42) -> Tween:
	control.visible = true
	center_pivot(control)
	control.modulate.a = 0.0
	control.scale = Vector2(0.82, 0.82)
	var tween: Tween = _tween(control).set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.55).set_delay(delay)
	tween.tween_property(control, "scale", Vector2.ONE, duration).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween

## Shrinks and fades out, then hides the control and restores it for the next time it is shown.
static func pop_out(control: Control, duration: float = 0.2) -> Tween:
	center_pivot(control)
	var tween: Tween = _tween(control).set_parallel(true)
	tween.tween_property(control, "modulate:a", 0.0, duration)
	tween.tween_property(control, "scale", Vector2(0.9, 0.9), duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		control.visible = false
		control.scale = Vector2.ONE
		control.modulate.a = 1.0)
	return tween

static func fade_in(control: Control, delay: float = 0.0, duration: float = 0.35) -> Tween:
	control.visible = true
	control.modulate.a = 0.0
	var tween: Tween = _tween(control)
	tween.tween_property(control, "modulate:a", 1.0, duration).set_delay(delay)
	return tween

## Slides in from `offset` away from where the control sits now, fading in as it goes.
static func slide_in(control: Control, offset: Vector2, delay: float = 0.0, duration: float = 0.5) -> Tween:
	var target: Vector2 = _home(control)
	control.visible = true
	control.position = target + offset
	control.modulate.a = 0.0
	var tween: Tween = _tween(control).set_parallel(true)
	tween.tween_property(control, "position", target, duration).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration * 0.6).set_delay(delay)
	return tween

## Slides away by `offset`, then hides the control and puts it back where it was.
static func slide_out(control: Control, offset: Vector2, duration: float = 0.3) -> Tween:
	var home: Vector2 = _home(control)
	var tween: Tween = _tween(control).set_parallel(true)
	tween.tween_property(control, "position", home + offset, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(control, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(func() -> void:
		control.visible = false
		control.position = home
		control.modulate.a = 1.0)
	return tween

## A quick scale pulse with a little wobble, for emphasis (a heart lost, a wonder found).
static func punch(control: Control, strength: float = 1.4, duration: float = 0.45) -> Tween:
	center_pivot(control)
	control.scale = Vector2.ONE
	var tween: Tween = _tween(control, "punch")
	tween.tween_property(control, "scale", Vector2.ONE * strength, duration * 0.25) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.75) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var wobble: Tween = _tween(control, "wobble")
	wobble.tween_property(control, "rotation_degrees", -12.0, duration * 0.15)
	wobble.tween_property(control, "rotation_degrees", 9.0, duration * 0.2)
	wobble.tween_property(control, "rotation_degrees", -4.0, duration * 0.2)
	wobble.tween_property(control, "rotation_degrees", 0.0, duration * 0.2)
	return tween

## Counts a number up (or down) in a label. `format` turns the integer into the shown text.
static func count_up(label: Label, from_value: int, to_value: int, duration: float = 0.5,
		format: Callable = Callable(), delay: float = 0.0) -> Tween:
	var show: Callable = func(value: int) -> void:
		label.text = str(value) if format.is_null() else format.call(value)
	var tween: Tween = _tween(label, "count")
	tween.tween_method(func(v: float) -> void: show.call(roundi(v)), float(from_value), float(to_value), duration) \
			.set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: show.call(to_value))
	return tween

## Springs a button up when hovered and squashes it when pressed. Idempotent.
static func hook_button(button: BaseButton) -> void:
	if button.has_meta("_motion_hooked"):
		return
	button.set_meta("_motion_hooked", true)
	button.resized.connect(func() -> void: center_pivot(button))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			_spring(button, SPRING_HOVER))
	button.mouse_exited.connect(func() -> void: _spring(button, 1.0))
	button.button_down.connect(func() -> void: _spring(button, SPRING_PRESS, 0.07))
	button.button_up.connect(func() -> void:
		_spring(button, SPRING_HOVER if button.is_hovered() and not button.disabled else 1.0))
	center_pivot(button)

static func _spring(button: Control, target: float, duration: float = 0.16) -> void:
	center_pivot(button)
	_tween(button, "spring").tween_property(button, "scale", Vector2.ONE * target, duration) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
