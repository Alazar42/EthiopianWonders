class_name PathGenerator
extends Node3D

signal landmark_spawned(landmark: LandmarkData, target: LandmarkTarget)
signal planet_transition_ready(from_planet: SphericalPlanet, to_planet: SphericalPlanet)

@export var segment_scene: PackedScene
@export var target_scene: PackedScene
@export var planet_scene: PackedScene = preload("res://scenes/planets/spherical_planet.tscn")
@export var lookahead_segments: int = 6
@export var cleanup_distance_behind: float = 40.0
@export var lane_width: float = 2.2

# Active segment management
var active_segments: Array[PathSegment] = []
var active_planets: Array[SphericalPlanet] = []
var current_planet: SphericalPlanet = null

# Generation state
var current_frame: PathTypes.RouteFrame = PathTypes.RouteFrame.new()
var total_segments_generated: int = 0
var landmarks_spawned_count: int = 0
var segments_since_last_landmark: int = 0
var segments_since_last_transition: int = 0
var segments_since_last_turn: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Predefined planet themes
const PLANET_THEMES = [
	{
		"name": "Highland Savanna",
		"radius": 45.0,
		"terrain": Color(0.28, 0.52, 0.32),
		"accent": Color(0.68, 0.45, 0.25)
	},
	{
		"name": "Rift Valley",
		"radius": 48.0,
		"terrain": Color(0.72, 0.38, 0.22),
		"accent": Color(0.35, 0.28, 0.25)
	},
	{
		"name": "Simien Peaks",
		"radius": 50.0,
		"terrain": Color(0.32, 0.42, 0.45),
		"accent": Color(0.50, 0.60, 0.42)
	},
	{
		"name": "Golden Lalibela",
		"radius": 46.0,
		"terrain": Color(0.80, 0.58, 0.35),
		"accent": Color(0.58, 0.26, 0.20)
	}
]
var _theme_index: int = 0

func initialize_generator(initial_planet: SphericalPlanet, seed_val: int = 12345) -> void:
	rng.seed = seed_val
	current_planet = initial_planet
	active_planets.clear()
	if initial_planet and not active_planets.has(initial_planet):
		active_planets.append(initial_planet)
	
	# Start at top of the initial planet
	var start_pos = initial_planet.global_position + Vector3(0, initial_planet.radius, 0)
	var start_up = Vector3.UP
	var start_fwd = Vector3.FORWARD
	current_frame = PathTypes.RouteFrame.new(start_pos, start_fwd, start_up, 0.0)
	
	# Clear previous segments
	for seg in active_segments:
		if is_instance_valid(seg):
			seg.queue_free()
	active_segments.clear()
	
	total_segments_generated = 0
	landmarks_spawned_count = 0
	segments_since_last_landmark = 0
	segments_since_last_transition = 0
	segments_since_last_turn = 0
	
	# Initial seed sequence:
	# 1. Straight safe runway
	_generate_segment(PathTypes.SegmentType.STRAIGHT, 24.0)
	
	# 2. First introductory landmark (guaranteed discovery chance!)
	_generate_segment(PathTypes.SegmentType.LANDMARK_APPROACH, 32.0)
	
	# 3. Recovery straight
	_generate_segment(PathTypes.SegmentType.RECOVERY, 18.0)
	
	# Fill remaining lookahead
	while active_segments.size() < lookahead_segments:
		_generate_next_segment()

## Update generator based on player's current cumulative distance
func update_generation(player_distance: float) -> void:
	# 1. Check if we need more segments ahead
	var last_dist = current_frame.distance
	var iters = 0
	while (last_dist - player_distance) < (lookahead_segments * 20.0) and iters < 25:
		iters += 1
		_generate_next_segment()
		last_dist = current_frame.distance
	
	# 2. Check and clean up obsolete segments behind player
	_cleanup_old_segments(player_distance)

## Samples the route at any cumulative distance
func sample_route_at_distance(dist: float) -> PathTypes.RouteFrame:
	if active_segments.is_empty():
		return current_frame
	
	# If before the first segment, return first sample
	if dist <= active_segments[0].start_frame.distance:
		return active_segments[0].start_frame
	
	# Find segment containing dist
	for seg in active_segments:
		if dist >= seg.start_frame.distance and dist <= seg.end_frame.distance:
			return seg.get_frame_at_distance(dist)
	
	# If past the last generated segment, return current_frame
	return current_frame

## Check interaction deadlines for all active segments
func check_deadlines(player_distance: float) -> void:
	for seg in active_segments:
		if seg.landmark_target and is_instance_valid(seg.landmark_target):
			seg.landmark_target.check_deadline(player_distance)

func _generate_next_segment() -> void:
	total_segments_generated += 1
	segments_since_last_landmark += 1
	segments_since_last_transition += 1
	segments_since_last_turn += 1
	
	# Pacing logic:
	# Transition planet every 8-11 segments
	if segments_since_last_transition >= 9:
		_generate_planet_transition()
		segments_since_last_transition = 0
		segments_since_last_landmark = 0
		segments_since_last_turn = 0
		return
	
	# Spawn a landmark every 4-6 segments
	if segments_since_last_landmark >= 4:
		_generate_segment(PathTypes.SegmentType.LANDMARK_APPROACH, 32.0)
		segments_since_last_landmark = 0
		return
	
	# After landmark, generate recovery
	if segments_since_last_landmark == 1:
		_generate_segment(PathTypes.SegmentType.RECOVERY, 18.0)
		return
	
	# Sharp turns or curves
	if segments_since_last_turn >= 3:
		var roll = rng.randf()
		if roll < 0.35: # Sharp left turn
			_generate_segment(PathTypes.SegmentType.TURN_LEFT, 16.0)
			segments_since_last_turn = 0
			return
		elif roll < 0.70: # Sharp right turn
			_generate_segment(PathTypes.SegmentType.TURN_RIGHT, 16.0)
			segments_since_last_turn = 0
			return
		elif roll < 0.85: # Gentle curve left
			_generate_segment(PathTypes.SegmentType.CURVE_LEFT, 22.0)
			segments_since_last_turn = 0
			return
		else: # Gentle curve right
			_generate_segment(PathTypes.SegmentType.CURVE_RIGHT, 22.0)
			segments_since_last_turn = 0
			return
	
	# Default: Straight segment
	_generate_segment(PathTypes.SegmentType.STRAIGHT, rng.randf_range(16.0, 22.0))

func _generate_segment(type: PathTypes.SegmentType, length: float) -> void:
	var seg = segment_scene.instantiate() as PathSegment
	add_child(seg)
	
	var samples: Array[PathTypes.RouteFrame] = []
	match type:
		PathTypes.SegmentType.STRAIGHT, PathTypes.SegmentType.RECOVERY:
			samples = _build_straight_samples(current_frame, current_planet, length, 10)
		PathTypes.SegmentType.CURVE_LEFT:
			samples = _build_curved_samples(current_frame, current_planet, length, 0.32, 12)
		PathTypes.SegmentType.CURVE_RIGHT:
			samples = _build_curved_samples(current_frame, current_planet, length, -0.32, 12)
		PathTypes.SegmentType.TURN_LEFT:
			samples = _build_sharp_turn_samples(current_frame, current_planet, length, 1.0, 16)
		PathTypes.SegmentType.TURN_RIGHT:
			samples = _build_sharp_turn_samples(current_frame, current_planet, length, -1.0, 16)
		PathTypes.SegmentType.LANDMARK_APPROACH:
			samples = _build_straight_samples(current_frame, current_planet, length, 12)
		PathTypes.SegmentType.PLANET_ARRIVAL:
			samples = _build_straight_samples(current_frame, current_planet, length, 10)
	
	seg.setup_segment(type, samples, current_planet)
	active_segments.append(seg)
	current_frame = seg.end_frame.duplicate()
	
	# If landmark approach, attach landmark
	if type == PathTypes.SegmentType.LANDMARK_APPROACH:
		var lm_data = LandmarkCatalog.get_random_undiscovered(true)
		if lm_data:
			var deadline_dist = seg.start_frame.distance + length * 0.90
			seg.attach_landmark(target_scene, lm_data, deadline_dist)
			landmarks_spawned_count += 1
			if seg.landmark_target:
				landmark_spawned.emit(lm_data, seg.landmark_target)

func _generate_planet_transition() -> void:
	if not current_planet or not is_instance_valid(current_planet):
		return
	
	# 1. Pick next planet theme and spawn next planet
	_theme_index = (_theme_index + 1) % PLANET_THEMES.size()
	var theme = PLANET_THEMES[_theme_index]
	
	var next_planet = planet_scene.instantiate() as SphericalPlanet
	next_planet.name = "Planet_" + theme["name"]
	next_planet.planet_name = theme["name"]
	next_planet.radius = theme["radius"]
	next_planet.terrain_color = theme["terrain"]
	next_planet.accent_color = theme["accent"]
	
	var offset_dir = current_frame.forward.normalized()
	var target_planet_center = current_planet.global_position + offset_dir * (current_planet.radius + next_planet.radius + 35.0)
	
	var parent_node = get_parent()
	if parent_node:
		parent_node.add_child(next_planet)
	else:
		add_child(next_planet)
		
	next_planet.global_position = target_planet_center
	next_planet.apply_planet_settings()
	next_planet.generate_surface_decorations(rng.randi())
	active_planets.append(next_planet)
	
	# 2. Build transition curve connecting departure on current planet to arrival on next planet
	var departure_pos = current_frame.position
	var departure_fwd = current_frame.forward
	
	# Arrival on next planet: entry point on near surface facing into next planet
	var arrival_surface_dir = (departure_pos - target_planet_center).normalized()
	var arrival_pos = target_planet_center + arrival_surface_dir * next_planet.radius
	var arrival_up = PlanetaryGravity.get_up_direction(arrival_pos, target_planet_center)
	var arrival_fwd = (departure_fwd - arrival_up * departure_fwd.dot(arrival_up)).normalized()
	
	var seg = segment_scene.instantiate() as PathSegment
	add_child(seg)
	seg.is_transition = true
	seg.destination_planet = next_planet
	
	# Generate Bezier bridge samples across space
	var samples = _build_transition_bridge_samples(
		current_frame,
		arrival_pos,
		arrival_fwd,
		arrival_up,
		18
	)
	
	seg.setup_segment(PathTypes.SegmentType.PLANET_TRANSITION, samples, null)
	active_segments.append(seg)
	
	# Switch current planet to next planet
	var old_planet = current_planet
	current_planet = next_planet
	if seg.end_frame:
		current_frame = seg.end_frame.duplicate()
	elif not samples.is_empty():
		current_frame = samples[samples.size() - 1].duplicate()
	
	planet_transition_ready.emit(old_planet, next_planet)
	
	# Generate arrival recovery segment on new planet
	_generate_segment(PathTypes.SegmentType.PLANET_ARRIVAL, 20.0)

func _build_straight_samples(start_f: PathTypes.RouteFrame, planet: SphericalPlanet, length: float, steps: int) -> Array[PathTypes.RouteFrame]:
	var list: Array[PathTypes.RouteFrame] = []
	var center = planet.global_position if planet else Vector3.ZERO
	var r = planet.radius if planet else 45.0
	var p0 = start_f.position
	var f0 = start_f.forward
	var right0 = start_f.right
	# Great circle rotation axis
	var axis = -right0
	var total_angle = length / r
	
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var angle = total_angle * t
		var pt = center + (p0 - center).rotated(axis, angle)
		var up_t = (pt - center).normalized()
		var f_t = f0.rotated(axis, angle)
		var frame = PathTypes.RouteFrame.new(pt, f_t, up_t, start_f.distance + length * t)
		list.append(frame)
	return list

func _build_curved_samples(start_f: PathTypes.RouteFrame, planet: SphericalPlanet, length: float, total_yaw: float, steps: int) -> Array[PathTypes.RouteFrame]:
	var list: Array[PathTypes.RouteFrame] = []
	var center = planet.global_position if planet else Vector3.ZERO
	var r = planet.radius if planet else 45.0
	var cur_pos = start_f.position
	var cur_fwd = start_f.forward
	var cur_up = start_f.up
	var step_len = length / float(steps)
	var step_yaw = total_yaw / float(steps)
	
	list.append(start_f.duplicate())
	for i in range(1, steps + 1):
		# Turn forward around local up
		cur_fwd = cur_fwd.rotated(cur_up, step_yaw).normalized()
		var cur_right = cur_fwd.cross(cur_up).normalized()
		var axis = -cur_right
		var step_angle = step_len / r
		cur_pos = center + (cur_pos - center).rotated(axis, step_angle)
		cur_up = (cur_pos - center).normalized()
		# Re-project forward onto sphere tangent
		cur_fwd = (cur_fwd - cur_up * cur_fwd.dot(cur_up)).normalized()
		var frame = PathTypes.RouteFrame.new(cur_pos, cur_fwd, cur_up, start_f.distance + step_len * i)
		list.append(frame)
	return list

func _build_sharp_turn_samples(start_f: PathTypes.RouteFrame, planet: SphericalPlanet, length: float, turn_dir: float, steps: int) -> Array[PathTypes.RouteFrame]:
	var list: Array[PathTypes.RouteFrame] = []
	var center = planet.global_position if planet else Vector3.ZERO
	var r = planet.radius if planet else 45.0
	var cur_pos = start_f.position
	var cur_fwd = start_f.forward
	var cur_up = start_f.up
	var step_len = length / float(steps)
	var total_yaw = (PI / 2.0) * turn_dir
	
	list.append(start_f.duplicate())
	for i in range(1, steps + 1):
		var t = float(i) / float(steps)
		# Smoothstep derivative weight for easing into and out of turn
		var weight = 6.0 * t * (1.0 - t) / float(steps)
		var dyaw = total_yaw * weight
		cur_fwd = cur_fwd.rotated(cur_up, dyaw).normalized()
		var cur_right = cur_fwd.cross(cur_up).normalized()
		var axis = -cur_right
		var step_angle = step_len / r
		cur_pos = center + (cur_pos - center).rotated(axis, step_angle)
		cur_up = (cur_pos - center).normalized()
		cur_fwd = (cur_fwd - cur_up * cur_fwd.dot(cur_up)).normalized()
		var frame = PathTypes.RouteFrame.new(cur_pos, cur_fwd, cur_up, start_f.distance + step_len * i)
		list.append(frame)
	return list

func _build_transition_bridge_samples(
	start_f: PathTypes.RouteFrame,
	arr_pos: Vector3,
	arr_fwd: Vector3,
	arr_up: Vector3,
	steps: int
) -> Array[PathTypes.RouteFrame]:
	var list: Array[PathTypes.RouteFrame] = []
	var p0 = start_f.position
	var p3 = arr_pos
	var span = (p3 - p0).length()
	
	# Elevated Bezier control points forming a stylized orbital skyway arch
	var p1 = p0 + start_f.forward * (span * 0.4) + start_f.up * (span * 0.25)
	var p2 = p3 - arr_fwd * (span * 0.4) + arr_up * (span * 0.25)
	
	for i in range(steps + 1):
		var t = float(i) / float(steps)
		# Cubic Bezier formula
		var omt = 1.0 - t
		var pt = omt*omt*omt * p0 + 3.0*omt*omt*t * p1 + 3.0*omt*t*t * p2 + t*t*t * p3
		
		# Tangent (derivative)
		var tangent = 3.0*omt*omt * (p1 - p0) + 6.0*omt*t * (p2 - p1) + 3.0*t*t * (p3 - p2)
		var fwd = tangent.normalized()
		var up = start_f.up.slerp(arr_up, t).normalized()
		# Orthogonalize
		fwd = (fwd - up * fwd.dot(up)).normalized()
		
		var dist = start_f.distance + span * t
		var frame = PathTypes.RouteFrame.new(pt, fwd, up, dist)
		list.append(frame)
	return list

func _cleanup_old_segments(player_distance: float) -> void:
	var to_remove: Array[PathSegment] = []
	for seg in active_segments:
		if seg.end_frame.distance < (player_distance - cleanup_distance_behind):
			to_remove.append(seg)
	
	for seg in to_remove:
		active_segments.erase(seg)
		seg.queue_free()
	
	# Also clean up old planets that are far behind
	if active_planets.size() > 2:
		var oldest = active_planets[0]
		if oldest != current_planet and oldest.global_position.distance_to(current_frame.position) > 250.0:
			active_planets.remove_at(0)
			oldest.queue_free()
