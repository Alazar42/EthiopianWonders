class_name RouteGenerator
extends Node3D
## Endless, seeded route across a chain of planets. Keeps `ahead_distance` of route generated in
## front of the runner and frees everything far behind. The route is only data (RouteSegment);
## planets, wonders and targets are instances of authored scenes.

const T = RouteTypes.SegmentType

signal segment_entered(segment: RouteSegment)
signal target_spawned(target: LandmarkTarget)
signal planet_spawned(planet: PlanetController)
signal tank_spawned(tank: FuelTank)
signal crate_spawned(crate: AmmoCrate)

@export var start_planet: PlanetController
@export var planet_scenes: Array[PackedScene] = []
@export var target_scene: PackedScene
@export var gate_scene: PackedScene
@export var seed_value: int = 20260607
@export_group("Generation")
@export var ahead_distance: float = 170.0
@export var behind_distance: float = 60.0
@export_range(0.5, 1.5) var planet_arc_fraction: float = 0.95
@export var corridor_clearance: float = 9.0
@export_group("Landmarks")
@export var target_height: float = 3.4
@export var target_lateral: float = 5.0
@export var wonder_lateral: float = 17.0
@export var window_lead: float = 28.0
@export var deadline_after_target: float = 4.0
@export_group("Obstacles")
@export var obstacle_scenes: Array[PackedScene] = []
@export var obstacles_enabled: bool = true
@export var lane_width: float = 2.4
## Half width of the steering band; rocks are scattered across all of it.
@export var steer_band: float = 7.0
## Half width of a rock, used to measure the gaps between them.
@export var rock_half_width: float = 1.0
## Narrowest gap a row of rocks may leave (the ship is about 1.1 wide).
@export var passable_gap: float = 3.2
## Furthest the gap may move sideways from one row to the next.
@export var gap_reach: float = 5.0
## No obstacles before this route distance, so the tutorial planet stays calm.
@export var obstacle_min_start: float = 70.0
@export_group("Fuel")
@export var fuel_scene: PackedScene
@export var fuel_tanks_enabled: bool = true
## Route distance of the first gas tank.
@export var fuel_first_distance: float = 55.0
## Gap between gas tanks; it grows a little on every planet.
@export var fuel_spacing_min: float = 85.0
@export var fuel_spacing_max: float = 125.0
@export var fuel_spacing_growth: float = 6.0
@export var fuel_height: float = 3.0
@export_group("Ammo")
@export var ammo_scene: PackedScene
@export var ammo_crates_enabled: bool = true
## Ammo is meant to be scarce: crates are far apart, and further apart on later planets.
@export var ammo_first_distance: float = 120.0
@export var ammo_spacing_min: float = 150.0
@export var ammo_spacing_max: float = 200.0
@export var ammo_spacing_growth: float = 8.0
@export_group("Space traffic")
## Ethiopian stations and satellites drifting beside the flight path between planets.
@export var traffic_scenes: Array[PackedScene] = []
@export var traffic_min: int = 2
@export var traffic_max: int = 4
@export_group("Transitions")
@export var transition_clearance: float = 14.0
@export var transition_attempts: int = 32
## Distance between one planet and the next; long flights leave room for space traffic.
@export var transition_gap_min: float = 56.0
@export var transition_gap_max: float = 84.0
@export var transition_min_clearance: float = 6.0
@export var transition_max_retries: int = 4
@export_range(0.0, 90.0) var max_launch_yaw: float = 70.0

var rng := RandomNumberGenerator.new()
## Separate stream, so turning obstacles on or off never changes the route itself.
var _obstacle_rng := RandomNumberGenerator.new()
## Another separate stream for decoration, so space traffic never changes the route.
var _decor_rng := RandomNumberGenerator.new()
## Its own stream too, so gas tanks never change the route or the rocks.
var _fuel_rng := RandomNumberGenerator.new()
var _fuel_next: float = 0.0
var _ammo_rng := RandomNumberGenerator.new()
var _ammo_next: float = 0.0
var segments: Array[RouteSegment] = []
var planets: Array[PlanetController] = []
var targets: Array[LandmarkTarget] = []
var obstacles: Array[Obstacle] = []
var fuel_tanks: Array[FuelTank] = []
var ammo_crates: Array[AmmoCrate] = []
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
## Centre of the passable gap in the last row of rocks; above 1000 means none yet.
var _last_gap_center: float = 99999.0

# --- public API -------------------------------------------------------------------------------

## A negative seed uses `seed_value`, the fixed route tests rely on. Any other seed also turns the
## start planet to a random side and picks a random first wonder, so no two runs open the same way.
func begin_run(p_seed: int = -1) -> void:
	_clear()
	rng.seed = seed_value if p_seed < 0 else p_seed
	var first_wonder: String = "lalibela"
	if p_seed >= 0:
		start_planet.global_basis = Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var all: Array[LandmarkData] = LandmarkCatalog.get_all()
		first_wonder = all[rng.randi() % all.size()].id
	_obstacle_rng.seed = rng.seed + 777
	_decor_rng.seed = rng.seed + 4242
	_fuel_rng.seed = rng.seed + 1313
	_fuel_next = fuel_first_distance
	_ammo_rng.seed = rng.seed + 2626
	_ammo_next = ammo_first_distance
	_last_gap_center = 99999.0
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
	_append_surface(RouteTypes.SegmentType.LANDMARK_APPROACH, first_wonder)
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
	for tank in fuel_tanks:
		if is_instance_valid(tank):
			tank.disable()
	for crate in ammo_crates:
		if is_instance_valid(crate):
			crate.disable()

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
		options[T.TURN_LEFT] = 2.0 * bias_left
		options[T.TURN_RIGHT] = 2.0 * bias_right
	if planet_index >= 1 and remaining > 40.0 and absf(_yaw_total) < 1.8:
		options[T.SHARP_LEFT] = 1.7 * bias_left
		options[T.SHARP_RIGHT] = 1.7 * bias_right
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
	_spawn_obstacles(seg)
	_spawn_fuel(seg)
	_spawn_ammo(seg)
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
	_planet_budget = dest.radius * PI * planet_arc_fraction * rng.randf_range(0.7, 1.25)
	_yaw_total = 0.0
	_since_landmark = 1
	_last_type = RouteTypes.SegmentType.PLANET_TRANSITION
	_spawn_gate(seg, departure.position, departure.right, departure.up, departure.forward)
	_spawn_space_traffic(seg)
	_spawn_fuel(seg)
	_spawn_ammo(seg)
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
		var gap: float = rng.randf_range(transition_gap_min, transition_gap_max + 1.5 * float(attempt))
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

## Scatters stations and satellites beside a flight, never on the path and never inside a planet.
func _spawn_space_traffic(seg: RouteSegment) -> void:
	if traffic_scenes.is_empty():
		return
	var count: int = _decor_rng.randi_range(traffic_min, traffic_max)
	var frame := RouteFrame.new()
	var last_kind: int = -1
	for i in count:
		var along: float = seg.start_distance + seg.length * _decor_rng.randf_range(0.18, 0.82)
		seg.sample(along, frame)
		var side: float = 1.0 if _decor_rng.randf() < 0.5 else -1.0
		var pos: Vector3 = frame.position + frame.right * side * _decor_rng.randf_range(24.0, 42.0) \
			+ frame.up * _decor_rng.randf_range(-8.0, 14.0) + frame.forward * _decor_rng.randf_range(-8.0, 8.0)
		var clear: bool = true
		for planet in planets:
			if pos.distance_to(planet.global_position) < planet.radius + 16.0:
				clear = false
		if not clear:
			continue
		var kind: int = _decor_rng.randi() % traffic_scenes.size()
		if kind == last_kind and traffic_scenes.size() > 1:
			kind = (kind + 1) % traffic_scenes.size()
		last_kind = kind
		var craft := traffic_scenes[kind].instantiate() as Node3D
		add_child(craft)
		craft.global_position = pos
		craft.global_basis = Basis.from_euler(Vector3(_decor_rng.randf() * 0.6, _decor_rng.randf() * TAU, _decor_rng.randf() * 0.6)) \
			* Basis.from_scale(Vector3.ONE * _decor_rng.randf_range(0.8, 1.25))
		seg.props.append(craft)

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

## Gas tanks beside the route, spaced by route distance. A tank is never put on top of the wonder
## target of the same segment.
func _spawn_fuel(seg: RouteSegment) -> void:
	if not fuel_tanks_enabled or fuel_scene == null:
		return
	while _fuel_next < seg.end_distance() - 2.0:
		var at: float = maxf(_fuel_next, seg.start_distance + 2.0)
		if seg.target != null:
			var target_at: float = seg.start_distance + seg.length * 0.55
			if absf(at - target_at) < 9.0:
				at = target_at + 9.0
		if at >= seg.end_distance() - 2.0:
			break
		_place_tank(seg, at)
		_fuel_next = at + _fuel_rng.randf_range(fuel_spacing_min, fuel_spacing_max) \
				+ fuel_spacing_growth * float(mini(planet_index, 8))

## Ammo crates, spaced by route distance. A crate keeps clear of gas tanks and of the segment's
## wonder target.
func _spawn_ammo(seg: RouteSegment) -> void:
	if not ammo_crates_enabled or ammo_scene == null:
		return
	while _ammo_next < seg.end_distance() - 2.0:
		var at: float = maxf(_ammo_next, seg.start_distance + 2.0)
		if seg.target != null:
			var target_at: float = seg.start_distance + seg.length * 0.55
			if absf(at - target_at) < 9.0:
				at = target_at + 9.0
		for tank in fuel_tanks:
			if is_instance_valid(tank) and absf(tank.route_distance - at) < 10.0:
				at = tank.route_distance + 10.0
		if at >= seg.end_distance() - 2.0:
			break
		_place_crate(seg, at)
		_ammo_next = at + _ammo_rng.randf_range(ammo_spacing_min, ammo_spacing_max) \
				+ ammo_spacing_growth * float(mini(planet_index, 8))

func _place_crate(seg: RouteSegment, distance: float) -> void:
	var frame := RouteFrame.new()
	seg.sample(distance, frame)
	var offset: float = _ammo_rng.randf_range(-steer_band + 2.0, steer_band - 2.0)
	var crate := ammo_scene.instantiate() as AmmoCrate
	add_child(crate)
	crate.global_transform = frame.lane_transform(offset, fuel_height)
	crate.setup(distance, offset)
	seg.props.append(crate)
	ammo_crates.append(crate)
	crate_spawned.emit(crate)

func _place_tank(seg: RouteSegment, distance: float) -> void:
	var frame := RouteFrame.new()
	seg.sample(distance, frame)
	var offset: float = _fuel_rng.randf_range(-steer_band + 2.0, steer_band - 2.0)
	var tank := fuel_scene.instantiate() as FuelTank
	add_child(tank)
	tank.global_transform = frame.lane_transform(offset, fuel_height)
	tank.setup(distance, offset)
	seg.props.append(tank)
	fuel_tanks.append(tank)
	tank_spawned.emit(tank)

## Rocks scattered across the whole steering band. Every row of rocks leaves a gap wide enough to
## fly through, and that gap is never further from the previous row's gap than the ship can slide in
## the time between rows, so there is always a way through.
func _spawn_obstacles(seg: RouteSegment) -> void:
	if not obstacles_enabled or obstacle_scenes.is_empty() or seg.start_distance < obstacle_min_start:
		return
	if not seg.type in [T.STRAIGHT, T.CURVE_LEFT, T.CURVE_RIGHT, T.TURN_LEFT, T.TURN_RIGHT, T.SHARP_LEFT, T.SHARP_RIGHT]:
		return
	var spacing: float = maxf(8.5, 14.0 - 1.0 * float(planet_index))
	var distance: float = seg.start_distance + _obstacle_rng.randf_range(5.0, 8.0)
	while distance < seg.end_distance() - 4.0:
		var count: int = 1
		if _obstacle_rng.randf() < clampf(0.08 * float(planet_index), 0.0, 0.4):
			count = 2
		if planet_index >= 3 and _obstacle_rng.randf() < 0.15:
			count = 3
		var row: Array[float] = _make_row(count)
		for offset in row:
			_place_obstacle(seg, distance + _obstacle_rng.randf_range(-0.4, 0.4), offset)
		distance += spacing + _obstacle_rng.randf_range(-1.5, 3.0)

## Picks `count` rock offsets whose widest gap is passable and close to the previous row's gap.
func _make_row(count: int) -> Array[float]:
	var best: Array[float] = []
	for attempt in 12:
		var row: Array[float] = []
		for i in count:
			row.append(_obstacle_rng.randf_range(-steer_band + 0.6, steer_band - 0.6))
		row.sort()
		var gap: Vector2 = _widest_gap(row)
		if gap.y < passable_gap:
			continue
		if _last_gap_center > 1000.0 or absf(gap.x - _last_gap_center) <= gap_reach:
			_last_gap_center = gap.x
			return row
	# No random row worked: a single rock beside the previous gap is always fair.
	if _last_gap_center < 1000.0:
		best.append(clampf(_last_gap_center + (3.5 if _obstacle_rng.randf() < 0.5 else -3.5), -steer_band + 0.6, steer_band - 0.6))
	else:
		best.append(0.0)
	var fallback: Vector2 = _widest_gap(best)
	_last_gap_center = fallback.x
	return best

## Returns (centre, width) of the widest free span between rocks (and the band's edges).
func _widest_gap(row: Array[float]) -> Vector2:
	var edges: Array[float] = [-steer_band - 0.55]
	for offset in row:
		edges.append(offset - rock_half_width)
		edges.append(offset + rock_half_width)
	edges.append(steer_band + 0.55)
	var best := Vector2(0.0, -1.0)
	for i in range(0, edges.size(), 2):
		var width: float = edges[i + 1] - edges[i]
		if width > best.y:
			best = Vector2((edges[i] + edges[i + 1]) * 0.5, width)
	return best

func _place_obstacle(seg: RouteSegment, distance: float, offset: float) -> void:
	var scene: PackedScene = obstacle_scenes[_obstacle_rng.randi() % obstacle_scenes.size()]
	var obstacle := scene.instantiate() as Obstacle
	var frame := RouteFrame.new()
	seg.sample(distance, frame)
	add_child(obstacle)
	var xf: Transform3D = frame.lane_transform(offset, 0.0)
	xf.basis = xf.basis.rotated(xf.basis.y, _obstacle_rng.randf() * TAU)
	obstacle.global_transform = xf
	obstacle.setup(distance, offset)
	seg.props.append(obstacle)
	obstacles.append(obstacle)

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
	for i in range(obstacles.size() - 1, -1, -1):
		if not is_instance_valid(obstacles[i]) or obstacles[i].is_queued_for_deletion():
			obstacles.remove_at(i)
	for i in range(fuel_tanks.size() - 1, -1, -1):
		if not is_instance_valid(fuel_tanks[i]) or fuel_tanks[i].is_queued_for_deletion():
			fuel_tanks.remove_at(i)
	for i in range(ammo_crates.size() - 1, -1, -1):
		if not is_instance_valid(ammo_crates[i]) or ammo_crates[i].is_queued_for_deletion():
			ammo_crates.remove_at(i)
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
	obstacles.clear()
	fuel_tanks.clear()
	ammo_crates.clear()
	for planet in planets:
		if is_instance_valid(planet) and planet != start_planet:
			planet.queue_free()
	planets.clear()
	_bag.clear()
