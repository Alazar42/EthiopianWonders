class_name LaneMovement
extends RefCounted
## Three logical lanes (-1, 0, +1) with smooth lateral interpolation.

signal lane_changed(new_lane: int)

const LANE_LEFT: int = -1
const LANE_CENTER: int = 0
const LANE_RIGHT: int = 1

var lane_width: float = 2.4
var switch_speed: float = 14.0

var target_lane: int = 0
## Lateral distance from the route centerline, positive to the right.
var offset: float = 0.0
## Banking angle while sliding between lanes.
var roll: float = 0.0

func shift(direction: int) -> bool:
	var next_lane: int = clampi(target_lane + direction, LANE_LEFT, LANE_RIGHT)
	if next_lane == target_lane:
		return false
	target_lane = next_lane
	lane_changed.emit(target_lane)
	return true

func current_lane() -> int:
	return clampi(roundi(offset / lane_width), LANE_LEFT, LANE_RIGHT)

func update(delta: float) -> void:
	var target_offset: float = float(target_lane) * lane_width
	var remaining: float = target_offset - offset
	offset = move_toward(offset, target_offset, switch_speed * delta)
	var target_roll: float = clampf(-remaining * 0.12, -0.25, 0.25)
	roll = move_toward(roll, target_roll, delta * 3.5)

func reset() -> void:
	target_lane = 0
	offset = 0.0
	roll = 0.0
