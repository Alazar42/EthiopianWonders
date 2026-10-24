class_name PlanetaryGravity
extends RefCounted

## Utility math for spherical planetary gravity and coordinate frames

static func get_up_direction(point: Vector3, planet_center: Vector3) -> Vector3:
	var diff = point - planet_center
	if diff.length_squared() < 0.0001:
		return Vector3.UP
	return diff.normalized()

static func get_gravity_direction(point: Vector3, planet_center: Vector3) -> Vector3:
	return -get_up_direction(point, planet_center)

static func get_surface_position(point: Vector3, planet_center: Vector3, radius: float) -> Vector3:
	var up = get_up_direction(point, planet_center)
	return planet_center + up * radius

static func get_distance_to_surface(point: Vector3, planet_center: Vector3, radius: float) -> float:
	return (point - planet_center).length() - radius

## Aligns a basis so that its Y axis points along 'normal', while preserving forward direction
static func align_basis_to_normal(current_basis: Basis, normal: Vector3) -> Basis:
	var forward = -current_basis.z
	# Project forward onto the plane defined by normal
	var proj_forward = forward - normal * forward.dot(normal)
	if proj_forward.length_squared() < 0.001:
		# If forward is parallel to normal, choose right as fallback
		proj_forward = current_basis.x - normal * current_basis.x.dot(normal)
	proj_forward = proj_forward.normalized()
	
	var right = proj_forward.cross(normal).normalized()
	# In standard Godot coordinate system: X=right, Y=up(normal), Z=-forward
	return Basis(right, normal, -proj_forward).orthonormalized()
