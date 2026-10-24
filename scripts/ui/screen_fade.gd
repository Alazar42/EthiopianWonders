class_name ScreenFade
extends CanvasLayer
## A black overlay for smooth transitions. Starts opaque, so a scene can fade in from black.

@onready var _rect: ColorRect = $Rect

func fade_in(duration: float = 0.8) -> Tween:
	return _fade_to(0.0, duration)

func fade_out(duration: float = 0.35) -> Tween:
	return _fade_to(1.0, duration)

## A short dip used when a run restarts.
func blink(duration: float = 0.4) -> Tween:
	_rect.color.a = 0.75
	return _fade_to(0.0, duration)

func opacity() -> float:
	return _rect.color.a

func _fade_to(alpha: float, duration: float) -> Tween:
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_rect, "color:a", alpha, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tween
