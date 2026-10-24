class_name PlanetaryGravity
extends RefCounted
## Radial gravity math shared by the player and the tests.

## Outward surface normal: normalize(P - C).
static func up_at(point: Vector3, center: Vector3) -> Vector3:
	var diff: Vector3 = point - center
	if diff.length_squared() < 0.0001:
		return Vector3.UP
	return diff.normalized()

## Gravity points inward: -up.
static func gravity_at(point: Vector3, center: Vector3, strength: float) -> Vector3:
	return -up_at(point, center) * strength

static func height_above(point: Vector3, center: Vector3, radius: float) -> float:
	return point.distance_to(center) - radius

## Basis whose Y is `up` and whose -Z is `forward_hint` flattened onto the tangent plane.
static func surface_basis(up: Vector3, forward_hint: Vector3) -> Basis:
	var fwd: Vector3 = forward_hint - up * forward_hint.dot(up)
	if fwd.length_squared() < 0.0001:
		fwd = up.cross(Vector3.RIGHT)
		if fwd.length_squared() < 0.0001:
			fwd = up.cross(Vector3.FORWARD)
	fwd = fwd.normalized()
	return Basis(fwd.cross(up).normalized(), up, -fwd)
