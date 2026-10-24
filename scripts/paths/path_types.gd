class_name PathTypes
extends RefCounted

enum SegmentType {
	STRAIGHT,
	CURVE_LEFT,
	CURVE_RIGHT,
	TURN_LEFT,
	TURN_RIGHT,
	LANDMARK_APPROACH,
	PLANET_TRANSITION,
	PLANET_ARRIVAL,
	RECOVERY
}

class RouteFrame extends RefCounted:
	var position: Vector3 = Vector3.ZERO
	var forward: Vector3 = Vector3.FORWARD
	var up: Vector3 = Vector3.UP
	var right: Vector3 = Vector3.RIGHT
	var distance: float = 0.0
	
	func _init(p_pos: Vector3 = Vector3.ZERO, p_fwd: Vector3 = Vector3.FORWARD, p_up: Vector3 = Vector3.UP, p_dist: float = 0.0) -> void:
		position = p_pos
		up = p_up.normalized()
		if up.length_squared() < 0.001:
			up = Vector3.UP
		
		var proj_fwd = p_fwd - up * p_fwd.dot(up)
		if proj_fwd.length_squared() < 0.001:
			var fallback_axis = Vector3.FORWARD if abs(up.dot(Vector3.FORWARD)) < 0.85 else Vector3.RIGHT
			proj_fwd = (fallback_axis - up * fallback_axis.dot(up)).normalized()
		else:
			proj_fwd = proj_fwd.normalized()
		forward = proj_fwd
		
		right = forward.cross(up).normalized()
		if right.length_squared() < 0.001:
			var fallback_r = Vector3.RIGHT if abs(up.dot(Vector3.RIGHT)) < 0.85 else Vector3.FORWARD
			right = up.cross(fallback_r).normalized()
		distance = p_dist
	
	func get_basis() -> Basis:
		return Basis(right, up, -forward).orthonormalized()
	
	func get_lane_position(lane_offset: float, planet_center: Vector3 = Vector3.ZERO, planet_radius: float = 0.0) -> Vector3:
		if planet_radius > 0.0:
			var raw_pos = position + right * lane_offset
			var dir = (raw_pos - planet_center).normalized()
			return planet_center + dir * planet_radius
		return position + right * lane_offset
	
	func duplicate() -> RouteFrame:
		var rf = RouteFrame.new(position, forward, up, distance)
		rf.right = right
		return rf
