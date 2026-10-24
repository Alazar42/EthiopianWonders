class_name LaserBolt
extends Node3D
## A visual laser bolt that flies from a cannon to the aim point and then reports the impact.
## Whether a wonder was discovered is decided when the shot is fired, not by the bolt.

signal hit(point: Vector3)

@export var speed: float = 110.0

var _target: Vector3 = Vector3.ZERO

func fire(from: Vector3, to: Vector3, up: Vector3) -> void:
	global_position = from
	_target = to
	var direction: Vector3 = to - from
	if direction.length_squared() < 0.0001:
		return
	var hint: Vector3 = up if absf(direction.normalized().dot(up)) < 0.98 else Vector3.RIGHT
	look_at(to, hint)

func _process(delta: float) -> void:
	var remaining: Vector3 = _target - global_position
	var step: float = speed * delta
	if remaining.length() <= step:
		global_position = _target
		hit.emit(_target)
		queue_free()
	else:
		global_position += remaining.normalized() * step
