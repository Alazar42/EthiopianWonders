class_name PlayerGravity
extends RefCounted

## Manages player-specific gravity alignment and surface normal orientation

var current_up: Vector3 = Vector3.UP
var gravity_direction: Vector3 = Vector3.DOWN
var alignment_speed: float = 14.0

func update_orientation(player_pos: Vector3, planet: SphericalPlanet, delta: float) -> Basis:
	var target_up = Vector3.UP
	if planet:
		target_up = planet.get_up(player_pos)
	
	current_up = current_up.slerp(target_up, delta * alignment_speed).normalized()
	gravity_direction = -current_up
	
	# Fallback basis aligned with current_up
	var arbitrary_fwd = Vector3.FORWARD
	if abs(current_up.dot(arbitrary_fwd)) > 0.95:
		arbitrary_fwd = Vector3.RIGHT
	var right = arbitrary_fwd.cross(current_up).normalized()
	var forward = current_up.cross(right).normalized()
	return Basis(right, current_up, -forward)
