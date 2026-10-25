extends SceneTree
## Headless gameplay tests. Run from the project folder:
##   godot --headless --path . --script res://tests/test_suite.gd
## Exits with the number of failed checks.

const DT: float = 1.0 / 60.0
const MENU_SCENE: String = "res://scenes/menus/main_menu.tscn"
const SPLASH_SCENE: String = "res://scenes/menus/splash.tscn"
const TEST_BOARD: String = "user://test_leaderboard.json"
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
	await _test_health_and_hud()
	await _test_obstacles()
	await _test_ui_and_audio()
	await _test_theme_and_kenney_assets()
	await _test_ui_motion()
	await _test_screen_animations()
	await _test_layout()
	await _test_missing_and_game_over()
	await _test_leaderboard_and_score()
	await _test_space_and_wonders()
	await _test_restart_and_popup()
	await _test_worlds_and_backdrop()
	_test_resources_load()
	await _test_return_to_menu()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(_failed)

# --- helpers -------------------------------------------------------------------------------------------

func _new_world(with_obstacles: bool = false) -> GameManager:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate() as GameManager
	world.random_seed_each_run = false # the fixed route the tests rely on
	world.leaderboard_path = TEST_BOARD
	root.add_child(world)
	world.set_process(false) # tests drive tick() themselves
	await process_frame
	# Rocks are opt-in here, so long autoplay runs are not interrupted by crashes.
	world.route.obstacles_enabled = with_obstacles
	# Fuel has its own tests; long autoplay runs must not run dry.
	world.fuel_enabled = false
	world.route.fuel_tanks_enabled = false
	world.ammo_enabled = false
	world.route.ammo_crates_enabled = false
	world.pause_on_discovery = false # long autoplay runs must not stall on a popup
	world.start_new_run()
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
	check("project launches into the splash screens",
		ProjectSettings.get_setting("application/run/main_scene") == SPLASH_SCENE)
	var splash := (load(SPLASH_SCENE) as PackedScene).instantiate() as Splash
	root.add_child(splash)
	await process_frame
	var logo := splash.get_node("%Logo") as TextureRect
	check("the first splash is Techawach on white", splash.index == 0 and logo.texture.resource_path.ends_with("techawach.jpg")
		and splash.get_node("%Background").color == Color.WHITE)
	var view_height: float = splash.get_viewport_rect().size.y
	check("the logo is shown small enough to stay sharp", splash.logo_size().y <= view_height * 0.55 and splash.logo_size().y >= view_height * 0.2)
	await create_timer(1.2).timeout
	check("the logo fades in rather than popping", logo.modulate.a > 0.2 and logo.scale.x > 0.9)
	splash.skip()
	check("the second splash is Melkam", splash.index == 1 and logo.texture.resource_path.ends_with("melkam.jpg"))
	await create_timer(0.3).timeout
	var blended: Color = splash.get_node("%Background").color
	check("the background dissolves between logos instead of cutting", blended.r < 0.99 and blended.r > 0.1, str(blended))
	check("the splash scene leads to the main menu", splash.next_scene == MENU_SCENE)
	splash.set_process(false)
	splash.queue_free()
	await process_frame
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
	var ship_length: float = (player.get_node("Visuals/Ship") as MeshInstance3D).get_aabb().size.z * (player.get_node("Visuals") as Node3D).scale.z
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
	_key(KEY_D, true)
	await process_frame
	check("holding D steers right", Input.get_axis("move_left", "move_right") > 0.5)
	_step(world, 0.1)
	check("steering is smooth, not a teleport", player.lane.offset > start_offset and player.lane.offset < 2.0, str(player.lane.offset))
	_step(world, 0.5)
	var lateral: float = (player.global_position - player.center_transform().origin).dot(player.frame.right)
	check("the ship slid right along the surface", lateral > player.lane_width * 1.5, "lateral %f" % lateral)
	_step(world, 2.0)
	check("the ship stops at the edge of the band", is_equal_approx(player.lane.offset, player.steer_band) and player.lane.velocity == 0.0)
	_key(KEY_D, false)
	await process_frame
	_step(world, 0.3)
	check("releasing the key stops the ship where it is", is_equal_approx(player.lane.offset, player.steer_band))
	_key(KEY_LEFT, true)
	await process_frame
	_step(world, 0.5)
	check("the ship can rest anywhere, not only on three lanes", player.lane.offset < player.steer_band - 3.0 and player.lane.offset > -player.steer_band)
	_step(world, 3.0)
	check("the band is wide on the left too", is_equal_approx(player.lane.offset, -player.steer_band))
	_key(KEY_LEFT, false)
	await process_frame
	player.lane.reset()
	_key(KEY_W, true)
	await process_frame
	var d0: float = player.distance
	_step(world, 1.5)
	check("W speeds the ship up", player.speed_scale > 1.2 and player.distance - d0 > player.run_speed * 1.5 * 1.1, "scale %f" % player.speed_scale)
	_key(KEY_W, false)
	_key(KEY_S, true)
	await process_frame
	_step(world, 2.0)
	check("S slows the ship down but never stops it", player.speed_scale < 0.8 and player.speed_scale >= player.min_speed_scale - 0.001)
	_key(KEY_S, false)
	await process_frame

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
	for i in int(240.0 / DT):
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
	check("sideways offset survives a flight", absf(player.lane.offset) <= player.steer_band + 0.001)
	await _free_world(world)

func _test_clicking() -> void:
	print("landmark clicking")
	var world := await _new_world()
	world.pause_on_discovery = true
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
	check("discovery enters the feedback state without pausing the tree",
		world.state == GameState.State.DISCOVERY_FEEDBACK and not paused)
	var distance_before: float = player.distance
	_step(world, 1.0, false)
	check("the ship stops while the popup is open", absf(player.distance - distance_before) < 0.001 and world.discovery_popup.is_open())
	world.discovery_popup.hide_popup()
	check("closing the popup lets the ship fly on", world.state == GameState.State.RUNNING)
	_step(world, 0.5, false)
	check("the ship moves again after the popup", player.distance > distance_before + 1.0)
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
	_step(world, 0.4, false)
	_key(KEY_D, false)
	check("D key steers right", player.lane.offset > 2.0)
	_key(KEY_A, true)
	await process_frame
	_step(world, 1.5, false)
	_key(KEY_A, false)
	check("A key steers left", player.lane.offset < -2.0)
	_key(KEY_ESCAPE, true)
	await process_frame
	_key(KEY_ESCAPE, false)
	check("Escape pauses", world.state == GameState.State.PAUSED and paused)
	var offset_paused: float = player.lane.offset
	_key(KEY_D, true)
	await process_frame
	world.tick(DT)
	_key(KEY_D, false)
	await process_frame
	check("steering is ignored while paused", is_equal_approx(player.lane.offset, offset_paused))
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
	check("Space no longer fires: shooting is by mouse only", _live_bolts() == 0)
	check("firing at nothing discovers nothing", world.discovery_manager.discovered_wonders.is_empty())
	_mouse(true, Vector2(4, 4))
	await process_frame
	_mouse(false, Vector2(4, 4))
	check("a click on empty space fires a laser but discovers nothing",
		_live_bolts() == 1 and world.discovery_manager.discovered_wonders.is_empty())
	for i in 40:
		player.fire_laser(player.global_position + player.get_forward() * 50.0)
	check("live bolts are capped", _live_bolts() <= player.max_bolts, "%d bolts" % _live_bolts())

	# There is no auto-aim: an open target is only discovered by clicking on it.
	var target: LandmarkTarget = world.route.targets[0]
	while not target.is_active():
		world.tick(DT)
	_key(KEY_SPACE, true)
	await process_frame
	_key(KEY_SPACE, false)
	check("Space does not lock on to an open target", target.state == LandmarkTarget.State.ACTIVE and world.discovery_manager.discovered_wonders.is_empty())
	check("the game has no lock-on function any more", not world.has_method("fire_forward"))
	await _free_world(world)

func _hud_heart_textures(world: GameManager) -> Array[Texture2D]:
	var found: Array[Texture2D] = []
	for heart in world.game_hud.get_node("%Hearts").get_children():
		found.append((heart as TextureRect).texture)
	return found

func _test_health_and_hud() -> void:
	print("half hearts")
	var world := await _new_world()
	var dm := world.discovery_manager
	var hud := world.game_hud
	check("a run starts with six half hearts", dm.health_halves == 6 and is_equal_approx(dm.current_hearts, 3.0))
	var textures := _hud_heart_textures(world)
	check("a full health bar shows three full hearts", textures == [hud.heart_full, hud.heart_full, hud.heart_full])
	dm.register_obstacle_hit()
	check("an obstacle costs exactly half a heart", dm.health_halves == 5 and is_equal_approx(dm.current_hearts, 2.5))
	textures = _hud_heart_textures(world)
	check("the third heart turns into a half heart", textures == [hud.heart_full, hud.heart_full, hud.heart_half])
	dm.register_miss(LandmarkCatalog.get_by_id("lalibela"))
	check("a missed wonder still costs a whole heart", dm.health_halves == 3 and is_equal_approx(dm.current_hearts, 1.5))
	textures = _hud_heart_textures(world)
	check("hearts show full, half and empty", textures == [hud.heart_full, hud.heart_half, hud.heart_empty])
	check("two obstacles do not end the run", dm.obstacles_hit == 1 and world.state != GameState.State.GAME_OVER)
	dm.register_obstacle_hit()
	dm.register_obstacle_hit()
	check("half hearts run out into game over", dm.health_halves == 1 and world.state != GameState.State.GAME_OVER)
	dm.register_obstacle_hit()
	check("the last half heart ends the run", world.state == GameState.State.GAME_OVER and dm.health_halves == 0)
	var stats: Dictionary = dm.stats()
	check("run stats include rocks hit and destroyed", stats.has("obstacles_hit") and stats.has("obstacles_destroyed") and stats["obstacles_hit"] == 4)
	check("the game over screen shows the stats", world.game_over_screen.visible)
	await _free_world(world)

func _first_obstacle(world: GameManager) -> Obstacle:
	var first: Obstacle = null
	for obstacle in world.route.obstacles:
		if first == null or obstacle.route_distance < first.route_distance:
			first = obstacle
	return first

## Moves the ship straight to a sideways offset without waiting for the slide.
func _snap_to_offset(world: GameManager, offset: float) -> void:
	world.player.lane.place(offset)

func _test_obstacles() -> void:
	print("obstacles")
	var world := await _new_world(true)
	var route := world.route
	var dm := world.discovery_manager
	check("rocks are generated ahead of the ship", route.obstacles.size() >= 3, "%d rocks" % route.obstacles.size())
	var too_early: int = 0
	var blocked_rows: int = 0
	var min_offset: float = 0.0
	var max_offset: float = 0.0
	var in_calm_segments: int = 0
	for obstacle in route.obstacles:
		if obstacle.route_distance < route.obstacle_min_start:
			too_early += 1
		var row_offsets: Array[float] = []
		for other in route.obstacles:
			if absf(other.route_distance - obstacle.route_distance) < 2.0:
				row_offsets.append(other.lane_offset)
		row_offsets.sort()
		if route._widest_gap(row_offsets).y < route.passable_gap - 0.01:
			blocked_rows += 1
		min_offset = minf(min_offset, obstacle.lane_offset)
		max_offset = maxf(max_offset, obstacle.lane_offset)
		for seg in route.segments:
			if seg.contains(obstacle.route_distance) and seg.type in [RouteTypes.SegmentType.LANDMARK_APPROACH,
					RouteTypes.SegmentType.RECOVERY, RouteTypes.SegmentType.PLANET_ARRIVAL, RouteTypes.SegmentType.PLANET_TRANSITION]:
				in_calm_segments += 1
	check("the tutorial stretch has no rocks", too_early == 0, "%d too early" % too_early)
	check("every row of rocks leaves a gap wide enough to fly through", blocked_rows == 0, "%d blocked rows" % blocked_rows)
	check("rocks are scattered across the whole band, not three lanes", max_offset - min_offset > 2.0 * route.lane_width * 1.5,
		"offsets %f to %f" % [min_offset, max_offset])
	check("no rocks in landmark, recovery, arrival or flight segments", in_calm_segments == 0, "%d" % in_calm_segments)

	# Flying into a rock costs half a heart, and the rock breaks.
	var rock := _first_obstacle(world)
	_snap_to_offset(world, rock.lane_offset)
	var guard: int = 0
	while rock.is_active() and world.is_playing() and guard < int(30.0 / DT):
		world.tick(DT)
		for target in route.targets:
			if is_instance_valid(target) and target.is_active():
				target.attempt_interact(world.player.distance)
		_snap_to_offset(world, rock.lane_offset)
		guard += 1
	check("crashing into a rock costs half a heart", dm.obstacles_hit >= 1 and dm.health_halves == 6 - dm.obstacles_hit - 2 * dm.missed_count,
		"hits %d halves %d" % [dm.obstacles_hit, dm.health_halves])
	check("the rock that was hit is destroyed", not rock.is_active())
	check("the ship is invulnerable and blinking after a crash", world.player.is_invulnerable())
	var hits_after_crash: int = dm.obstacles_hit
	_step(world, 0.2)
	check("one crash cannot cost more than half a heart", dm.obstacles_hit == hits_after_crash)
	_step(world, 1.5, true)
	check("invulnerability wears off", not world.player.is_invulnerable())
	await _free_world(world)

	# Dodging: steering through the gap in a row avoids the rocks completely.
	world = await _new_world(true)
	var target_rock := _first_obstacle(world)
	var row: Array[float] = []
	for other in world.route.obstacles:
		if absf(other.route_distance - target_rock.route_distance) < 2.0:
			row.append(other.lane_offset)
	row.sort()
	var free_offset: float = world.route._widest_gap(row).x
	_snap_to_offset(world, free_offset)
	var hits_before: int = world.discovery_manager.obstacles_hit
	while world.player.distance < target_rock.route_distance + 3.0 and world.is_playing():
		world.tick(DT)
		for target in world.route.targets:
			if is_instance_valid(target) and target.is_active():
				target.attempt_interact(world.player.distance)
		_snap_to_offset(world, free_offset)
		if world.player.distance > target_rock.route_distance - 15.0:
			break
	while world.player.distance < target_rock.route_distance + 3.0 and world.is_playing():
		world.tick(DT)
		_snap_to_offset(world, free_offset)
	check("steering through the gap dodges a rock", world.discovery_manager.obstacles_hit == hits_before and target_rock.is_active())
	await _free_world(world)

	# Lasers: clicking a rock destroys it, with no damage.
	world = await _new_world(true)
	var shot_rock := _first_obstacle(world)
	var cleared: bool = true
	while shot_rock.route_distance - world.player.distance > 28.0 and world.is_playing():
		world.tick(DT)
		for target in world.route.targets:
			if is_instance_valid(target) and target.is_active():
				target.attempt_interact(world.player.distance)
		_snap_to_offset(world, 0.0)
	await physics_frame
	await physics_frame
	world.gameplay_camera.snap()
	var screen: Vector2 = world.gameplay_camera.unproject_position(shot_rock.global_position + Vector3.UP * 0.9)
	var health_before: int = world.discovery_manager.health_halves
	check("clicking a rock does not count as a discovery", not world.click_at(screen))
	check("a laser shot destroys the rock", not shot_rock.is_active())
	check("shooting a rock costs nothing", world.discovery_manager.health_halves == health_before)
	check("the destroyed rock is counted", world.discovery_manager.obstacles_destroyed == 1)
	await _free_world(world)

	# Space locks on to the nearest rock when no wonder is open.
	world = await _new_world(true)
	var lock_rock := _first_obstacle(world)
	while lock_rock.route_distance - world.player.distance > 30.0 and world.is_playing():
		world.tick(DT)
		for target in world.route.targets:
			if is_instance_valid(target) and target.is_active():
				target.attempt_interact(world.player.distance)
		_snap_to_offset(world, lock_rock.lane_offset)
	world.discovery_popup.hide_popup(false) # an open popup would take the Space press
	_key(KEY_SPACE, true)
	await process_frame
	_key(KEY_SPACE, false)
	check("Space does not blast rocks for you", world.discovery_manager.obstacles_destroyed == 0)
	check("a click on the rock still blasts it", world.click_at(world.gameplay_camera.unproject_position(lock_rock.global_position)) == false
		and (world.discovery_manager.obstacles_destroyed == 1 or not lock_rock.is_active()))
	await _free_world(world)

func _test_ui_and_audio() -> void:
	print("game UI and audio")
	var audio := root.get_node_or_null("GameAudio")
	check("the GameAudio autoload exists", audio != null)
	var missing: Array[String] = []
	for sound in ["laser", "laser_hit", "discover", "hit", "explosion", "heart_lost", "launch", "arrive",
			"ui_hover", "ui_click", "game_over", "engine", "music"]:
		var player := audio.get_node_or_null(sound) as AudioStreamPlayer if audio else null
		if player == null or player.stream == null:
			missing.append(sound)
	check("every sound is present", missing.is_empty(), str(missing))
	var music_stream: AudioStream = (audio.get_node("music") as AudioStreamPlayer).stream
	check("the music is videoplayback.ogg and loops", music_stream.resource_path.ends_with("videoplayback.ogg") and (music_stream as AudioStreamOggVorbis).loop)
	check("the Music and Effects buses exist", AudioServer.get_bus_index(&"Music") >= 0 and AudioServer.get_bus_index(&"Effects") >= 0)
	audio.set_bus_volume(&"Music", 0.5)
	check("bus volume can be changed", absf(audio.get_bus_volume(&"Music") - 0.5) < 0.01)
	audio.set_bus_volume(&"Music", 1.0)
	var button := Button.new()
	root.add_child(button)
	check("buttons get hover and click sounds automatically", button.mouse_entered.get_connections().size() > 0 and button.pressed.get_connections().size() > 0)
	button.queue_free()

	var theme := load("res://assets/ui/game_theme.tres") as Theme
	check("the game theme loads with a default font", theme != null and theme.default_font != null)
	check("the theme styles buttons and panels", theme.has_stylebox("normal", "Button") and theme.has_stylebox("panel", "PanelContainer"))
	check("the title style uses its own font", theme.get_font("font", "TitleLabel") != theme.default_font)
	var unthemed: Array[String] = []
	for path in ["res://scenes/menus/main_menu.tscn", "res://scenes/ui/game_hud.tscn", "res://scenes/ui/discovery_popup.tscn",
			"res://scenes/ui/pause_menu.tscn", "res://scenes/game/game_over.tscn"]:
		var screen := (load(path) as PackedScene).instantiate() as Control
		if screen.theme != theme:
			unthemed.append(path)
		screen.free()
	check("every screen uses the game theme", unthemed.is_empty(), str(unthemed))
	var world := await _new_world()
	check("the ship is smaller than before", (world.player.get_node("Visuals") as Node3D).scale.x <= 0.7)
	await _free_world(world)

func _test_theme_and_kenney_assets() -> void:
	print("Kenney theme and assets")
	var theme := load("res://assets/ui/game_theme.tres") as Theme
	var problems: Array[String] = []
	var checked: int = 0
	for theme_type in ["Button", "GreyButton", "RedButton", "PanelContainer", "HudPanel", "CardPanel", "HeaderLabel"]:
		for style_name in ["normal", "hover", "pressed", "disabled", "panel"]:
			if not theme.has_stylebox(style_name, theme_type):
				continue
			var box := theme.get_stylebox(style_name, theme_type)
			if box is StyleBoxTexture:
				checked += 1
				var texture := (box as StyleBoxTexture).texture
				var sb := box as StyleBoxTexture
				if texture == null:
					problems.append("%s/%s has no texture" % [theme_type, style_name])
				elif sb.texture_margin_left + sb.texture_margin_right >= texture.get_width() \
						or sb.texture_margin_top + sb.texture_margin_bottom >= texture.get_height() + 1:
					problems.append("%s/%s margins exceed the texture" % [theme_type, style_name])
	check("buttons, panels and ribbons are Kenney Adventure 9-slice textures", checked >= 14 and problems.is_empty(), "%d checked, %s" % [checked, str(problems)])
	var variations: Array[String] = []
	for variation in ["TitleLabel", "HeaderLabel", "FloatLabel", "StatLabel", "HintLabel", "NumberLabel",
			"GreyButton", "RedButton", "HudPanel", "CardPanel"]:
		if theme.get_type_variation_base(variation) == &"":
			variations.append(variation)
	check("every theme variation the screens use exists", variations.is_empty(), str(variations))
	var title_font := theme.get_font("font", "TitleLabel") as FontVariation
	var button_font := theme.get_font("font", "Button") as FontVariation
	check("titles and buttons use Cinzel", title_font != null and title_font.base_font.resource_path.ends_with("Cinzel-Variable.ttf")
		and button_font != null and button_font.base_font.resource_path.ends_with("Cinzel-Variable.ttf"))
	var body_font := theme.default_font as FontVariation
	check("reading text uses Nunito", body_font != null and body_font.base_font.resource_path.ends_with("Nunito-Variable.ttf"))
	check("no Ethiopic font or Geez text is left", not FileAccess.file_exists("res://assets/fonts/NotoSansEthiopic-Variable.ttf")
		and not (FileAccess.get_file_as_string("res://scenes/menus/main_menu.tscn") + FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")).contains("የ"))
	var missing: Array[String] = []
	for path in ["res://assets/ui/kenney/adventure/panel_brown.png", "res://assets/ui/kenney/adventure/panel_brown_corners.png",
			"res://assets/ui/kenney/adventure/button_brown.png", "res://assets/ui/kenney/adventure/button_red.png",
			"res://assets/ui/kenney/adventure/button_grey.png", "res://assets/ui/techawach.jpg", "res://assets/ui/melkam.jpg",
			"res://assets/ui/kenney/icons/star.png", "res://assets/ui/kenney/cursors/crosshair.png",
			"res://assets/ui/kenney/cursors/arrow.png", "res://assets/ui/kenney/License.txt",
			"res://assets/fonts/Cinzel-Variable.ttf", "res://assets/fonts/Nunito-Variable.ttf", "res://assets/audio/kenney_click.ogg", "res://assets/audio/kenney_tap.ogg"]:
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			missing.append(path)
	check("the Kenney sprites, fonts, sounds and licence are in the project", missing.is_empty(), str(missing))
	var audio := root.get_node("GameAudio")
	check("interface sounds are Kenney's", (audio.get_node("ui_click") as AudioStreamPlayer).stream.resource_path.contains("kenney"))
	check("the UiHooks autoload is present", root.has_node("UiHooks"))

## A plain Control to animate, parked in the tree with a known size and position.
func _motion_control(position: Vector2 = Vector2(100, 100)) -> Control:
	var control := Control.new()
	control.custom_minimum_size = Vector2(120, 60)
	control.size = Vector2(120, 60)
	control.position = position
	root.add_child(control)
	return control

func _test_ui_motion() -> void:
	print("UI motion")
	# Pop in: starts small and invisible, passes through the middle, ends exact.
	var control := _motion_control()
	UiMotion.pop_in(control, 0.0, 0.4)
	check("pop-in starts invisible and smaller", control.modulate.a == 0.0 and control.scale.x < 1.0)
	await create_timer(0.12).timeout
	check("pop-in is partway after a moment", control.modulate.a > 0.0 and control.modulate.a <= 1.0 and control.scale.x < 1.0 + 0.3)
	await create_timer(0.7).timeout
	check("pop-in ends fully visible at exactly scale 1", is_equal_approx(control.modulate.a, 1.0) and control.scale.is_equal_approx(Vector2.ONE))

	# Slide in: starts displaced, ends at home, and re-triggering mid-slide never drifts.
	control.position = Vector2(100, 100)
	UiMotion.slide_in(control, Vector2(0, -200), 0.0, 0.4)
	check("slide-in starts displaced", control.position.y < 0.0)
	await create_timer(0.1).timeout
	UiMotion.slide_in(control, Vector2(0, -200), 0.0, 0.4)
	await create_timer(0.9).timeout
	check("slide-in ends exactly at home even when re-triggered", control.position.is_equal_approx(Vector2(100, 100)) and is_equal_approx(control.modulate.a, 1.0),
		str(control.position))

	# Slide out: ends hidden, then everything is restored for next time.
	UiMotion.slide_out(control, Vector2(0, -200), 0.25)
	await create_timer(0.6).timeout
	check("slide-out hides the control and restores its state", not control.visible and control.position.is_equal_approx(Vector2(100, 100)) and is_equal_approx(control.modulate.a, 1.0))

	# Pop out likewise.
	control.visible = true
	UiMotion.pop_out(control, 0.2)
	await create_timer(0.5).timeout
	check("pop-out hides and restores", not control.visible and control.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(control.modulate.a, 1.0))

	# Punch ends clean.
	control.visible = true
	UiMotion.punch(control, 1.5, 0.4)
	await create_timer(0.08).timeout
	check("punch grows the control", control.scale.x > 1.0)
	await create_timer(1.2).timeout
	check("punch settles at scale 1 and no tilt", control.scale.is_equal_approx(Vector2.ONE) and absf(control.rotation_degrees) < 0.01,
		"%s %f" % [control.scale, control.rotation_degrees])

	# Reset snaps everything back mid-animation.
	UiMotion.slide_in(control, Vector2(300, 0), 0.0, 1.0)
	UiMotion.reset(control)
	await create_timer(0.3).timeout
	check("reset stops animations and restores rest state", control.position.is_equal_approx(Vector2(100, 100)) and is_equal_approx(control.modulate.a, 1.0))

	# Count up: between start and end partway, exact at the end, formatter applied.
	var label := Label.new()
	root.add_child(label)
	UiMotion.count_up(label, 0, 100, 0.5, func(v: int) -> String: return "%d m" % v)
	await create_timer(0.2).timeout
	var partway: int = int(label.text.get_slice(" ", 0))
	check("count-up is between the start and the end partway", partway > 0 and partway < 100, label.text)
	await create_timer(0.7).timeout
	check("count-up lands exactly on the final value", label.text == "100 m", label.text)
	label.queue_free()

	# Buttons spring on hover and press, and always return to rest.
	var button := Button.new()
	button.text = "TEST"
	root.add_child(button)
	await process_frame
	check("every new button is hooked for motion automatically", button.has_meta("_motion_hooked"))
	button.mouse_entered.emit()
	await create_timer(0.4).timeout
	check("hovering springs a button up", button.scale.x > 1.03, str(button.scale))
	button.button_down.emit()
	await create_timer(0.3).timeout
	check("pressing squashes a button", button.scale.x < 1.0, str(button.scale))
	button.mouse_exited.emit()
	await create_timer(0.4).timeout
	check("a button returns to exactly scale 1", button.scale.is_equal_approx(Vector2.ONE), str(button.scale))
	for i in 6:
		button.mouse_entered.emit()
		await create_timer(0.02).timeout
		button.mouse_exited.emit()
		await create_timer(0.02).timeout
	await create_timer(0.5).timeout
	check("rapid hovering never leaves a button scaled", button.scale.is_equal_approx(Vector2.ONE), str(button.scale))
	button.disabled = true
	button.mouse_entered.emit()
	await create_timer(0.3).timeout
	check("disabled buttons do not spring", button.scale.is_equal_approx(Vector2.ONE))
	button.queue_free()

	# Animations keep running while the game is paused, so menus still animate.
	control.visible = true
	paused = true
	UiMotion.pop_in(control, 0.0, 0.3)
	await create_timer(0.7).timeout
	var ran_while_paused: bool = is_equal_approx(control.modulate.a, 1.0) and control.scale.is_equal_approx(Vector2.ONE)
	paused = false
	check("UI animations run while the tree is paused", ran_while_paused)
	control.queue_free()

	# The screen fade.
	var fade := (load("res://scenes/ui/screen_fade.tscn") as PackedScene).instantiate() as ScreenFade
	root.add_child(fade)
	await process_frame
	check("the screen fade starts black", fade.opacity() == 1.0)
	fade.fade_in(0.2)
	await create_timer(0.6).timeout
	check("fading in clears the screen", fade.opacity() == 0.0)
	fade.fade_out(0.2)
	await create_timer(0.6).timeout
	check("fading out goes fully black", fade.opacity() == 1.0)
	fade.queue_free()

func _test_screen_animations() -> void:
	print("screen animations")
	Engine.time_scale = 1.0
	# Main menu intro: everything ends visible and in place.
	var menu := (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	await process_frame
	var title := menu.get_node("%TitleTop") as Control
	var card := menu.get_node("%MenuCard") as Control
	check("the menu starts with its title and card hidden", title.modulate.a < 0.2 and card.modulate.a < 0.2)
	await create_timer(2.6).timeout
	var all_visible: bool = true
	for node_name in ["%TitleTop", "%TitleBottom", "%GreetingLabel", "%MenuCard"]:
		all_visible = all_visible and is_equal_approx((menu.get_node(node_name) as Control).modulate.a, 1.0)
	check("the menu intro ends with every element fully visible", all_visible)
	check("the menu stays minimal: title, greeting and the button card", menu.get_node("Center").get_child_count() == 5 and not menu.has_node("%ControlsBar"))
	check("the menu's buttons are clickable and focused", (menu.get_node("%PlayButton") as Button).has_focus())
	menu.queue_free()
	await process_frame

	# HUD: intro, heart punch, count-up, toast.
	var world := await _new_world()
	var hud := world.game_hud
	await create_timer(1.4).timeout
	var hearts := hud.get_node("%Hearts").get_children()
	var intro_done: bool = is_equal_approx((hud.get_node("%StatusPanel") as Control).modulate.a, 1.0)
	for heart in hearts:
		intro_done = intro_done and is_equal_approx((heart as Control).modulate.a, 1.0) and (heart as Control).scale.is_equal_approx(Vector2.ONE)
	check("the HUD intro ends with the panel and hearts fully in", intro_done)
	world.discovery_manager.register_obstacle_hit()
	await create_timer(0.08).timeout
	var lost_heart := hearts[2] as Control
	check("losing health punches the affected heart", lost_heart.scale.x > 1.05, str(lost_heart.scale))
	await create_timer(1.2).timeout
	check("the heart settles back to normal size", lost_heart.scale.is_equal_approx(Vector2.ONE) and lost_heart.modulate.is_equal_approx(Color.WHITE))
	hud.update_wonders(3)
	await create_timer(0.1).timeout
	var counting: String = (hud.get_node("%WondersLabel") as Label).text
	await create_timer(0.8).timeout
	check("the wonder counter ticks up to its final value", (hud.get_node("%WondersLabel") as Label).text == "3 wonders", counting)
	hud.show_toast("Test message")
	var toast := hud.get_node("%ToastPanel") as Control
	await create_timer(0.6).timeout
	check("a toast slides in and stays", toast.visible and is_equal_approx(toast.modulate.a, 1.0))
	var toast_home: Vector2 = toast.position
	hud._toast_timer.timeout.emit()
	await create_timer(0.7).timeout
	check("a toast slides out, hides and returns to rest", not toast.visible and toast.position.is_equal_approx(toast_home))
	hud.show_toast("Again")
	await create_timer(0.7).timeout
	check("a toast can be shown again after leaving", toast.visible and toast.position.is_equal_approx(toast_home))

	# Achievement banner.
	var popup := world.discovery_popup
	var panel := popup.get_node("%Panel") as Control
	var landmark := LandmarkCatalog.get_by_id("yeha")
	popup.show_discovery(landmark, 1)
	await create_timer(0.1).timeout
	check("the banner is off-screen at first and sliding", panel.visible and panel.position.y < 130.0, str(panel.position))
	await create_timer(1.0).timeout
	var banner_home_y: float = panel.position.y
	check("the banner lands fully visible", is_equal_approx(panel.modulate.a, 1.0) and banner_home_y >= 0.0)
	popup.hide_popup()
	await create_timer(0.7).timeout
	check("the banner slides away and hides", not panel.visible and not popup.is_open())
	popup.show_discovery(landmark, 2)
	popup.hide_popup(false)
	popup.show_discovery(landmark, 3)
	await create_timer(1.0).timeout
	check("rapid show, hide, show leaves the banner in place", panel.visible and absf(panel.position.y - banner_home_y) < 1.0,
		"%f vs %f" % [panel.position.y, banner_home_y])
	popup.hide_popup(false)

	# Pause card pops in with its buttons.
	world.toggle_pause()
	var card_node := world.pause_menu.get_node("%Card") as Control
	await create_timer(0.9).timeout
	var pause_ready: bool = is_equal_approx(card_node.modulate.a, 1.0) and card_node.scale.is_equal_approx(Vector2.ONE)
	for button_name in ["%ResumeButton", "%RestartButton", "%MainMenuButton"]:
		pause_ready = pause_ready and is_equal_approx((world.pause_menu.get_node(button_name) as Control).modulate.a, 1.0)
	check("the pause card and its buttons finish fully visible while paused", pause_ready)
	world.toggle_pause()
	check("resuming hides the pause card at once", not world.pause_menu.visible)

	# Game over: stats count up to the exact numbers.
	world.discovery_manager.obstacles_destroyed = 4
	world.discovery_manager.run_distance = 123.0
	world.discovery_manager.elapsed_time = 75.0
	world.discovery_manager.health_halves = 1
	world.discovery_manager.register_obstacle_hit()
	check("game over shows the card straight away", world.game_over_screen.visible)
	await create_timer(0.3).timeout
	var counting_label := world.game_over_screen.get_node("%DistanceLabel") as Label
	var mid_text: String = counting_label.text
	await create_timer(2.6).timeout
	var go := world.game_over_screen
	check("game over stats count up to their exact final values",
		(go.get_node("%RocksLabel") as Label).text == "4" and (go.get_node("%DistanceLabel") as Label).text == "123 m" \
		and (go.get_node("%TimeLabel") as Label).text == "01:15" and (go.get_node("%WondersLabel") as Label).text == "0",
		"%s | %s | %s" % [(go.get_node("%RocksLabel") as Label).text, (go.get_node("%DistanceLabel") as Label).text, (go.get_node("%TimeLabel") as Label).text])
	check("the game over buttons fade in and are visible", is_equal_approx((go.get_node("%RestartButton") as Control).modulate.a, 1.0))
	world.start_new_run()
	check("restarting hides the game over card immediately", not world.game_over_screen.visible)
	await _free_world(world)

func _test_layout() -> void:
	print("layout at different window sizes")
	Engine.time_scale = 4.0
	var original_size: Vector2i = root.size
	var problems: Array[String] = []
	# Stretching keeps the shape of 16:9 windows, so only different aspect ratios test the layout.
	for window_size in [Vector2i(1280, 720), Vector2i(1024, 600), Vector2i(800, 800), Vector2i(2560, 1080)]:
		root.size = window_size
		await process_frame
		var view: Rect2 = root.get_visible_rect()
		var menu := (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate() as MainMenu
		root.add_child(menu)
		await create_timer(2.8).timeout
		var card := menu.get_node("%MenuCard") as Control
		var title := menu.get_node("Center") as Control
		for item in [["menu card", card], ["title", title]]:
			if not view.grow(2).encloses((item[1] as Control).get_global_rect()):
				problems.append("%s %s outside %s at %s" % [item[0], str((item[1] as Control).get_global_rect()), str(view), str(window_size)])
		menu.queue_free()
		await process_frame

		var world := await _new_world()
		await create_timer(1.6).timeout
		world.game_hud.show_toast("A fairly long message to test how the toast panel fits at every size")
		world.discovery_popup.show_discovery(LandmarkCatalog.get_by_id("lalibela"), 1)
		await create_timer(1.6).timeout
		for item in [["status panel", world.game_hud.get_node("%StatusPanel")], ["pause button", world.game_hud.get_node("%PauseButton")],
				["toast", world.game_hud.get_node("%ToastPanel")], ["banner", world.discovery_popup.get_node("%Panel")]]:
			if not view.grow(2).encloses((item[1] as Control).get_global_rect()):
				problems.append("%s %s outside %s at %s" % [item[0], str((item[1] as Control).get_global_rect()), str(view), str(window_size)])
		world.toggle_pause()
		await create_timer(1.2).timeout
		if not view.grow(2).encloses((world.pause_menu.get_node("%Card") as Control).get_global_rect()):
			problems.append("pause card outside the view at %s" % str(window_size))
		world.toggle_pause()
		world.discovery_manager.health_halves = 1
		world.discovery_manager.register_obstacle_hit()
		await create_timer(1.2).timeout
		if not view.grow(2).encloses((world.game_over_screen.get_node("%Card") as Control).get_global_rect()):
			problems.append("game over card outside the view at %s" % str(window_size))
		await _free_world(world)
	root.size = original_size
	Engine.time_scale = 1.0
	check("every screen stays inside the window at 16:9, 1024x600, square and ultrawide", problems.is_empty(), "\n    ".join(problems))

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

func _test_leaderboard_and_score() -> void:
	print("score and leaderboard")
	var world := await _new_world()
	var dm := world.discovery_manager
	dm.reset_run()
	dm.update_stats(1.0, 100.0)
	check("a fresh run scores its distance only", dm.score() == 100, str(dm.score()))
	dm.register_discovery(LandmarkCatalog.get_by_id("lalibela"))
	dm.register_planet_arrival()
	dm.register_obstacle_destroyed()
	check("wonders, planets, rocks and metres all score",
		dm.score() == DiscoveryManager.POINTS_PER_WONDER + DiscoveryManager.POINTS_PER_PLANET + DiscoveryManager.POINTS_PER_ROCK + 100,
		str(dm.score()))
	check("the stats carry the score", int(dm.stats()["score"]) == dm.score() and int(dm.stats()["planets"]) == 1)
	world.tick(DT)
	check("the HUD shows the score", world.game_hud.get_node("%DistanceLabel").text.contains("pts"))
	await _free_world(world)

	# The table itself.
	var board := Leaderboard.new(TEST_BOARD)
	board.clear()
	check("an empty board has no entries", board.entries.is_empty())
	check("a score of zero never qualifies", not board.qualifies(0))
	check("any score qualifies while there is room", board.qualifies(1) and board.rank_for(1) == 1)
	for i in 10:
		board.add("P%d" % i, (i + 1) * 100, i, i * 10)
	check("the board keeps ten entries, best first", board.entries.size() == 10 and int(board.entries[0]["score"]) == 1000
		and int(board.entries[9]["score"]) == 100)
	check("a score below the tenth place does not qualify", not board.qualifies(100) and not board.qualifies(50) and board.rank_for(50) == 0)
	check("a better score takes its place in the order", board.rank_for(550) == 6 and board.rank_for(5000) == 1)
	check("a tie ranks below the run already there", board.rank_for(1000) == 2)
	check("adding a non-qualifying score does nothing", board.add("LOW", 50, 0, 0) == 0 and board.entries.size() == 10)
	check("a top score is placed first and pushes the last one out", board.add("ACE", 5000, 9, 900) == 1
		and board.entries.size() == 10 and str(board.entries[0]["name"]) == "ACE" and int(board.entries[9]["score"]) == 200)
	var reloaded := Leaderboard.new(TEST_BOARD)
	check("the board is saved and loads back the same", reloaded.entries.size() == 10 and str(reloaded.entries[0]["name"]) == "ACE"
		and int(reloaded.entries[3]["score"]) == int(board.entries[3]["score"]))
	check("blank names become PILOT", Leaderboard.clean_name("   ") == "PILOT")
	check("long names are cut to twelve characters", Leaderboard.clean_name("A very long pilot name").length() <= Leaderboard.NAME_LIMIT)
	check("scores are written with thousands separators",
		Leaderboard.format_score(1234567) == "1,234,567" and Leaderboard.format_score(12) == "12" and Leaderboard.format_score(1000) == "1,000")
	var broken := FileAccess.open(TEST_BOARD, FileAccess.WRITE)
	broken.store_string("this is not json {")
	broken.close()
	check("a damaged file loads as an empty board", Leaderboard.new(TEST_BOARD).entries.is_empty())

	# Game over, top ten: the player is asked for a name and the score is saved.
	board = Leaderboard.new(TEST_BOARD)
	board.clear()
	world = await _new_world()
	_force_game_over(world, 3, 2, 1200.0)
	await create_timer(2.8).timeout
	var screen := world.game_over_screen
	check("a run that makes the board asks for a name", screen.get_node("%NameEntry").visible)
	check("the card shows the score", screen.get_node("%ScoreLabel").text == Leaderboard.format_score(world.discovery_manager.score()),
		screen.get_node("%ScoreLabel").text)
	(screen.get_node("%NameField") as LineEdit).text = "Almaz"
	check("saving returns the place", screen.save_score() == 1)
	check("the score is on the board under that name", str(world.leaderboard.entries[0]["name"]) == "Almaz"
		and int(world.leaderboard.entries[0]["score"]) == world.discovery_manager.score())
	check("the name box goes away once saved", not screen.get_node("%NameEntry").visible)
	check("the leaderboard opens with the new score", (screen.get_node("%LeaderboardPanel") as Control).visible
		and (screen.get_node("%LeaderboardPanel/Center/Card/Content/Rows") as Control).get_child_count() == 10)
	check("a saved score cannot be saved twice", screen.save_score() == 0 and world.leaderboard.entries.size() == 1)
	await _free_world(world)

	# Game over, outside the top ten: no name box and no entry.
	board = Leaderboard.new(TEST_BOARD)
	board.clear()
	for i in 10:
		board.add("TOP%d" % i, 90000 + i, 1, 1)
	world = await _new_world()
	_force_game_over(world, 0, 0, 50.0)
	await create_timer(2.8).timeout
	screen = world.game_over_screen
	check("a score below the tenth place gets no name box", not screen.get_node("%NameEntry").visible)
	check("the card says what it would take", (screen.get_node("%StatusLabel") as Label).visible
		and (screen.get_node("%StatusLabel") as Label).text.contains("90,000"), (screen.get_node("%StatusLabel") as Label).text)
	check("nothing was added to the board", world.leaderboard.entries.size() == 10 and str(world.leaderboard.entries[0]["name"]).begins_with("TOP"))
	await _free_world(world)

	# The menu can open the table.
	var menu := (load(MENU_SCENE) as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	check("the menu has a leaderboard button", menu.get_node("%BoardButton") is Button)
	(menu.get_node("%BoardButton") as Button).pressed.emit()
	await process_frame
	check("pressing it shows ten places", (menu.get_node("%LeaderboardPanel") as Control).visible
		and (menu.get_node("%LeaderboardPanel/Center/Card/Content/Rows") as Control).get_child_count() == 10)
	(menu.get_node("%LeaderboardPanel") as LeaderboardPanel).close()
	check("it closes again", not (menu.get_node("%LeaderboardPanel") as Control).visible)
	menu.free()
	DirAccess.remove_absolute(TEST_BOARD)

	# Every run is different, but a fixed seed still repeats.
	var firsts: Dictionary = {}
	var orientations: Dictionary = {}
	world = await _new_world()
	for seed_number in [11, 22, 33, 44, 55, 66, 77, 88]:
		world.route.begin_run(seed_number)
		firsts[world.route.targets[0].landmark_data.id] = true
		orientations[str(world.route.start_planet.global_basis.get_euler().snapped(Vector3.ONE * 0.05))] = true
	check("random seeds open with different wonders", firsts.size() >= 3, str(firsts.keys()))
	check("random seeds turn the start planet to different sides", orientations.size() >= 6, str(orientations.size()))
	world.route.begin_run()
	check("the fixed seed still opens with Lalibela", world.route.targets[0].landmark_data.id == "lalibela")
	await _free_world(world)

## Ends the run with the given discoveries, rocks destroyed and distance.
func _force_game_over(world: GameManager, wonders: int, rocks: int, distance: float) -> void:
	var dm := world.discovery_manager
	var all: Array[LandmarkData] = LandmarkCatalog.get_all()
	for i in wonders:
		dm.register_discovery(all[i])
	for i in rocks:
		dm.register_obstacle_destroyed()
	dm.update_stats(1.0, distance)
	dm.health_halves = 1
	dm.register_obstacle_hit()

func _test_space_and_wonders() -> void:
	print("space traffic, flight length and wonders")
	var missing: Array[String] = []
	for landmark in LandmarkCatalog.get_all():
		if landmark.load_scene() == null:
			missing.append(landmark.id)
		if landmark.get_fact().length() < 40 or landmark.name.is_empty() or landmark.achievement_title.is_empty():
			missing.append(landmark.id + " text")
	check("all 22 wonders have a scene, a name, a title and a fact", missing.is_empty(), str(missing))
	var tags: Array[String] = []
	for path in ["res://scenes/space/space_nss12.tscn", "res://scenes/space/space_etrss1.tscn", "res://scenes/space/space_selam_relay.tscn"]:
		var craft := (load(path) as PackedScene).instantiate() as SpaceObject
		tags.append((craft.get_node("%Tag") as Label3D).text)
		craft.free()
	check("the Ethiopian craft are NSS-12, ETRSS-1 and the Selam relay", tags == ["NSS-12", "ETRSS-1", "SELAM RELAY"], str(tags))

	var world := await _new_world()
	var route := world.route
	var flights: int = 0
	var with_traffic: int = 0
	var short_flights: int = 0
	var inside_planet: int = 0
	var kinds: Dictionary = {}
	var distance: float = 0.0
	var seen_flights: Dictionary = {}
	while route.planet_index < 8 and distance < 4000.0:
		distance += 20.0
		route.update(distance)
		for seg in route.segments:
			if seg.type != RouteTypes.SegmentType.PLANET_TRANSITION or seen_flights.has(seg.start_distance):
				continue
			seen_flights[seg.start_distance] = true
			flights += 1
			if seg.length < 50.0:
				short_flights += 1
			var crafts: int = 0
			for prop in seg.props:
				if prop is SpaceObject:
					crafts += 1
					kinds[(prop as SpaceObject).display_name] = true
					for planet in route.planets:
						if prop.global_position.distance_to(planet.global_position) < planet.radius + 10.0:
							inside_planet += 1
			if crafts > 0:
				with_traffic += 1
	check("flights between planets were generated", flights >= 3, "%d flights" % flights)
	check("planets are much further apart", short_flights == 0, "%d short flights" % short_flights)
	check("most flights pass space stations or satellites", with_traffic >= maxi(1, flights - 1), "%d of %d" % [with_traffic, flights])
	check("space traffic never sits inside a planet", inside_planet == 0, "%d inside" % inside_planet)
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
	check("popup shows the achievement title", (popup.get_node("%TitleLabel") as Label).text == data.achievement_title)
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
	check("the catalog holds 22 unique wonders", LandmarkCatalog.get_all().size() == 22 and ids.size() == 22,
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
	await create_timer(0.9).timeout
	check("pause menu returns to the main menu", current_scene is MainMenu, str(current_scene))
	check("tree is unpaused after leaving", not paused)
	(current_scene as MainMenu).get_node("%PlayButton").pressed.emit()
	await create_timer(1.2).timeout
	check("Play fades out and starts the game", current_scene is GameManager, str(current_scene))
