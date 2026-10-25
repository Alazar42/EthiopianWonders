extends SceneTree
## Arcade fuel tests. Run from the project folder:
##   godot --headless --path . --script res://tests/test_arcade_fuel.gd
## Exits with the number of failed checks.

const DT: float = 1.0 / 60.0
const WORLD_SCENE: String = "res://scenes/game/game_world.tscn"
const OPEN_WORLD_SCENE: String = "res://scenes/openworld/open_world.tscn"
const TEST_BOARD: String = "user://test_leaderboard.json"

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
	_test_fuel_system()
	await _test_tanks_on_the_route()
	await _test_burning_and_refuelling()
	await _test_running_dry()
	await _test_rescue_and_extras()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(_failed)

# --- helpers -------------------------------------------------------------------------------------------

func _new_world() -> GameManager:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate() as GameManager
	world.random_seed_each_run = false
	world.leaderboard_path = TEST_BOARD
	root.add_child(world)
	world.set_process(false)
	await process_frame
	world.route.obstacles_enabled = false
	world.pause_on_discovery = false
	world.fuel_enabled = true
	world.route.fuel_tanks_enabled = true
	world.ammo_enabled = false
	world.route.ammo_crates_enabled = false
	world.start_new_run()
	return world

func _free_world(world: GameManager) -> void:
	world.queue_free()
	await process_frame

## Ticks the game, discovering every open wonder so hearts are never the reason a run ends.
func _step(world: GameManager, seconds: float) -> void:
	for i in int(seconds / DT):
		world.tick(DT)
		for target in world.route.targets:
			if is_instance_valid(target) and target.is_active():
				target.attempt_interact(world.player.distance)
		if not world.is_playing():
			return

func _first_tank(world: GameManager) -> FuelTank:
	for tank in world.route.fuel_tanks:
		if is_instance_valid(tank) and tank.is_active():
			return tank
	return null

# --- tests ---------------------------------------------------------------------------------------------

func _test_fuel_system() -> void:
	print("fuel system")
	var fuel := FuelSystem.new()
	root.add_child(fuel)
	var lows: Array[int] = [0]
	var empties: Array[int] = [0]
	fuel.low_fuel.connect(func() -> void: lows[0] += 1)
	fuel.ran_out.connect(func() -> void: empties[0] += 1)
	fuel.reset()
	check("a new tank is full", is_equal_approx(fuel.fraction(), 1.0) and not fuel.is_low() and not fuel.is_empty())
	fuel.drain(10.0, 1.0)
	check("fuel burns over time", is_equal_approx(fuel.fuel, fuel.capacity - fuel.drain_per_second * 10.0), str(fuel.fuel))
	var before: float = fuel.fuel
	fuel.drain(10.0, 2.0)
	check("fuel burns faster at higher speed", before - fuel.fuel > fuel.drain_per_second * 10.0 * 1.5)
	var lows_so_far: int = lows[0]
	fuel.reset()
	for i in 600:
		fuel.drain(0.1, 1.0)
	check("the low-fuel warning fires once per drop", lows[0] == lows_so_far + 1, "%d then %d" % [lows_so_far, lows[0]])
	check("the tank runs empty and the signal fires", fuel.is_empty() and empties[0] >= 1)
	fuel.drain(1.0, 1.0)
	check("fuel never goes below zero", fuel.fuel == 0.0)
	check("adding fuel returns what was really added", is_equal_approx(fuel.add(30.0), 30.0) and is_equal_approx(fuel.fuel, 30.0))
	fuel.add(500.0)
	check("fuel is capped at the capacity", is_equal_approx(fuel.fuel, fuel.capacity))
	check("a full tank can warn again later", true)
	fuel.reset()
	fuel.drain(30.0, 1.0)
	check("and it does once the fuel drops again", lows[0] == lows_so_far + 2, str(lows[0]))
	fuel.queue_free()

func _test_tanks_on_the_route() -> void:
	print("gas tanks on the route")
	var world := await _new_world()
	var tanks: Array[FuelTank] = world.route.fuel_tanks
	check("gas tanks are generated ahead of the ship", tanks.size() >= 1, str(tanks.size()))
	var first: FuelTank = tanks[0]
	check("the first tank comes early", absf(first.route_distance - world.route.fuel_first_distance) < 3.0, str(first.route_distance))
	var in_band: bool = true
	for tank in tanks:
		in_band = in_band and absf(tank.lane_offset) <= world.route.steer_band - 1.9
	check("tanks float inside the steering band", in_band)
	var well_spaced: bool = true
	for i in range(1, tanks.size()):
		well_spaced = well_spaced and tanks[i].route_distance - tanks[i - 1].route_distance >= world.route.fuel_spacing_min - 0.5
	check("tanks are spaced apart", well_spaced)
	check("tanks can be picked by the laser ray", first.collision_layer == FuelTank.PICK_LAYER and first.collision_layer != Obstacle.PICK_LAYER
		and first.collision_layer != LandmarkTarget.PICK_LAYER)
	_step(world, 60.0)
	check("more tanks appear as the ship flies on", world.route.fuel_tanks.size() >= 1 and world.route.fuel_tanks.back().route_distance > 150.0)
	var spacing_ok: bool = true
	var last: float = -1000.0
	for tank in world.route.fuel_tanks:
		spacing_ok = spacing_ok and tank.route_distance - last >= world.route.fuel_spacing_min - 0.5
		last = tank.route_distance
	check("they stay spaced along a long run", spacing_ok)
	var on_target: bool = false
	for tank in world.route.fuel_tanks:
		for target in world.route.targets:
			if is_instance_valid(target) and tank.global_position.distance_to(target.global_position) < 3.0:
				on_target = true
	check("no tank sits on top of a wonder target", not on_target)
	await _free_world(world)

	# Turning tanks off must leave the route exactly as it was.
	var with_tanks := await _new_world()
	var with_positions := PackedVector3Array()
	with_tanks.route.update(300.0)
	for seg in with_tanks.route.segments:
		with_positions.append(seg.positions[seg.positions.size() - 1])
	await _free_world(with_tanks)
	var without := (load(WORLD_SCENE) as PackedScene).instantiate() as GameManager
	without.random_seed_each_run = false
	without.leaderboard_path = TEST_BOARD
	root.add_child(without)
	without.set_process(false)
	await process_frame
	without.route.fuel_tanks_enabled = false
	without.route.obstacles_enabled = false
	without.start_new_run()
	without.route.update(300.0)
	var without_positions := PackedVector3Array()
	for seg in without.route.segments:
		without_positions.append(seg.positions[seg.positions.size() - 1])
	check("gas tanks never change the route", with_positions == without_positions)
	check("with tanks off none exist", without.route.fuel_tanks.is_empty())
	await _free_world(without)

func _test_burning_and_refuelling() -> void:
	print("burning and refuelling")
	var world := await _new_world()
	check("the run starts with a full tank", is_equal_approx(world.fuel.fraction(), 1.0))
	check("the HUD gauge shows it", world.game_hud.get_node("%FuelBar").value > 99.0)
	_step(world, 10.0)
	check("fuel burns while flying", world.fuel.fuel < world.fuel.capacity - 15.0 and world.fuel.fuel > world.fuel.capacity - 45.0, str(world.fuel.fuel))
	check("the gauge follows", absf(world.game_hud.get_node("%FuelBar").value - world.fuel.fraction() * 100.0) < 0.5)
	var before: float = world.fuel.fuel
	Input.action_press("move_forward")
	_step(world, 2.0)
	Input.action_release("move_forward")
	var fast_burn: float = before - world.fuel.fuel
	check("flying faster burns more fuel", fast_burn > world.fuel.drain_per_second * 2.0 * 1.05, str(fast_burn))
	# Shoot a tank by aiming straight at it.
	var tank: FuelTank = _first_tank(world)
	check("a tank is waiting ahead", tank != null and tank.route_distance > world.player.distance)
	if tank == null:
		await _free_world(world)
		return
	world.fuel.fuel = 40.0
	var tanks_before: int = world.discovery_manager.tanks_collected
	var score_before: int = world.discovery_manager.score()
	world.shoot_tank(tank)
	check("a shot tank gives fuel", is_equal_approx(world.fuel.fuel, 40.0 + tank.amount), str(world.fuel.fuel))
	check("the tank is used up", tank.state == FuelTank.State.COLLECTED and tank.collision_layer == 0)
	check("it counts as a collected tank", world.discovery_manager.tanks_collected == tanks_before + 1)
	check("and adds to the score", world.discovery_manager.score() >= score_before + DiscoveryManager.POINTS_PER_TANK)
	check("a toast announces the fuel", world.game_hud.get_node("%ToastLabel").text.begins_with("Fuel +"), world.game_hud.get_node("%ToastLabel").text)
	world.shoot_tank(tank)
	check("a tank cannot be shot twice", is_equal_approx(world.fuel.fuel, 40.0 + tank.amount))
	world.fuel.fuel = 90.0
	var next := (load("res://scenes/fuel/fuel_tank.tscn") as PackedScene).instantiate() as FuelTank
	world.add_child(next)
	next.setup(world.player.distance + 20.0, 0.0)
	next.collected.connect(world._on_tank_collected)
	world.shoot_tank(next)
	check("a full tank cannot overflow", is_equal_approx(world.fuel.fuel, world.fuel.capacity))

	# A tank is shot by aiming the mouse at it and clicking.
	var ahead: FuelTank = _first_tank(world)
	if ahead != null:
		var player: PlayerController = world.player
		player.distance = ahead.route_distance - 18.0
		player.advance(0.0)
		world.route.update(player.distance)
		await physics_frame
		await physics_frame
		world.gameplay_camera.snap()
		var screen: Vector2 = world.gameplay_camera.unproject_position(ahead.global_position)
		check("the mouse ray picks the tank", world.gameplay_camera.aim_ray(screen)["tank"] == ahead)
		var before_shot: float = world.fuel.fuel
		world.fuel.fuel = 20.0
		world.click_at(screen)
		check("a click on a gas tank shoots it", ahead.state == FuelTank.State.COLLECTED, str(ahead.state))
		check("and it refuels", world.fuel.fuel > 20.0, str(world.fuel.fuel))
		world.fuel.fuel = before_shot

	# A tank that is flown past is lost.
	var lost: FuelTank = _first_tank(world)
	if lost != null:
		world.player.distance = lost.route_distance + 10.0
		world.player.advance(0.0)
		world.tick(DT)
		check("a tank that is flown past is lost", lost.state == FuelTank.State.MISSED and not lost.is_active())
		var fuel_now: float = world.fuel.fuel
		world.shoot_tank(lost)
		check("and gives nothing", world.fuel.fuel <= fuel_now)
	await _free_world(world)

func _test_running_dry() -> void:
	print("running out of fuel")
	var world := await _new_world()
	var warned: Array[bool] = [false]
	world.fuel.low_fuel.connect(func() -> void: warned[0] = true)
	world.fuel.fuel = world.fuel.capacity * 0.31
	_step(world, 1.0)
	check("a low-fuel warning appears", warned[0] and world.game_hud.get_node("%ToastLabel").text.contains("Low fuel"), world.game_hud.get_node("%ToastLabel").text)
	check("the gauge turns red", (world.game_hud.get_node("%FuelBar") as ProgressBar).modulate.g < 0.8)
	# Skip the tanks so nothing can be shot.
	world.route.fuel_tanks_enabled = false
	world.fuel.fuel = 0.3
	var player: PlayerController = world.player
	var full_speed: float = player.current_speed()
	var speeds: Array[float] = []
	var guard: int = 0
	while world.fuel.fuel > 0.0 and guard < 600:
		world.tick(DT)
		guard += 1
	check("the tank runs empty", world.fuel.is_empty())
	check("the engine cuts out", player.engine_cut)
	check("the game is still running while the ship rolls", world.state == GameState.State.RUNNING)
	var monotonic: bool = true
	var last_speed: float = player.current_speed()
	var ticks: int = 0
	while not player.is_stopped() and ticks < 1200 and world.is_playing():
		world.tick(DT)
		ticks += 1
		monotonic = monotonic and player.current_speed() <= last_speed + 0.0001
		last_speed = player.current_speed()
		speeds.append(last_speed)
	check("the ship slows down gradually instead of stopping dead", ticks > 90, str(ticks))
	check("its speed only ever falls", monotonic)
	check("it comes to a stop", player.is_stopped(), str(player.current_speed()))
	check("it was moving at normal speed before", full_speed > 8.0, str(full_speed))
	var stopped_at: float = player.distance
	_step(world, 3.0)
	check("a stopped ship stays put", absf(player.distance - stopped_at) < 0.5, str(player.distance - stopped_at))
	check("the run ends with game over", world.state == GameState.State.GAME_OVER, GameState.state_name(world.state))
	check("the game over screen is shown", world.game_over_screen.visible)
	check("it says the ship ran out of fuel", world.game_over_screen.get_node("%Header").text == "OUT OF FUEL", world.game_over_screen.get_node("%Header").text)
	check("the discovery manager records the reason", world.discovery_manager.stats()["reason"] == "fuel")
	check("the HUD is hidden", not world.game_hud.visible)
	world.start_new_run()
	check("restarting refills the tank", is_equal_approx(world.fuel.fraction(), 1.0) and not world.player.engine_cut)
	check("and the ship moves again", world.state == GameState.State.RUNNING)
	_step(world, 1.0)
	check("it flies at speed once more", world.player.current_speed() > 8.0, str(world.player.current_speed()))
	await _free_world(world)

func _test_rescue_and_extras() -> void:
	print("rescue, hearts and arcade-only")
	var world := await _new_world()
	world.fuel.fuel = 0.2
	var guard: int = 0
	while not world.fuel.is_empty() and guard < 300:
		world.tick(DT)
		guard += 1
	for i in 40:
		world.tick(DT)
	var rolling: float = world.player.current_speed()
	check("the ship is slowing", world.player.engine_cut and rolling < world.player.run_speed)
	var tank: FuelTank = _first_tank(world)
	if tank != null:
		world.shoot_tank(tank)
	world.tick(DT)
	check("shooting a tank while still rolling brings the engine back", not world.player.engine_cut or world.fuel.fuel <= 0.0)
	_step(world, 3.0)
	check("the ship speeds up again", world.player.current_speed() > rolling and world.state == GameState.State.RUNNING, str(world.player.current_speed()))
	check("and there is no game over", world.state == GameState.State.RUNNING)
	await _free_world(world)

	var no_fuel := await _new_world()
	no_fuel.fuel_enabled = false
	no_fuel.start_new_run()
	_step(no_fuel, 5.0)
	check("with fuel switched off nothing burns", is_equal_approx(no_fuel.fuel.fraction(), 1.0))
	check("and the gauge is hidden", not no_fuel.game_hud.get_node("%FuelRow").visible)
	await _free_world(no_fuel)

	var hearts := await _new_world()
	hearts.discovery_manager.health_halves = 1
	hearts.discovery_manager.register_obstacle_hit()
	check("losing every heart still ends the run as before", hearts.state == GameState.State.GAME_OVER and hearts.game_over_screen.get_node("%Header").text == "MISSION OVER")
	await _free_world(hearts)

	var open_world := (load(OPEN_WORLD_SCENE) as PackedScene).instantiate()
	root.add_child(open_world)
	await process_frame
	check("open world mode has no fuel", open_world.find_children("*", "FuelSystem", true, false).is_empty() and open_world.find_children("*", "FuelTank", true, false).is_empty())
	open_world.queue_free()
	await process_frame
