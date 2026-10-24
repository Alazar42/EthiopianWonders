class_name RouteSegment
extends RefCounted
## A stretch of route stored as evenly spaced samples. Pure data: nothing is rendered for it,
## the planet itself is the track.

var type: RouteTypes.SegmentType = RouteTypes.SegmentType.STRAIGHT
var start_distance: float = 0.0
var length: float = 0.0
var planet: Node3D = null
var center: Vector3 = Vector3.ZERO
var radius: float = 0.0

var positions: PackedVector3Array = PackedVector3Array()
var forwards: PackedVector3Array = PackedVector3Array()
var ups: PackedVector3Array = PackedVector3Array()

## Nodes created for this segment (wonder scenery, targets, launch rings); freed with it.
var props: Array[Node] = []
var target: LandmarkTarget = null
var destination_planet: Node3D = null

func end_distance() -> float:
	return start_distance + length

func contains(distance: float) -> bool:
	return distance >= start_distance and distance < start_distance + length

## Fills `out` with the frame at an absolute route distance.
func sample(distance: float, out: RouteFrame) -> void:
	var local: float = clampf(distance - start_distance, 0.0, length)
	var f: float = local / RouteTypes.SAMPLE_STEP
	var i: int = mini(int(f), positions.size() - 2)
	var t: float = clampf(f - float(i), 0.0, 1.0)
	var pos: Vector3 = positions[i].lerp(positions[i + 1], t)
	var up: Vector3 = ups[i].lerp(ups[i + 1], t).normalized()
	var fwd: Vector3 = forwards[i].lerp(forwards[i + 1], t)
	out.center = center
	out.radius = radius
	out.planet = planet
	if radius > 0.0:
		pos = center + (pos - center).normalized() * radius
		up = (pos - center).normalized()
	out.set_frame(pos, fwd, up)
	out.distance = start_distance + local

func free_props() -> void:
	for node in props:
		if is_instance_valid(node):
			node.queue_free()
	props.clear()
	target = null

# --- builders -------------------------------------------------------------------------------

## Walks along the planet surface, turning by `total_yaw` radians (positive = left) while moving
## `p_length` units. The frame is carried along the great circle (parallel transport), so the
## lane frame never flips no matter how far around the sphere the route goes.
static func build_surface(
		p_type: RouteTypes.SegmentType, start: RouteFrame, p_length: float,
		total_yaw: float, eased: bool) -> RouteSegment:
	var seg := RouteSegment.new()
	seg.type = p_type
	seg.start_distance = start.distance
	seg.planet = start.planet
	seg.center = start.center
	seg.radius = start.radius
	var steps: int = maxi(1, ceili(p_length / RouteTypes.SAMPLE_STEP))
	seg.length = float(steps) * RouteTypes.SAMPLE_STEP
	var up: Vector3 = start.up
	var fwd: Vector3 = start.forward
	seg.positions.push_back(seg.center + up * seg.radius)
	seg.forwards.push_back(fwd)
	seg.ups.push_back(up)
	var previous_ease: float = 0.0
	for i in range(1, steps + 1):
		var weight: float = 1.0 / float(steps)
		if eased:
			var t: float = float(i) / float(steps)
			var e: float = t * t * (3.0 - 2.0 * t)
			weight = e - previous_ease
			previous_ease = e
		fwd = fwd.rotated(up, total_yaw * weight)
		var axis: Vector3 = up.cross(fwd).normalized()
		var angle: float = RouteTypes.SAMPLE_STEP / seg.radius
		up = up.rotated(axis, angle).normalized()
		fwd = fwd.rotated(axis, angle)
		fwd = (fwd - up * fwd.dot(up)).normalized()
		seg.positions.push_back(seg.center + up * seg.radius)
		seg.forwards.push_back(fwd)
		seg.ups.push_back(up)
	return seg

## Control points of the flight arc: lifts off along the route, arrives from above the landing.
static func transition_curve(
		start: RouteFrame, landing: Vector3, landing_up: Vector3, landing_forward: Vector3,
		lift: float, count: int) -> PackedVector3Array:
	var p0: Vector3 = start.position
	var span: float = p0.distance_to(landing)
	var p1: Vector3 = p0 + start.forward * span * 0.35 + start.up * (lift + span * 0.2)
	var p2: Vector3 = landing + landing_up * (lift * 0.6 + span * 0.12) - landing_forward * span * 0.3
	var points := PackedVector3Array()
	for i in range(count + 1):
		var t: float = float(i) / float(count)
		var omt: float = 1.0 - t
		points.push_back(omt * omt * omt * p0 + 3.0 * omt * omt * t * p1 				+ 3.0 * omt * t * t * p2 + t * t * t * landing)
	return points

## Airborne hop between two planets. The runner's up vector is a gravity blend: the outward
## directions of both planets, weighted by how close each surface is. The nearer planet always
## dominates, so the runner is never upside down relative to the ground it is about to touch, and
## the blend ends exactly on the landing normal.
static func build_transition(
		start: RouteFrame, landing: Vector3, landing_up: Vector3, landing_forward: Vector3,
		lift: float, destination: Node3D, dest_center: Vector3, dest_radius: float) -> RouteSegment:
	var seg := RouteSegment.new()
	seg.type = RouteTypes.SegmentType.PLANET_TRANSITION
	seg.start_distance = start.distance
	seg.destination_planet = destination
	# Dense curve first, then resample at even arc length.
	var dense: int = 64
	var dp: PackedVector3Array = transition_curve(start, landing, landing_up, landing_forward, lift, dense)
	var dl := PackedFloat32Array()
	var total: float = 0.0
	for i in range(dp.size()):
		if i > 0:
			total += dp[i].distance_to(dp[i - 1])
		dl.push_back(total)
	var steps: int = maxi(2, ceili(total / RouteTypes.SAMPLE_STEP))
	seg.length = float(steps) * RouteTypes.SAMPLE_STEP
	var cursor: int = 0
	for s in range(steps + 1):
		var target_len: float = total * float(s) / float(steps)
		while cursor < dense - 1 and dl[cursor + 1] < target_len:
			cursor += 1
		var span_len: float = maxf(dl[cursor + 1] - dl[cursor], 0.0001)
		var k: float = clampf((target_len - dl[cursor]) / span_len, 0.0, 1.0)
		var pos: Vector3 = dp[cursor].lerp(dp[cursor + 1], k)
		var radial_a: Vector3 = pos - start.center
		var radial_b: Vector3 = pos - dest_center
		var weight_a: float = 1.0 / pow(maxf(radial_a.length() - start.radius, 0.0) + 2.0, 2.0)
		var weight_b: float = 1.0 / pow(maxf(radial_b.length() - dest_radius, 0.0) + 2.0, 2.0)
		seg.positions.push_back(pos)
		seg.ups.push_back((radial_a.normalized() * weight_a + radial_b.normalized() * weight_b).normalized())
		# Heading follows the flight path; sample() flattens it onto the plane perpendicular to up.
		seg.forwards.push_back((dp[cursor + 1] - dp[cursor]).normalized())
	seg.ups[0] = start.up
	seg.forwards[0] = start.forward
	# The authored landing pose is exact.
	seg.positions[steps] = landing
	seg.ups[steps] = landing_up
	seg.forwards[steps] = landing_forward
	return seg
