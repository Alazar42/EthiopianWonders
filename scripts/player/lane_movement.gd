class_name LaneMovement
extends RefCounted

signal lane_changed(new_lane: int)

const LANE_LEFT: int = -1
const LANE_CENTER: int = 0
const LANE_RIGHT: int = 1

var target_lane: int = 0
var current_lane: int = 0
var lane_width: float = 2.2
var switch_speed: float = 12.0 # units per second

var current_offset: float = 0.0
var roll_tilt: float = 0.0 # Radians for banking animation

func shift_left() -> bool:
	if target_lane > LANE_LEFT:
		target_lane -= 1
		lane_changed.emit(target_lane)
		return true
	return false

func shift_right() -> bool:
	if target_lane < LANE_RIGHT:
		target_lane += 1
		lane_changed.emit(target_lane)
		return true
	return false

func update(delta: float) -> void:
	var target_offset = float(target_lane) * lane_width
	var diff = target_offset - current_offset
	
	# Smoothly interpolate lateral offset
	current_offset = move_toward(current_offset, target_offset, switch_speed * delta)
	
	# Update lane index when crossing thresholds
	if current_offset < -lane_width * 0.5:
		current_lane = LANE_LEFT
	elif current_offset > lane_width * 0.5:
		current_lane = LANE_RIGHT
	else:
		current_lane = LANE_CENTER
	
	# Calculate banking tilt based on velocity direction
	var target_tilt = clampf(-diff * 0.12, -0.25, 0.25)
	roll_tilt = move_toward(roll_tilt, target_tilt, delta * 3.5)

func reset() -> void:
	target_lane = 0
	current_lane = 0
	current_offset = 0.0
	roll_tilt = 0.0
