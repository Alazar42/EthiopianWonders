class_name LaneMovement
extends RefCounted
## Free sideways steering across a wide band on either side of the route centreline. The ship
## accelerates toward the steer input and eases to a stop, so it can sit anywhere in the band, not
## just in three fixed lanes.

## Furthest the ship can be from the centreline, to either side.
var max_offset: float = 7.0
## Sideways top speed in units per second.
var max_speed: float = 12.0
## How quickly the sideways speed follows the input.
var acceleration: float = 48.0

## Steering input from -1 (left) to +1 (right); set by the player controller every frame.
var steer: float = 0.0
## Lateral distance from the route centerline, positive to the right.
var offset: float = 0.0
var velocity: float = 0.0
## Banking angle while sliding sideways.
var roll: float = 0.0

func update(delta: float) -> void:
	velocity = move_toward(velocity, clampf(steer, -1.0, 1.0) * max_speed, acceleration * delta)
	offset += velocity * delta
	if absf(offset) > max_offset:
		offset = clampf(offset, -max_offset, max_offset)
		# Pressing against the edge stops the slide instead of storing up speed.
		if signf(velocity) == signf(offset):
			velocity = 0.0
	var target_roll: float = clampf(-velocity / max_speed * 0.4, -0.4, 0.4)
	roll = move_toward(roll, target_roll, delta * 3.5)

## Puts the ship at `value` right away, at rest. Used by tests and when a run starts.
func place(value: float) -> void:
	offset = clampf(value, -max_offset, max_offset)
	velocity = 0.0
	steer = 0.0

func reset() -> void:
	place(0.0)
	roll = 0.0
