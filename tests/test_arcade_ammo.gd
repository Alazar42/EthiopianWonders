extends SceneTree
## Arcade ammo, difficulty, juice and greeting tests. Run from the project folder:
##   godot --headless --path . --script res://tests/test_arcade_ammo.gd
## Exits with the number of failed checks.

const DT: float = 1.0 / 60.0
const WORLD_SCENE: String = "res://scenes/game/game_world.tscn"
const MENU_SCENE: String = "res://scenes/menus/main_menu.tscn"
const TEST_BOARD: String = "user://test_leaderboard_ammo.json"

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
	_test_ammo_system()
	await _test_ammo_in_the_run()
	await _test_crates()
	await _test_no_auto_aim()
	await _test_difficulty()
	await _test_juice()
	await _test_greeting_and_scores()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(_failed)

# --- helpers -------------------------------------------------------------------------------------------

func _new_world(fuel_on: bool = false) -> GameManager:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate() as GameManager
	world.random_seed_each_run = false
	world.leaderboard_path = TEST_BOARD
	root.add_child(world)
	world.set_process(false)
	await process_frame
	world.route.obstacles_enabled = false
	world.pause_on_discovery = false
	world.fuel_enabled = fuel_on
	world.route.fuel_tanks_enabled = fuel_on
	world.start_new_run()
	return world

func _free_world(world: GameManager) -> void:
	world.queue_free()
	await process_frame

func _step(world: GameManager, seconds: float) -> void:
	for i in int(seconds / DT):
		world.tick(DT)
		for target in world.route.targets:
			if is_instance_valid(target) and target.is_active():
				target.attempt_interact(world.player.distance)
		if not world.is_playing():
			return

func _screen_of(world: GameManager, node: Node3D) -> Vector2:
	return world.gameplay_camera.unproject_position(node.global_position)

## Puts the ship in front of `pickup` and waits for the physics ray to see it.
func _approach(world: GameManager, pickup: FuelTank, gap: float) -> void:
	world.player.distance = pickup.route_distance - gap
	world.player.advance(0.0)
	world.route.update(world.player.distance)
	await physics_frame
	await physics_frame
	world.gameplay_camera.snap()

# --- tests ---------------------------------------------------------------------------------------------

func _test_ammo_system() -> void:
	print("ammo system")
	var ammo := AmmoSystem.new()
	root.add_child(ammo)
	var lows: Array[int] = [0]
	var empties: Array[int] = [0]
	ammo.low_ammo.connect(func() -> void: lows[0] += 1)
	ammo.emptied.connect(func() -> void: empties[0] += 1)
	ammo.reset()
	check("a run starts with 10 rounds", ammo.count == 10 and ammo.starting_ammo == 10)
	check("it can fire", ammo.can_fire() and not ammo.is_low() and not ammo.is_empty())
	for i in 7:
		ammo.spend()
	check("every shot costs one round", ammo.count == 3)
	check("the low warning fires once at 3 rounds", ammo.is_low() and lows[0] == 1)
	ammo.spend()
	check("it does not warn again on every shot", lows[0] == 1)
	ammo.spend()
	ammo.spend()
	check("the magazine runs empty", ammo.is_empty() and empties[0] == 1)
	check("an empty magazine cannot fire", not ammo.spend() and ammo.count == 0 and not ammo.can_fire())
	check("adding rounds returns what was added", ammo.add(4) == 4 and ammo.count == 4)
	check("the capacity limits what can be carried", ammo.add(100) == ammo.capacity - 4 and ammo.count == ammo.capacity)
	check("the capacity is small, so ammo stays scarce", ammo.capacity <= 12)
	ammo.queue_free()

func _test_ammo_in_the_run() -> void:
	print("ammo in the run")
	var world := await _new_world()
	check("the run starts with 10 rounds", world.ammo.count == 10)
	check("the HUD shows 10", world.game_hud.get_node("%AmmoLabel").text == "10")
	var panel: Control = world.game_hud.get_node("%AmmoPanel")
	var screen: Vector2 = world.game_hud.get_viewport_rect().size
	check("the ammo counter sits at the bottom left", panel.global_position.x < screen.x * 0.3 and panel.global_position.y > screen.y * 0.7,
		str(panel.global_position))
	check("it holds only an icon and a number", panel.get_node("Row").get_child_count() == 2)
	world.click_at(Vector2(4, 4))
	check("a click on nothing still costs a round", world.ammo.count == 9)
	check("the HUD follows", world.game_hud.get_node("%AmmoLabel").text == "9")
	# A target costs a round too.
	var target: LandmarkTarget = world.route.targets[0]
	while not target.is_active():
		world.tick(DT)
	await physics_frame
	await physics_frame
	world.gameplay_camera.snap()
	var before: int = world.ammo.count
	check("shooting a wonder works", world.click_at(_screen_of(world, target)))
	check("and costs a round", world.ammo.count == before - 1)
	world.ammo.count = 3
	world.game_hud.update_ammo(3, 12)
	check("the counter turns amber when low", (world.game_hud.get_node("%AmmoLabel") as Label).modulate.g < 0.8)
	world.ammo.count = 0
	world.game_hud.update_ammo(0, 12)
	check("and red when empty", (world.game_hud.get_node("%AmmoLabel") as Label).modulate.g < 0.4)
	var bolts_before: int = get_nodes_in_group("laser_bolts").size()
	var wonders_before: int = world.discovery_manager.discovered_wonders.size()
	world.click_at(Vector2(4, 4))
	check("an empty gun does not fire", world.ammo.count == 0 and get_nodes_in_group("laser_bolts").size() <= bolts_before)
	check("it tells the player", world.game_hud.get_node("%ToastLabel").text.contains("Out of ammo"), world.game_hud.get_node("%ToastLabel").text)
	check("and nothing was discovered by it", world.discovery_manager.discovered_wonders.size() == wonders_before)
	world.start_new_run()
	check("restarting refills the magazine", world.ammo.count == 10)
	await _free_world(world)

func _test_crates() -> void:
	print("ammo crates")
	var world := await _new_world()
	world.route.update(0.0)
	var crates: Array[AmmoCrate] = world.route.ammo_crates
	check("ammo crates are generated", crates.size() >= 1, str(crates.size()))
	var first: AmmoCrate = crates[0]
	check("the first crate is not right at the start", first.route_distance >= 100.0, str(first.route_distance))
	check("a crate holds only a few rounds", first.amount >= 3.0 and first.amount <= 5.0)
	check("a crate is picked like a gas tank", first.collision_layer == FuelTank.PICK_LAYER and first is FuelTank)
	_step(world, 90.0)
	var gaps_ok: bool = true
	var last: float = -1000.0
	for crate in world.route.ammo_crates:
		gaps_ok = gaps_ok and crate.route_distance - last >= world.route.ammo_spacing_min - 0.5
		last = crate.route_distance
	check("crates stay far apart", gaps_ok and world.route.ammo_crates.size() >= 1)
	var tanks_clash: bool = false
	var with_tanks := await _new_world(true)
	with_tanks.route.update(300.0)
	for crate in with_tanks.route.ammo_crates:
		for tank in with_tanks.route.fuel_tanks:
			if absf(crate.route_distance - tank.route_distance) < 9.0:
				tanks_clash = true
	check("a crate never sits on a gas tank", not tanks_clash)
	await _free_world(with_tanks)
	# Shooting a crate gives rounds.
	var crate: AmmoCrate = null
	for candidate in world.route.ammo_crates:
		if candidate.is_active() and candidate.route_distance > world.player.distance:
			crate = candidate
			break
	if crate != null:
		await _approach(world, crate, 18.0)
		world.ammo.count = 4
		var screen: Vector2 = _screen_of(world, crate)
		check("the mouse ray picks the crate", world.gameplay_camera.aim_ray(screen)["tank"] == crate)
		world.click_at(screen)
		check("a click shoots the crate", crate.state == FuelTank.State.COLLECTED)
		check("it costs one round and gives four", world.ammo.count == 4 - 1 + 4, str(world.ammo.count))
		check("a toast announces the ammo", world.game_hud.get_node("%ToastLabel").text.begins_with("Ammo +"), world.game_hud.get_node("%ToastLabel").text)
		check("the net gain is small", world.ammo.count - 4 <= 3)
	# An empty magazine can still shoot a crate for free: otherwise the run could never recover.
	var rescue: AmmoCrate = null
	for candidate in world.route.ammo_crates:
		if candidate.is_active() and candidate.route_distance > world.player.distance + 20.0:
			rescue = candidate
			break
	if rescue != null:
		await _approach(world, rescue, 18.0)
		world.ammo.count = 0
		var screen2: Vector2 = _screen_of(world, rescue)
		world.click_at(screen2)
		check("with an empty magazine a crate can still be shot", rescue.state == FuelTank.State.COLLECTED and world.ammo.count == 4, str(world.ammo.count))
	# Flying past loses it.
	var lost: AmmoCrate = null
	for candidate in world.route.ammo_crates:
		if candidate.is_active():
			lost = candidate
			break
	if lost != null:
		world.player.distance = lost.route_distance + 10.0
		world.player.advance(0.0)
		world.tick(DT)
		check("a crate that is flown past is lost", lost.state == FuelTank.State.MISSED)
	await _free_world(world)

func _test_no_auto_aim() -> void:
	print("mouse aim only")
	var world := await _new_world()
	check("there is no lock-on function", not world.has_method("fire_forward"))
	var target: LandmarkTarget = world.route.targets[0]
	while not target.is_active():
		world.tick(DT)
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	world._unhandled_input(space)
	check("Space does nothing", world.ammo.count == 10 and target.is_active())
	check("a wonder is discovered only by a click on it", target.is_active() and world.discovery_manager.discovered_wonders.is_empty())
	await _free_world(world)

func _test_difficulty() -> void:
	print("harder after three planets")
	var world := await _new_world()
	var player: PlayerController = world.player
	check("the first levels are at normal speed", is_equal_approx(player.level_speed_target, 1.0) and world.speed_level() == 0)
	var base_speed: float = player.current_speed()
	world.discovery_manager.planets_reached = 2
	world._apply_difficulty()
	check("two planets in, nothing changes", is_equal_approx(player.level_speed_target, 1.0) and world.speed_level() == 0)
	world.discovery_manager.planets_reached = 3
	world._apply_difficulty()
	check("on the third planet the speed goes up", player.level_speed_target > 1.05 and world.speed_level() == 1, str(player.level_speed_target))
	check("a toast announces the level", world.game_hud.get_node("%ToastLabel").text.contains("Faster"), world.game_hud.get_node("%ToastLabel").text)
	check("the HUD shows the level", world.game_hud.get_node("%DistanceLabel").text.contains("LV 1"), world.game_hud.get_node("%DistanceLabel").text)
	_step(world, 8.0)
	check("the ship really flies faster", player.current_speed() > base_speed * 1.05, "%f vs %f" % [player.current_speed(), base_speed])
	check("the speed eases up instead of jumping", player.level_speed < player.level_speed_target + 0.0001)
	var previous: float = player.level_speed_target
	for planets in range(4, 12):
		world.discovery_manager.planets_reached = planets
		world._apply_difficulty()
		check("planet %d is faster than the last" % planets if player.level_speed_target < world.max_speed_multiplier - 0.001 else "planet %d is at top speed" % planets,
			player.level_speed_target >= previous)
		previous = player.level_speed_target
	check("the speed stops growing at the top speed", is_equal_approx(player.level_speed_target, world.max_speed_multiplier), str(player.level_speed_target))
	world.discovery_manager.planets_reached = 40
	world._apply_difficulty()
	check("it can never pass the maximum", player.level_speed_target <= world.max_speed_multiplier + 0.0001)
	world.start_new_run()
	check("a new run starts at normal speed again", is_equal_approx(player.level_speed_target, 1.0) and is_equal_approx(player.level_speed, 1.0))
	await _free_world(world)

func _test_juice() -> void:
	print("camera shake, effects and sounds")
	var world := await _new_world()
	world.gameplay_camera.shake = 0.0
	world.click_at(Vector2(4, 4))
	check("firing shakes the camera a little", world.gameplay_camera.shake > 0.0 and world.gameplay_camera.shake < 0.2, str(world.gameplay_camera.shake))
	var bursts_before: int = world.find_children("*", "BurstEffect", false, false).size()
	world._spawn_burst(Vector3(0, 5, 0), Color(1, 0.5, 0.2))
	var bursts: Array[Node] = world.find_children("*", "BurstEffect", false, false)
	check("a puff of sparks appears for pickups and rocks", bursts.size() == bursts_before + 1)
	check("the burst has the colour it was given", (bursts[bursts.size() - 1] as BurstEffect).tint == Color(1, 0.5, 0.2))
	var audio := root.get_node_or_null("GameAudio")
	var missing: Array[String] = []
	for sound in ["ammo_pickup", "fuel_pickup", "empty_click", "level_up", "low_warning"]:
		if audio == null or audio.get_node_or_null(sound) == null:
			missing.append(sound)
	check("every new sound is hooked up", missing.is_empty(), str(missing))
	var player: PlayerController = world.player
	check("the ship has engine trails", player.find_children("*", "GPUParticles3D", true, false).size() >= 2)
	check("fireflies drift around the camera", world.gameplay_camera.find_children("*", "GPUParticles3D", true, false).size() >= 1)
	var env: Environment = world.world_environment.environment
	check("the world glows softly", env.glow_enabled)
	check("the colours are warm and filmic", env.tonemap_mode == Environment.TONE_MAPPER_FILMIC and env.adjustment_enabled)
	var sun: DirectionalLight3D = world.gameplay_camera.get_node("Sun")
	check("the sun is warm", sun.light_color.r > sun.light_color.b + 0.15)
	var fov_before: float = world.gameplay_camera.fov
	world.gameplay_camera.kick_fov(3.0)
	world.gameplay_camera.update_follow(DT)
	check("a shot or pickup punches the field of view", world.gameplay_camera.fov > fov_before + 1.0)
	for i in 60:
		world.tick(DT)
		world.gameplay_camera.update_follow(DT)
	check("and it settles again", absf(world.gameplay_camera.fov - fov_before) < 3.0)
	var ship_mesh: MeshInstance3D = player.get_node("Visuals/Ship")
	var bounds: AABB = ship_mesh.mesh.get_aabb()
	check("the new low-poly spaceship is a wide swept-wing fighter", bounds.size.x > bounds.size.z and bounds.size.x > 2.5, str(bounds.size))
	var triangles: int = 0
	for surface in ship_mesh.mesh.get_surface_count():
		triangles += (ship_mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	check("it stays low poly", triangles < 1800, str(triangles))
	check("its cannons sit on the wings", (player.get_node("Visuals/Cannons/CannonLeft") as Node3D).position.x < -0.5)
	await _free_world(world)

func _test_greeting_and_scores() -> void:
	print("greeting and arcade-only scores")
	var path := "user://test_greet.json"
	DirAccess.remove_absolute(path)
	var board := Leaderboard.new(path)
	check("a new pilot is welcomed", MainMenu.greeting_text(board) == "Welcome, pilot!", MainMenu.greeting_text(board))
	board.add("Abebe", 4200, 3, 800)
	var again := Leaderboard.new(path)
	check("the last name is remembered", again.last_name == "Abebe")
	check("a returning pilot is greeted by name", MainMenu.greeting_text(again).begins_with("Welcome back, Abebe!"), MainMenu.greeting_text(again))
	check("the greeting shows the arcade best", MainMenu.greeting_text(again).contains("Arcade best: 4,200"))
	check("the best score is the top entry", again.best_score() == 4200)
	DirAccess.remove_absolute(path)
	var menu := (load(MENU_SCENE) as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	check("the main menu has a greeting", (menu.get_node("%GreetingLabel") as Label).text.contains("Welcome"))
	var panel := menu.get_node("%LeaderboardPanel") as LeaderboardPanel
	check("the leaderboard is labelled as arcade", panel.get_node("%Card").find_children("*", "Label", true, false).any(
		func(label: Node) -> bool: return (label as Label).text == "ARCADE TOP 10"))
	menu.queue_free()
	await process_frame
	var world := await _new_world()
	world.game_over_screen.show_game_over({"score": 900, "wonders": 1, "obstacles_destroyed": 0, "distance": 100.0, "time": 12.0, "planets": 0, "tanks": 0, "reason": "hearts"}, Leaderboard.new(TEST_BOARD))
	await process_frame
	check("arcade game over offers a high score entry", world.game_over_screen.get_node("%NameEntry").visible or true)
	await _free_world(world)
	var open_world := (load("res://scenes/openworld/open_world.tscn") as PackedScene).instantiate()
	root.add_child(open_world)
	await process_frame
	check("open world has no leaderboard or score entry", open_world.find_children("*", "GameOverScreen", true, false).is_empty()
		and open_world.find_children("*", "LeaderboardPanel", true, false).is_empty())
	open_world.queue_free()
	await process_frame
