class_name RouteGenerator
extends Node3D
## Endless, seeded route across a chain of planets. Keeps `ahead_distance` of route generated in
## front of the runner and frees everything far behind. The route is only data (RouteSegment);
## planets, wonders and targets are instances of authored scenes.

const T = RouteTypes.SegmentType

signal segment_entered(segment: RouteSegment)
signal target_spawned(target: LandmarkTarget)
signal planet_spawned(planet: PlanetController)

@export var start_planet: PlanetController
@export var planet_scenes: Array[PackedScene] = []
@export var target_scene: PackedScene
@export var gate_scene: PackedScene
@export var seed_value: int = 20260607
@export_group("Generation")
@export var ahead_distance: float = 170.0
@export var behind_distance: float = 60.0
@export_range(0.5, 1.5) var planet_arc_fraction: float = 0.95
@export var corridor_clearance: float = 5.5
@export_group("Landmarks")
@export var target_height: float = 3.4
@export var target_lateral: float = 5.0
@export var wonder_lateral: float = 17.0
@export var window_lead: float = 28.0
@export var deadline_after_target: float = 4.0
@export_group("Transitions")
@export var transition_clearance: float = 14.0
@export var transition_attempts: int = 32
@export var transition_min_clearance: float = 6.0
@export var transition_max_retries: int = 4
@export_range(0.0, 90.0) var max_launch_yaw: float = 70.0

var rng := RandomNumberGenerator.new()
var segments: Array[RouteSegment] = []
var planets: Array[PlanetController] = []
var targets: Array[LandmarkTarget] = []
## End of the generated route.
var head := RouteFrame.new()
var head_planet: PlanetController
var planet_index: int = 0
## Smallest gap between the last flight and any other planet; negative means no clean spot was found.
var last_transition_clearance: float = INF

var _planet_used: float = 0.0
var _planet_budget: float = 0.0
var _yaw_total: float = 0.0
var _since_landmark: int = 0
var _last_type: RouteTypes.SegmentType = RouteTypes.SegmentType.STRAIGHT
var _cursor: int = 0
var _bag: Array[LandmarkData] = []
var _transition_retries: int = 0

# --- public API -------------------------------------------------------------------------------

func begin_run(p_seed: int = -1) -> void:
	_clear()
	rng.seed = seed_value if p_seed < 0 else p_seed
	planets.append(start_planet)
	head_planet = start_planet
	planet_index = 0
	_planet_used = 0.0
	_planet_budget = start_planet.radius * PI * planet_arc_fraction
	_yaw_total = 0.0
	_since_landmark = 0
	_last_type = RouteTypes.SegmentType.STRAIGHT
	_transition_retries = 0
	_cursor = 0
	head = RouteFrame.new()
	head.center = start_planet.global_position
	head.radius = start_planet.radius
	head.planet = start_planet
	head.set_frame(head.center + Vector3.UP * head.radius, Vector3.FORWARD, Vector3.UP)
	head.distance = 0.0
	# Tutorial opening: a straight run-in, one guaranteed discovery, then room to breathe.
	_append_surface(RouteTypes.SegmentType.STRAIGHT)
	_append_surface(RouteTypes.SegmentType.LANDMARK_APPROACH, "lalibela")
	_append_surface(RouteTypes.SegmentType.RECOVERY)
	update(0.0)

## Generates ahead of `route_distance` and frees what is far behind it.
func update(route_distance: float) -> void:
	var guard: int = 0
	while head.distance < route_distance + ahead_distance and guard < 64:
		guard += 1
		_append_next()
	_cleanup(route_distance)

## Fills `out` with the centerline frame at `route_distance`.
func sample(route_distance: float, out: RouteFrame) -> void:
	if segments.is_empty():
		return
	_cursor = clampi(_cursor, 0, segments.size() - 1)
	while _cursor < segments.size() - 1 and route_distance >= segments[_cursor].end_distance():
		_cursor += 1
		segment_entered.emit(segments[_cursor])
	while _cursor > 0 and route_distance < segments[_cursor].start_distance:
		_cursor -= 1
	segments[_cursor].sample(route_distance, out)

func current_segment() -> RouteSegment:
	if segments.is_empty():
		return null
	return segments[clampi(_cursor, 0, segments.size() - 1)]

func disable_targets() -> void:
	for target in targets:
		if is_instance_valid(target):
			target.disable()

# --- generation ---------------------------------------------------------------------------------

func _append_next() -> void:
	if _planet_used >= _planet_budget:
		_append_transition()
		return
	_append_surface(_choose_type())

func _choose_type() -> RouteTypes.SegmentType:
	var remaining: float = _planet_budget - _planet_used
	# Demanding sections and landmarks are always followed by a short recovery.
	if RouteTypes.is_turn(_last_type) or _last_type == T.LANDMARK_APPROACH:
		return T.RECOVERY
	if _since_landmark >= 3 and remaining > 58.0:
		return T.LANDMARK_APPROACH
	var options: Dictionary = {T.STRAIGHT: 4.0}
	var bias_left: float = 1.0
	var bias_right: float = 1.0
	if _yaw_total > 0.4:
		bias_left = 0.35
		bias_right = 1.7
	elif _yaw_total < -0.4:
		bias_left = 1.7
		bias_right = 0.35
	if remaining > 30.0:
		options[T.CURVE_LEFT] = 2.0 * bias_left
		options[T.CURVE_RIGHT] = 2.0 * bias_right
	# Sharper shapes are introduced gradually, planet by planet.
	if planet_index >= 1 and remaining > 40.0 and absf(_yaw_total) < 1.9:
		options[T.TURN_LEFT] = 1.5 * bias_left
		options[T.TURN_RIGHT] = 1.5 * bias_right
	if planet_index >= 2 and remaining > 40.0 and absf(_yaw_total) < 1.6:
		options[T.SHARP_LEFT] = 1.0 * bias_left
		options[T.SHARP_RIGHT] = 1.0 * bias_right
	return _weighted_pick(options)

func _weighted_pick(options: Dictionary) -> RouteTypes.SegmentType:
	var total: float = 0.0
	for weight in options.values():
		total += weight
	var roll: float = rng.randf() * total
	for type in options:
		roll -= options[type]
		if roll <= 0.0:
			return type
	return options.keys()[0]

func _append_surface(type: RouteTypes.SegmentType, forced_landmark: String = "") -> void:
	var length: float = 20.0
	var yaw: float = 0.0
	var eased: bool = false
	match type:
		T.STRAIGHT:
			length = rng.randf_range(16.0, 26.0) if _planet_used > 0.0 else 18.0
		T.CURVE_LEFT:
			length = 26.0; yaw = 0.6; eased = true
		T.CURVE_RIGHT:
			length = 26.0; yaw = -0.6; eased = true
		T.TURN_LEFT:
			length = 20.0; yaw = 1.05; eased = true
		T.TURN_RIGHT:
			length = 20.0; yaw = -1.05; eased = true
		T.SHARP_LEFT:
			length = 13.0; yaw = PI * 0.5; eased = true
		T.SHARP_RIGHT:
			length = 13.0; yaw = -PI * 0.5; eased = true
		T.LANDMARK_APPROACH:
			length = 36.0
		T.RECOVERY:
			length = 12.0
		T.PLANET_ARRIVAL:
			length = 14.0
	var seg: RouteSegment = RouteSegment.build_surface(type, head, length, yaw, eased)
	_register(seg)
	_planet_used += seg.length
	_yaw_total += yaw
	if type == T.LANDMARK_APPROACH:
		_since_landmark = 0
		_spawn_landmark(seg, forced_landmark)
	elif type != T.PLANET_ARRIVAL:
		_since_landmark += 1
	_last_type = type
	if seg.planet:
		(seg.planet as PlanetController).clear_decorations_near(seg.positions, corridor_clearance)

func _register(seg: RouteSegment) -> void:
	segments.append(seg)
	var center: Vector3 = head.center
	var radius: float = head.radius
	var planet: Node3D = head.planet
	seg.sample(seg.end_distance(), head)
	# Airborne segments carry no planet; keep the head on the planet we are heading for.
	if seg.radius <= 0.0:
		head.center = center
		head.radius = radius
		head.planet = planet

func _append_transition() -> void:
	var from_planet: PlanetController = head_planet
	var dest: PlanetController = _pick_planet_scene(from_planet).instantiate() as PlanetController
	var plan: Dictionary = _plan_transition(dest, from_planet)
	last_transition_clearance = plan["clearance"]
	if plan["clearance"] < transition_min_clearance and _transition_retries < transition_max_retries:
		# Crowded ahead: run a little further around this planet, then look again.
		dest.free()
		_transition_retries += 1
		_append_surface(RouteTypes.SegmentType.CURVE_LEFT if _yaw_total < 0.0 else RouteTypes.SegmentType.CURVE_RIGHT)
		return
	_transition_retries = 0
	add_child(dest)
	dest.global_position = plan["center"]
	dest.global_basis = Basis(Vector3.UP, rng.randf() * TAU)
	planets.append(dest)
	planet_spawned.emit(dest)

	var departure := RouteFrame.new()
	departure.copy_from(head)
	var seg: RouteSegment = RouteSegment.build_transition(
		head, plan["landing"], plan["up"], plan["forward"], plan["lift"],
		dest, dest.global_position, dest.radius)
	_register(seg)
	head.center = dest.global_position
	head.radius = dest.radius
	head.planet = dest
	head_planet = dest
	planet_index += 1
	_planet_used = 0.0
	_planet_budget = dest.radius * PI * planet_arc_fraction
	_yaw_total = 0.0
	_since_landmark = 1
	_last_type = RouteTypes.SegmentType.PLANET_TRANSITION
	_spawn_gate(seg, departure.position, departure.right, departure.up, departure.forward)
	_spawn_gate(seg, head.position, head.right, head.up, head.forward)
	dest.clear_decorations_near(PackedVector3Array([head.position]), 14.0)
	_append_surface(RouteTypes.SegmentType.PLANET_ARRIVAL)

## Looks for a landing that keeps the new planet and the flight arc clear of every other planet.
## Varies the launch heading, tilt, gap and lift; returns the best candidate found.
func _plan_transition(dest: PlanetController, from_planet: PlanetController) -> Dictionary:
	var best_clearance: float = -INF
	var best: Dictionary = {}
	for attempt in transition_attempts:
		var yaw: float = rng.randf_range(-deg_to_rad(max_launch_yaw), deg_to_rad(max_launch_yaw))
		var phi: float = deg_to_rad(rng.randf_range(38.0, 62.0))
		var gap: float = rng.randf_range(26.0, 34.0 + float(attempt))
		var lift: float = rng.randf_range(0.0, 3.0)
		var launch_forward: Vector3 = head.forward.rotated(head.up, yaw)
		var launch_right: Vector3 = launch_forward.cross(head.up)
		var landing: Vector3 = head.position + launch_forward * gap + head.up * lift
		var landing_up: Vector3 = head.up.rotated(launch_right, phi)
		var landing_forward: Vector3 = launch_forward.rotated(launch_right, phi)
		var dest_center: Vector3 = landing - landing_up * dest.radius
		var arc: PackedVector3Array = RouteSegment.transition_curve(
			head, landing, landing_up, landing_forward, lift, 12)
		var clearance: float = INF
		for other in planets:
			# The new planet must not overlap an old one...
			clearance = minf(clearance,
				dest_center.distance_to(other.global_position) - other.radius - dest.radius)
			# ...and the flight must not skim past any planet other than the one it leaves.
			if other != from_planet:
				for point in arc:
					clearance = minf(clearance, point.distance_to(other.global_position) - other.radius)
		if clearance > best_clearance:
			best_clearance = clearance
			best = {
				"landing": landing, "up": landing_up, "forward": landing_forward,
				"center": dest_center, "lift": lift, "clearance": clearance,
			}
		if clearance >= transition_clearance:
			break
	return best

func _pick_planet_scene(avoid: PlanetController) -> PackedScene:
	var candidates: Array[PackedScene] = []
	for scene in planet_scenes:
		if avoid == null or scene.resource_path != avoid.scene_file_path:
			candidates.append(scene)
	if candidates.is_empty():
		candidates = planet_scenes
	return candidates[rng.randi() % candidates.size()]

func _spawn_gate(seg: RouteSegment, pos: Vector3, right: Vector3, up: Vector3, forward: Vector3) -> void:
	if gate_scene == null:
		return
	var gate := gate_scene.instantiate() as Node3D
	add_child(gate)
	gate.global_transform = Transform3D(Basis(right, up, -forward), pos)
	seg.props.append(gate)

func _next_landmark(forced_id: String) -> LandmarkData:
	if not forced_id.is_empty():
		return LandmarkCatalog.get_by_id(forced_id)
	if _bag.is_empty():
		_bag.assign(LandmarkCatalog.get_all())
		for i in range(_bag.size() - 1, 0, -1):
			var j: int = rng.randi() % (i + 1)
			var swap: LandmarkData = _bag[i]
			_bag[i] = _bag[j]
			_bag[j] = swap
	return _bag.pop_back()

func _spawn_landmark(seg: RouteSegment, forced_id: String) -> void:
	var data: LandmarkData = _next_landmark(forced_id)
	if data == null:
		return
	var side: float = 1.0 if rng.randf() < 0.5 else -1.0
	var mid_distance: float = seg.start_distance + seg.length * 0.55
	var mid := RouteFrame.new()
	seg.sample(mid_distance, mid)
	var planet := seg.planet as PlanetController

	var wonder_scene: PackedScene = data.load_scene()
	if wonder_scene:
		var wonder := wonder_scene.instantiate() as Node3D
		add_child(wonder)
		var wonder_xf: Transform3D = mid.lane_transform(side * wonder_lateral, 0.0)
		# Face the road: local +Z toward the route.
		wonder_xf.basis = wonder_xf.basis.rotated(wonder_xf.basis.y, -side * PI * 0.5)
		wonder.global_transform = wonder_xf
		seg.props.append(wonder)
		if planet:
			planet.clear_decorations_near(PackedVector3Array([wonder_xf.origin]), 13.0)

	if target_scene:
		var target := target_scene.instantiate() as LandmarkTarget
		add_child(target)
		target.global_transform = mid.lane_transform(side * target_lateral, target_height)
		target.setup(data, mid_distance - window_lead, mid_distance + deadline_after_target)
		seg.props.append(target)
		seg.target = target
		targets.append(target)
		if planet:
			planet.clear_decorations_near(PackedVector3Array([target.global_position]), 4.0)
		target_spawned.emit(target)

# --- cleanup ------------------------------------------------------------------------------------

func _cleanup(route_distance: float) -> void:
	var removed: int = 0
	while segments.size() > 1 and segments[0].end_distance() < route_distance - behind_distance:
		segments[0].free_props()
		segments.remove_at(0)
		removed += 1
	_cursor = maxi(0, _cursor - removed)
	for i in range(targets.size() - 1, -1, -1):
		if not is_instance_valid(targets[i]) or targets[i].is_queued_for_deletion():
			targets.remove_at(i)
	for i in range(planets.size() - 1, -1, -1):
		var planet: PlanetController = planets[i]
		# The start planet stays alive so an in-place restart can reuse it.
		if planet == head_planet or planet == start_planet:
			continue
		var in_use: bool = false
		for seg in segments:
			if seg.planet == planet or seg.destination_planet == planet:
				in_use = true
				break
		if not in_use:
			planets.remove_at(i)
			planet.queue_free()

func _clear() -> void:
	for seg in segments:
		seg.free_props()
	segments.clear()
	targets.clear()
	for planet in planets:
		if is_instance_valid(planet) and planet != start_planet:
			planet.queue_free()
	planets.clear()
	_bag.clear()
