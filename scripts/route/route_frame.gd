class_name RouteFrame
extends RefCounted
## One point of the route: where the lane centerline is, which way is forward and which way is up.
## On a planet `radius` > 0 and lanes bend with the sphere; in flight `radius` is 0.

var position: Vector3 = Vector3.ZERO
var forward: Vector3 = Vector3.FORWARD
var up: Vector3 = Vector3.UP
var right: Vector3 = Vector3.RIGHT
var distance: float = 0.0
var center: Vector3 = Vector3.ZERO
var radius: float = 0.0
var planet: Node3D = null

func set_frame(p_position: Vector3, p_forward: Vector3, p_up: Vector3) -> void:
	position = p_position
	up = p_up.normalized()
	forward = (p_forward - up * p_forward.dot(up)).normalized()
	right = forward.cross(up).normalized()

func copy_from(other: RouteFrame) -> void:
	position = other.position
	forward = other.forward
	up = other.up
	right = other.right
	distance = other.distance
	center = other.center
	radius = other.radius
	planet = other.planet

func is_airborne() -> bool:
	return radius <= 0.0

## Transform of something standing `height` above the route at `lane_offset` to the right.
## On a planet the lateral move is a rotation about `forward`, so lanes follow the curvature
## and the local up always points away from the planet center.
func lane_transform(lane_offset: float, height: float = 0.0) -> Transform3D:
	if radius > 0.0:
		var lane_up: Vector3 = up.rotated(forward, lane_offset / radius)
		var lane_right: Vector3 = forward.cross(lane_up).normalized()
		return Transform3D(Basis(lane_right, lane_up, -forward), center + lane_up * (radius + height))
	return Transform3D(Basis(right, up, -forward), position + right * lane_offset + up * height)
