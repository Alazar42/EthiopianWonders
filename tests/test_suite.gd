extends SceneTree
## Headless gameplay tests. Run from the project folder:
##   godot --headless --path . --script res://tests/test_suite.gd
## Exits with the number of failed checks.

const DT: float = 1.0 / 60.0
const MENU_SCENE: String = "res://scenes/menus/main_menu.tscn"
const WORLD_SCENE: String = "res://scenes/game/game_world.tscn"

var _passed: int = 0
var _failed: int = 0

func _initialize() -> void:
	_run()

func check(label: String, condition: bool, detail: String = "") -> void:
	if condition:
		_passed += 1
		print("  ok    ", label)
	else:
		_failed += 1
		print("  FAIL  ", label, "  ", detail)

func _run() -> void:
	await process_frame
	await _test_menu_and_loading()
	await _test_movement_basics()
	await _test_lane_frame_over_long_run()
	_test_sharp_turn_geometry()
	await _test_generation_and_cleanup()
	await _test_planet_transitions()
	await _test_clicking()
	await _test_input_pipeline()
	await _test_lasers()
	await _test_missing_and_game_over()
	await _test_restart_and_popup()
	await _test_worlds_and_backdrop()
	_test_resources_load()
	await _test_return_to_menu()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(_failed)

# --- helpers -------------------------------------------------------------------------------------------

func _new_world() -> GameManager:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate() as GameManager
	root.add_child(world)
	world.set_process(false) # tests drive tick() themselves
	await process_frame
	return world

func _free_world(world: GameManager) -> void:
	world.queue_free()
	await process_frame

## Ticks the game; with `autoclick` every open target is discovered so the run survives.
func _step(world: GameManager, seconds: float, autoclick: bool = true) -> void:
	for i in int(seconds / DT):
		world.tick(DT)
		if autoclick:
			for target in world.route.targets:
				if is_instance_valid(target) and target.is_active():
					target.attempt_interact(world.player.distance)
		if not world.is_playing():
			return

func _radial_height(world: GameManager) -> float:
	var frame: RouteFrame = world.player.frame
	return world.player.global_position.distance_to(frame.center) - frame.radius

# --- tests ---------------------------------------------------------------------------------------------

func _test_menu_and_loading() -> void:
	print("menu and loading")
	check("project launches into the main menu",
		ProjectSettings.get_setting("application/run/main_scene") == MENU_SCENE)
	var menu := (load(MENU_SCENE) as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	check("main menu has Play and Quit buttons",
		menu.get_node("%PlayButton") is Button and menu.get_node("%QuitButton") is Button)
	check("Play points at a loadable gameplay scene",
		ResourceLoader.exists(menu.game_scene) and (load(menu.game_scene) as PackedScene).instantiate() is GameManager)
	menu.queue_free()
	await process_frame

func _test_movement_basics() -> void:
	print("start, gravity, running and lanes")
	var world := await _new_world()
	var player := world.player
	var start_planet: PlanetController = world.get_node("StartPlanet")
	check("run starts in RUNNING", world.state == GameState.State.RUNNING)
	check("player starts on the first planet's top",
		player.global_position.distance_to(start_planet.global_position + Vector3.UP * (start_planet.radius + player.body_height + player.spawn_drop)) < 0.05,
		str(player.global_position))
	var ship_length: float = (player.get_node("Visuals/Ship") as MeshInstance3D).get_aabb().size.z
	check("planet is much larger than the ship", start_planet.radius >= 35.0 and start_planet.radius > ship_length * 15.0,
		"radius %f, ship %f" % [start_planet.radius, ship_length])
	var before_distance: float = player.distance
	_step(world, 1.0)
	check("gravity brings the player to the surface", player.gravity.is_grounded() and absf(_radial_height(world) - player.body_height) < 0.01,
		"height above surface %f" % _radial_height(world))
	check("player runs forward automatically", player.distance > before_distance + player.run_speed * 0.9)
	var radial: Vector3 = (player.global_position - start_planet.global_position).normalized()
	check("player up equals the local surface normal", player.get_up().dot(radial) > 0.9999)
	check("player keeps feet toward the planet center", player.get_up().dot(radial) > 0.0 and (-player.global_basis.y).dot(-radial) > 0.99)

	var start_offset: float = player.lane.offset
	var ev := InputEventAction.new()
	ev.action = "move_right"
	ev.pressed = true
	player._unhandled_input(ev)
	check("right input selects the right lane", player.lane.target_lane == 1)
	check("lane change is smooth, not a teleport", is_equal_approx(player.lane.offset, start_offset))
	_step(world, 0.5)
	var lateral: float = (player.global_position - player.center_transform().origin).dot(player.frame.right)
	check("player moved right along the surface", lateral > player.lane_width * 0.9, "lateral %f" % lateral)
	ev.action = "move_right"
	player._unhandled_input(ev)
	player._unhandled_input(ev)
	check("lanes clamp at the right edge", player.lane.target_lane == 1)
	ev.action = "move_left"
	for i in 5:
		player._unhandled_input(ev)
	check("lanes clamp at the left edge", player.lane.target_lane == -1)
	_step(world, 0.5)
	check("outer lane offset never exceeds one lane width", absf(player.lane.offset) <= player.lane_width + 0.001)

	var camera_before: Transform3D = world.gameplay_camera.global_transform
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(400, 300)
	motion.position = Vector2(500, 300)
	Input.parse_input_event(motion)
	await process_frame
	var cam_to_player: float = world.gameplay_camera.global_position.distance_to(player.global_position)
	check("camera sits behind and above the player",
		cam_to_player > 6.0 and cam_to_player < 11.0, "distance %f" % cam_to_player)
	var behind: float = (world.gameplay_camera.global_position - player.global_position).dot(-player.get_forward())
	check("camera is behind the player", behind > 4.0, "behind %f" % behind)
	check("mouse motion does not rotate the camera",
		world.gameplay_camera.global_basis.get_euler().distance_to(camera_before.basis.get_euler()) < 0.5)
	await _free_world(world)

func _test_lane_frame_over_long_run() -> void:
	print("lane frame stability across curves")
	var world := await _new_world()
	var player := world.player
	var prev_right: Vector3 = player.frame.right
	var prev_up: Vector3 = player.frame.up
	var worst_right_step: float = 0.0
	var worst_up_step: float = 0.0
	var worst_orthogonality: float = 0.0
	var worst_height_error: float = 0.0
	var turned: bool = false
	var start_forward: Vector3 = player.frame.forward
	for i in int(40.0 / DT):
		world.tick(DT)
		for target in world.route.targets:
			if is_instance_valid(target) and target.is_active():
				target.attempt_interact(player.distance)
		var frame: RouteFrame = player.frame
		worst_right_step = maxf(worst_right_step, prev_right.angle_to(frame.right))
		worst_up_step = maxf(worst_up_step, prev_up.angle_to(frame.up))
		worst_orthogonality = maxf(worst_orthogonality, absf(frame.right.dot(frame.up)) + absf(frame.forward.dot(frame.up)))
		if not frame.is_airborne() and player.gravity.is_grounded():
			worst_height_error = maxf(worst_height_error, absf(_radial_height(world) - player.body_height))
		if frame.forward.angle_to(start_forward) > 0.3:
			turned = true
		prev_right = frame.right
		prev_up = frame.up
	check("lane right axis never jumps between frames", worst_right_step < 0.1, "worst %f rad" % worst_right_step)
	check("up axis never jumps between frames", worst_up_step < 0.1, "worst %f rad" % worst_up_step)
	check("frame stays orthonormal", worst_orthogonality < 0.001, "worst %f" % worst_orthogonality)
	check("player stays on the surface while running", worst_height_error < 0.02, "worst %f" % worst_height_error)
	check("route direction changes over a long run", turned)
	await _free_world(world)

func _test_sharp_turn_geometry() -> void:
	print("sharp turn changes the real route direction")
	var start := RouteFrame.new()
	start.center = Vector3(10, 20, 30)
	start.radius = 40.0
	start.set_frame(start.center + Vector3.UP * 40.0, Vector3.FORWARD, Vector3.UP)
	var straight := RouteSegment.build_surface(RouteTypes.SegmentType.STRAIGHT, start, 13.0, 0.0, false)
	var sharp := RouteSegment.build_surface(RouteTypes.SegmentType.SHARP_LEFT, start, 13.0, PI * 0.5, true)
	var straight_end := RouteFrame.new()
	var sharp_end := RouteFrame.new()
	straight.sample(straight.end_distance(), straight_end)
	sharp.sample(sharp.end_distance(), sharp_end)
	var turn_angle: float = rad_to_deg(straight_end.forward.angle_to(sharp_end.forward))
	check("sharp-left turns the heading by about 90 degrees", absf(turn_angle - 90.0) < 4.0, "%f deg" % turn_angle)
	var sign_check: float = straight_end.forward.cross(sharp_end.forward).dot(sharp_end.up)
	check("sharp-left turns to the left", sign_check > 0.0)
	var mid := RouteFrame.new()
	sharp.sample(sharp.start_distance + 6.5, mid)
	check("sharp turn stays on the sphere", absf(mid.position.distance_to(start.center) - 40.0) < 0.001)
	var lane_in := sharp_end.lane_transform(2.4, 0.9).origin
	check("outer lane follows the turn on the sphere", absf(lane_in.distance_to(start.center) - 40.9) < 0.001)

func _test_generation_and_cleanup() -> void:
	print("generation ahead and cleanup behind")
	var world := await _new_world()
	var route := world.route
	check("route is generated before the player needs it",
		route.head.distance - world.player.distance >= route.ahead_distance)
	var min_ahead: float = INF
	var max_segments: int = 0
	var max_children: int = 0
	for i in int(90.0 / DT):
		world.tick(DT)
		for target in route.targets:
			if is_instance_valid(target) and target.is_active():
				target.attempt_interact(world.player.distance)
		min_ahead = minf(min_ahead, route.head.distance - world.player.distance)
		max_segments = maxi(max_segments, route.segments.size())
		if i % 60 == 0:
			await process_frame
			max_children = maxi(max_children, route.get_child_count())
	check("player never reaches the end of the generated route", min_ahead > route.ahead_distance * 0.8,
		"min ahead %f" % min_ahead)
	check("old segments are removed", route.segments[0].end_distance() >= world.player.distance - route.behind_distance - 0.01,
		"first segment ends %f, player %f" % [route.segments[0].end_distance(), world.player.distance])
	check("active segment count stays bounded", max_segments < 24, "max %d" % max_segments)
	check("route nodes stay bounded", max_children < 40, "max children %d" % max_children)
	check("a second planet was generated", route.planet_index >= 1, "planet index %d" % route.planet_index)
	await _free_world(world)

func _test_planet_transitions() -> void:
	print("planet transitions")
	var world := await _new_world()
	var player := world.player
	var route := world.route
	var min_alignment: float = 1.0
	var flights: int = 0
	var landed_checks: int = 0
	var landing_ok: bool = true
	var was_airborne: bool = false
	var departure_up := Vector3.UP
	var flight_up_steps: float = 0.0
	var prev_up: Vector3 = player.get_up()
	var seen_types: Dictionary = {}
	var sharp_turns: Array[float] = []
	route.segment_entered.connect(func(seg: RouteSegment) -> void:
		seen_types[seg.type] = true
		if seg.type == RouteTypes.SegmentType.SHARP_LEFT or seg.type == RouteTypes.SegmentType.SHARP_RIGHT:
			var a := RouteFrame.new()
			var b := RouteFrame.new()
			seg.sample(seg.start_distance, a)
			seg.sample(seg.end_distance(), b)
			# Compare against the same stretch driven straight, so the sphere's own curvature cancels out.
			var straight := RouteSegment.build_surface(RouteTypes.SegmentType.STRAIGHT, a, seg.length, 0.0, false)
			var c := RouteFrame.new()
			straight.sample(straight.end_distance(), c)
			sharp_turns.append(rad_to_deg(c.forward.angle_to(b.forward))))
	var clearances: Array[float] = []
	route.planet_spawned.connect(func(_p: PlanetController) -> void: clearances.append(route.last_transition_clearance))
	for i in int(150.0 / DT):
		world.tick(DT)
		for target in route.targets:
			if is_instance_valid(target) and target.is_active():
				target.attempt_interact(player.distance)
		var frame: RouteFrame = player.frame
		if frame.is_airborne():
			if not was_airborne:
				flights += 1
				departure_up = player.get_up()
			was_airborne = true
			# While flying the runner must be feet-first toward the nearest planet.
			var nearest: PlanetController = null
			var best: float = INF
			for planet in route.planets:
				var d: float = player.global_position.distance_to(planet.global_position) - planet.radius
				if d < best:
					best = d
					nearest = planet
			var radial: Vector3 = (player.global_position - nearest.global_position).normalized()
			min_alignment = minf(min_alignment, player.get_up().dot(radial))
			flight_up_steps = maxf(flight_up_steps, prev_up.angle_to(player.get_up()))
		elif was_airborne:
			was_airborne = false
			landed_checks += 1
			var planet := frame.planet as PlanetController
			var radial: Vector3 = (player.global_position - planet.global_position).normalized()
			landing_ok = landing_ok and player.get_up().dot(radial) > 0.995 \
				and absf(player.global_position.distance_to(planet.global_position) - planet.radius - player.body_height) < 0.3
		prev_up = player.get_up()
		if i % 120 == 0:
			await process_frame
	var min_clearance: float = INF
	for c in clearances:
		min_clearance = minf(min_clearance, c)
	var missing: Array[String] = []
	for type_name in RouteTypes.SegmentType.keys():
		if not seen_types.has(RouteTypes.SegmentType[type_name]):
			missing.append(type_name)
	check("generator produced every segment type", missing.is_empty(), "missing %s" % str(missing))
	var sharp_ok: bool = not sharp_turns.is_empty()
	for angle in sharp_turns:
		sharp_ok = sharp_ok and absf(angle - 90.0) < 5.0
	check("generated sharp turns really turn about 90 degrees", sharp_ok, str(sharp_turns))
	check("the run made at least one planet-to-planet flight", flights >= 1, "flights %d" % flights)
	check("new planets and flights keep clear of other planets", clearances.size() >= 3 and min_clearance >= route.transition_min_clearance - 0.01,
		"%d planets, min clearance %f" % [clearances.size(), min_clearance])
	check("during flight the runner never turns upside down", min_alignment > 0.35, "min alignment %f" % min_alignment)
	check("runner orientation changes smoothly in flight", flight_up_steps < 0.06, "worst step %f rad" % flight_up_steps)
	check("every flight lands upright on the destination surface", landed_checks >= 1 and landing_ok,
		"landings %d" % landed_checks)
	check("lane offset survives a flight", absf(player.lane.offset) <= player.lane_width)
	await _free_world(world)

func _test_clicking() -> void:
	print("landmark clicking")
	var world := await _new_world()
	var player := world.player
	var target: LandmarkTarget = world.route.targets[0]
	check("the first target is the tutorial wonder", target.landmark_data.id == "lalibela")
	check("target is not clickable before its window opens", not target.attempt_interact(player.distance))
	# Advance until the window opens.
	while not target.is_active():
		world.tick(DT)
	await physics_frame
	await physics_frame
	world.gameplay_camera.snap()
	var screen: Vector2 = world.gameplay_camera.unproject_position(target.global_position)
	var viewport_rect: Rect2 = world.get_viewport().get_visible_rect()
	check("active target is on screen", viewport_rect.has_point(screen), "screen %s in %s" % [screen, viewport_rect])
	check("clicking empty space discovers nothing", not world.click_at(Vector2(4, 4)))
	check("empty click leaves the target active", target.is_active() and world.discovery_manager.discovered_wonders.is_empty())
	check("mouse ray picks the real target", world.gameplay_camera.pick_target(screen) == target)
	check("clicking an active target succeeds", world.click_at(screen))
	check("target is marked discovered", target.state == LandmarkTarget.State.DISCOVERED)
	check("second click does not award it again", not world.click_at(screen) and not target.attempt_interact(player.distance))
	check("exactly one wonder is recorded", world.discovery_manager.discovered_wonders.size() == 1)
	check("hearts are untouched by a discovery", world.discovery_manager.current_hearts == 3)
	check("discovery enters the feedback state without pausing",
		world.state == GameState.State.DISCOVERY_FEEDBACK and not paused)
	var distance_before: float = player.distance
	_step(world, 0.5, false)
	check("the run keeps going during discovery feedback", player.distance > distance_before + 1.0)
	await _free_world(world)

## Input events are given in window coordinates; convert from viewport coordinates.
func _window_pos(viewport_pos: Vector2) -> Vector2:
	return root.get_final_transform() * viewport_pos

func _mouse(pressed: bool, viewport_pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _window_pos(viewport_pos)
	ev.global_position = ev.position
	Input.parse_input_event(ev)

func _key(keycode: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _test_input_pipeline() -> void:
	print("real input events")
	var world := await _new_world()
	var player := world.player
	_key(KEY_D, true)
	await process_frame
	_key(KEY_D, false)
	check("D key moves one lane right", player.lane.target_lane == 1)
	_key(KEY_RIGHT, true)
	await process_frame
	_key(KEY_RIGHT, false)
	check("right arrow cannot pass the right lane", player.lane.target_lane == 1)
	_key(KEY_A, true)
	await process_frame
	_key(KEY_A, false)
	_key(KEY_LEFT, true)
	await process_frame
	_key(KEY_LEFT, false)
	check("A and left arrow reach the left lane", player.lane.target_lane == -1)
	_key(KEY_ESCAPE, true)
	await process_frame
	_key(KEY_ESCAPE, false)
	check("Escape pauses", world.state == GameState.State.PAUSED and paused)
	_key(KEY_D, true)
	await process_frame
	_key(KEY_D, false)
	check("lane input is ignored while paused", player.lane.target_lane == -1)
	check("pausing stops the world's processing", not world.player.can_process() and not world.route.can_process())
	_key(KEY_ESCAPE, true)
	await process_frame
	_key(KEY_ESCAPE, false)
	check("Escape resumes", world.is_playing() and not paused)

	# A real mouse press on a target goes through the input pipeline and discovers it once.
	var target: LandmarkTarget = world.route.targets[0]
	while not target.is_active():
		world.tick(DT)
	await physics_frame
	await physics_frame
	world.gameplay_camera.snap()
	var screen: Vector2 = world.gameplay_camera.unproject_position(target.global_position)
	_mouse(true, Vector2(4, 4))
	await process_frame
	_mouse(false, Vector2(4, 4))
	check("a real click on empty space discovers nothing", world.discovery_manager.discovered_wonders.is_empty() and target.is_active())
	_mouse(true, screen)
	await process_frame
	_mouse(false, screen)
	check("a real mouse click on the target discovers it", target.state == LandmarkTarget.State.DISCOVERED and world.discovery_manager.discovered_wonders.size() == 1)
	await process_frame
	_mouse(true, screen)
	await process_frame
	_mouse(false, screen)
	check("clicking the same spot again does nothing", world.discovery_manager.discovered_wonders.size() == 1)
	world.toggle_pause()
	var count_while_paused: int = world.discovery_manager.discovered_wonders.size()
	check("clicks are ignored while paused", not world.click_at(screen) and world.discovery_manager.discovered_wonders.size() == count_while_paused)
	await _free_world(world)
	paused = false

func _live_bolts() -> int:
	var count: int = 0
	for bolt in get_nodes_in_group("laser_bolts"):
		if not bolt.is_queued_for_deletion():
			count += 1
	return count

func _test_lasers() -> void:
	print("spaceship lasers")
	var world := await _new_world()
	var player := world.player
	check("the player is a spaceship with two wing cannons", player.get_node_or_null("Visuals/Ship") != null 		and player.get_node("Visuals/Cannons").get_child_count() == 2)
	_key(KEY_SPACE, true)
	await process_frame
	_key(KEY_SPACE, false)
	check("Space fires a laser", _live_bolts() == 1)
	check("firing at nothing discovers nothing", world.discovery_manager.discovered_wonders.is_empty())
	_mouse(true, Vector2(4, 4))
	await process_frame
	_mouse(false, Vector2(4, 4))
	check("a click on empty space still fires a laser but discovers nothing",
		_live_bolts() == 2 and world.discovery_manager.discovered_wonders.is_empty())
	for i in 40:
		player.fire_laser(player.global_position + player.get_forward() * 50.0)
	check("live bolts are capped", _live_bolts() <= player.max_bolts, "%d bolts" % _live_bolts())

	# Space locks on to a target inside the aim-assist cone.
	var target: LandmarkTarget = world.route.targets[0]
	while not target.is_active():
		world.tick(DT)
	var angle: float = player.get_forward().angle_to(target.global_position - player.global_position)
	check("an open target is inside the aim-assist cone", rad_to_deg(angle) < world.aim_assist_degrees, "%f deg" % rad_to_deg(angle))
	var bolts_before: int = _live_bolts()
	_key(KEY_SPACE, true)
	await process_frame
	_key(KEY_SPACE, false)
	check("Space locks on and discovers the target", target.state == LandmarkTarget.State.DISCOVERED 		and world.discovery_manager.discovered_wonders.size() == 1)
	check("the lock-on shot fired a bolt too", _live_bolts() >= mini(bolts_before + 1, player.max_bolts))
	_key(KEY_SPACE, true)
	await process_frame
	_key(KEY_SPACE, false)
	check("firing again does not award the wonder twice", world.discovery_manager.discovered_wonders.size() == 1)
	await _free_world(world)

func _test_missing_and_game_over() -> void:
	print("hearts and game over")
	var world := await _new_world()
	var dm := world.discovery_manager
	var first: LandmarkTarget = world.route.targets[0]
	# Run past the first target without clicking.
	while first.state != LandmarkTarget.State.MISSED:
		world.tick(DT)
	check("a passed target counts as missed", first.state == LandmarkTarget.State.MISSED)
	check("missing removes exactly one heart", dm.current_hearts == 2 and dm.missed_count == 1,
		"hearts %d missed %d" % [dm.current_hearts, dm.missed_count])
	await physics_frame
	await physics_frame
	check("clicking after the target passed does nothing",
		not first.attempt_interact(world.player.distance) and dm.discovered_wonders.is_empty())
	var screen: Vector2 = world.gameplay_camera.unproject_position(first.global_position)
	check("a late mouse click cannot discover it", not world.click_at(screen))
	var guard: int = 0
	while world.is_playing() and guard < int(240.0 / DT):
		world.tick(DT)
		guard += 1
	check("the third miss ends the run", world.state == GameState.State.GAME_OVER and dm.current_hearts == 0)
	check("exactly three targets were missed", dm.missed_count == 3, "missed %d" % dm.missed_count)
	check("player stops at game over", not world.player.running)
	check("game over screen is shown with stats", world.game_over_screen.visible)
	var head_before: float = world.route.head.distance
	var distance_before: float = world.player.distance
	for i in 120:
		world.tick(DT)
	check("generation and movement stop at game over",
		is_equal_approx(world.route.head.distance, head_before) and is_equal_approx(world.player.distance, distance_before))
	var any_clickable: bool = false
	for target in world.route.targets:
		if is_instance_valid(target) and target.collision_layer != 0:
			any_clickable = true
	check("targets are disabled at game over", not any_clickable)
	await _free_world(world)

func _test_restart_and_popup() -> void:
	print("popup content and restart")
	var world := await _new_world()
	var target: LandmarkTarget = world.route.targets[0]
	while not target.is_active():
		world.tick(DT)
	target.attempt_interact(world.player.distance)
	var popup := world.discovery_popup
	var data := target.landmark_data
	check("popup is visible after a discovery", popup.is_open())
	check("popup shows the wonder name", (popup.get_node("%WonderLabel") as Label).text == data.name)
	check("popup shows the achievement title", (popup.get_node("%AchievementLabel") as Label).text.contains(data.achievement_title))
	check("popup shows the landmark fact", (popup.get_node("%FactLabel") as Label).text == data.get_fact())
	check("popup shows the discovery count", (popup.get_node("%CountLabel") as Label).text.ends_with("1"))
	popup.hide_popup()
	check("closing the popup returns to RUNNING", world.state == GameState.State.RUNNING)
	# Burn all hearts, then restart.
	var guard: int = 0
	while world.is_playing() and guard < int(300.0 / DT):
		world.tick(DT)
		guard += 1
	check("run reached game over before restart", world.state == GameState.State.GAME_OVER)
	world.start_new_run()
	var dm := world.discovery_manager
	check("restart gives three hearts", dm.current_hearts == 3)
	check("restart clears discoveries", dm.discovered_wonders.is_empty() and dm.missed_count == 0)
	check("restart clears per-run landmark state", not LandmarkCatalog.get_by_id(data.id).discovered)
	check("restart returns to RUNNING at distance zero", world.state == GameState.State.RUNNING and world.player.distance == 0.0)
	check("restart hides the game over screen", not world.game_over_screen.visible and world.game_hud.visible)
	check("restart rebuilds the route", world.route.segments.size() >= 3 and world.route.targets.size() >= 1)
	check("restarted player is running", world.player.running)
	_step(world, 1.0)
	check("restarted run plays normally", world.player.distance > 10.0 and world.state != GameState.State.GAME_OVER)
	world.toggle_pause()
	check("pause freezes the tree and shows the menu", paused and world.pause_menu.visible and world.state == GameState.State.PAUSED)
	var frozen: float = world.player.distance
	world.tick(DT)
	check("no simulation while paused", world.player.distance == frozen)
	world.toggle_pause()
	check("resume continues the run", not paused and world.state != GameState.State.PAUSED)
	await _free_world(world)

func _test_worlds_and_backdrop() -> void:
	print("worlds, backdrop and mood")
	var biomes: Array[String] = ["highland", "rift", "simien", "danakil", "bale"]
	var world := await _new_world()
	var route_scene_paths: Array[String] = []
	for scene in world.route.planet_scenes:
		route_scene_paths.append(scene.resource_path)
	var problems: Array[String] = []
	for biome in biomes:
		var path: String = "res://scenes/planets/planet_%s.tscn" % biome
		if not route_scene_paths.has(path):
			problems.append(biome + " is not in the route's planet list")
		var planet := (load(path) as PackedScene).instantiate() as PlanetController
		world.add_child(planet)
		planet.global_position = Vector3(5000, 0, 0)
		await process_frame
		var terrain := planet.get_node_or_null("Terrain") as MeshInstance3D
		if terrain == null or terrain.mesh == null or planet.get_node_or_null("Clouds") == null:
			problems.append(biome + " is missing terrain or clouds")
		if planet.decorations == null or planet.decorations.get_child_count() < 40:
			problems.append(biome + " has too little scenery")
		else:
			for child in planet.decorations.get_children():
				if not child.has_meta("clearance"):
					problems.append("%s/%s has no clearance" % [biome, child.name])
					break
		if planet.radius < 35.0:
			problems.append(biome + " is too small")
		planet.queue_free()
	check("all five worlds are complete and in the route", problems.is_empty(), "
    ".join(problems))

	# Scenery clearing respects each object's own size.
	var test_planet := (load("res://scenes/planets/planet_simien.tscn") as PackedScene).instantiate() as PlanetController
	world.add_child(test_planet)
	test_planet.global_position = Vector3(8000, 0, 0)
	await process_frame
	var big: Node3D = null
	for child in test_planet.decorations.get_children():
		if (child as Node3D).get_meta("clearance", 0.0) > 8.0:
			big = child
			break
	check("worlds contain large landmarks such as mountains", big != null)
	if big != null:
		var near_point := PackedVector3Array([big.global_position + Vector3(10.0, 0, 0)])
		test_planet.clear_decorations_near(near_point, 2.0)
		check("a large object is cleared from farther away than a small one", big.is_queued_for_deletion())
	test_planet.queue_free()

	var backdrop := world.get_node_or_null("SpaceBackdrop") as Node3D
	check("the space backdrop is part of the world", backdrop != null and backdrop.get_child_count() >= 15)
	world.gameplay_camera.global_position += Vector3(123, 45, -67)
	await process_frame
	await process_frame
	check("the backdrop follows the camera so space never gets closer",
		backdrop.global_position.distance_to(world.gameplay_camera.global_position) < 0.01)

	var rift := (load("res://scenes/planets/planet_rift.tscn") as PackedScene).instantiate() as PlanetController
	world.add_child(rift)
	world.apply_mood(rift, true)
	var env: Environment = world.world_environment.environment
	check("a world's mood tints the sky light and fog", env.ambient_light_color.is_equal_approx(rift.ambient_color) 		and env.fog_light_color.is_equal_approx(rift.fog_color))
	rift.queue_free()
	var ids: Dictionary = {}
	for landmark in LandmarkCatalog.get_all():
		ids[landmark.id] = true
	check("the catalog holds 15 unique wonders", LandmarkCatalog.get_all().size() == 15 and ids.size() == 15,
		"%d wonders, %d ids" % [LandmarkCatalog.get_all().size(), ids.size()])
	await _free_world(world)

func _test_resources_load() -> void:
	print("resources")
	var problems: Array[String] = []
	var scanned: int = 0
	for path in _collect_files("res://", ["tscn", "gd", "tres"]):
		scanned += 1
		if load(path) == null:
			problems.append("failed to load " + path)
			continue
		if path.ends_with(".tscn") or path.ends_with(".tres"):
			for dep in ResourceLoader.get_dependencies(path):
				var dep_path: String = dep.get_slice("::", 2) if dep.contains("::") else dep
				if not ResourceLoader.exists(dep_path):
					problems.append("%s -> missing %s" % [path, dep_path])
	check("all %d scenes, scripts and resources load with no missing references" % scanned, problems.is_empty(), "\n    ".join(problems))
	var scene_problems: Array[String] = []
	for landmark in LandmarkCatalog.get_all():
		var packed: PackedScene = landmark.load_scene()
		if packed == null or not packed.instantiate() is Node3D:
			scene_problems.append(landmark.id)
	check("every catalog wonder has a scene", scene_problems.is_empty(), str(scene_problems))

func _collect_files(dir_path: String, extensions: Array) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for sub in dir.get_directories():
		if sub.begins_with(".") or sub == "downloaded":
			continue
		found.append_array(_collect_files(dir_path.path_join(sub), extensions))
	for file in dir.get_files():
		if file.get_extension() in extensions:
			found.append(dir_path.path_join(file))
	return found

func _test_return_to_menu() -> void:
	print("return to main menu")
	var world := await _new_world()
	world.toggle_pause()
	world.pause_menu.main_menu_requested.emit()
	await process_frame
	await process_frame
	check("pause menu returns to the main menu", current_scene is MainMenu, str(current_scene))
	check("tree is unpaused after leaving", not paused)
