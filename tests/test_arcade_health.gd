extends SceneTree
## Arcade health pack tests. Run from the project folder:
##   godot --headless --path . --script res://tests/test_arcade_health.gd
## Exits with the number of failed checks.

const DT: float = 1.0 / 60.0
const WORLD_SCENE: String = "res://scenes/game/game_world.tscn"
const TEST_BOARD: String = "user://test_leaderboard_health.json"

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
	await _test_generation()
	await _test_healing()
	await _test_other_modes()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(_failed)

func _new_world() -> GameManager:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate() as GameManager
	world.random_seed_each_run = false
	world.leaderboard_path = TEST_BOARD
	root.add_child(world)
	world.set_process(false)
	await process_frame
	world.route.obstacles_enabled = false
	world.pause_on_discovery = false
	world.fuel_enabled = false
	world.route.fuel_tanks_enabled = false
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

func _test_generation() -> void:
	print("health packs on the route")
	var world := await _new_world()
	_step(world, 1.0)
	world.route.update(world.player.distance + 700.0)
	var packs: Array[HealthPack] = world.route.health_packs
	check("health packs are generated", packs.size() >= 1, str(packs.size()))
	var first: HealthPack = packs[0]
	check("the first one is far from the start", first.route_distance >= 250.0, str(first.route_distance))
	check("a pack is picked like a gas tank", first is FuelTank and first.collision_layer == FuelTank.PICK_LAYER)
	var rare: bool = true
	var last: float = -10000.0
	for pack in packs:
		rare = rare and pack.route_distance - last >= world.route.health_spacing_min - 0.5
		last = pack.route_distance
	check("they are far apart", rare)
	check("they are rarer than gas tanks and ammo crates",
		world.route.health_spacing_min > world.route.ammo_spacing_max and world.route.health_spacing_min > world.route.fuel_spacing_max * 2.0)
	var in_band: bool = true
	for pack in packs:
		in_band = in_band and absf(pack.lane_offset) <= world.route.steer_band - 1.9
	check("they float inside the steering band", in_band)
	var clash: bool = false
	for pack in packs:
		for crate in world.route.ammo_crates:
			if absf(crate.route_distance - pack.route_distance) < 9.0:
				clash = true
		for tank in world.route.fuel_tanks:
			if absf(tank.route_distance - pack.route_distance) < 9.0:
				clash = true
	check("a pack never sits on a tank or a crate", not clash)
	var count_tanks: int = world.route.fuel_tanks.size()
	var count_packs: int = packs.size()
	check("there are far fewer packs than tanks", count_packs * 2 <= maxi(count_tanks, 1) + 1 or count_tanks == 0, "%d vs %d" % [count_packs, count_tanks])
	await _free_world(world)

	# Turning packs off leaves the route as it was.
	var with_packs := await _new_world()
	with_packs.route.update(400.0)
	var a := PackedVector3Array()
	for seg in with_packs.route.segments:
		a.append(seg.positions[seg.positions.size() - 1])
	await _free_world(with_packs)
	var without := await _new_world()
	without.route.health_packs_enabled = false
	without.start_new_run()
	without.route.update(400.0)
	var b := PackedVector3Array()
	for seg in without.route.segments:
		b.append(seg.positions[seg.positions.size() - 1])
	check("health packs never change the route", a == b)
	check("with packs off none exist", without.route.health_packs.is_empty())
	await _free_world(without)

func _test_healing() -> void:
	print("healing")
	var world := await _new_world()
	var dm: DiscoveryManager = world.discovery_manager
	world.route.update(world.player.distance + 700.0)
	var pack: HealthPack = world.route.health_packs[0]
	dm.health_halves = 1
	world.game_hud.update_hearts(1, 6)
	var before_ammo: int = world.ammo.count
	world.player.distance = pack.route_distance - 18.0
	world.player.advance(0.0)
	world.route.update(world.player.distance)
	await physics_frame
	await physics_frame
	world.gameplay_camera.snap()
	var screen: Vector2 = world.gameplay_camera.unproject_position(pack.global_position)
	check("the mouse ray picks the pack", world.gameplay_camera.aim_ray(screen)["tank"] == pack)
	var hearts_seen: Array[int] = [-1]
	dm.hearts_changed.connect(func(current: int, _max: int) -> void: hearts_seen[0] = current)
	world.click_at(screen)
	check("a click shoots the pack", pack.state == FuelTank.State.COLLECTED)
	check("it costs a round like any shot", world.ammo.count == before_ammo - 1)
	check("every heart comes back", dm.health_halves == dm.max_halves() and is_equal_approx(dm.current_hearts, 3.0), str(dm.health_halves))
	check("the HUD is told", hearts_seen[0] == dm.max_halves())
	var heart_icons: Array[Node] = world.game_hud.get_node("%Hearts").get_children()
	var all_full: bool = true
	for heart in heart_icons:
		all_full = all_full and (heart as TextureRect).texture == world.game_hud.heart_full
	check("all three hearts show full", all_full)
	check("the hearts flash to show the heal", (heart_icons[0] as TextureRect).modulate.g > 1.2 or (heart_icons[0] as TextureRect).modulate.r < 0.99)
	check("a toast says so", world.game_hud.get_node("%ToastLabel").text == "Health restored!", world.game_hud.get_node("%ToastLabel").text)
	check("a pack cannot be used twice", pack.state == FuelTank.State.COLLECTED and not pack.collect())
	dm.register_obstacle_hit()
	check("hearts can be lost again afterwards", dm.health_halves == dm.max_halves() - 1)
	# A pack taken at full health is simply used up.
	world.route.update(world.player.distance + 1500.0)
	var spare: HealthPack = null
	for candidate in world.route.health_packs:
		if candidate.is_active() and candidate.route_distance > world.player.distance:
			spare = candidate
			break
	if spare != null:
		dm.health_halves = dm.max_halves()
		spare.collected.connect(world._on_tank_collected)
		var gained: int = dm.restore_health()
		check("at full health nothing is gained", gained == 0)
		spare.collect()
		check("the toast says health was already full", world.game_hud.get_node("%ToastLabel").text == "Health is already full")
	# A pack that is flown past is lost.
	var lost: HealthPack = null
	for candidate in world.route.health_packs:
		if candidate.is_active():
			lost = candidate
			break
	if lost != null:
		world.player.distance = lost.route_distance + 10.0
		world.player.advance(0.0)
		world.tick(DT)
		check("a pack that is flown past is lost", lost.state == FuelTank.State.MISSED)
	# After game over a heal does nothing.
	var dead := DiscoveryManager.new()
	dead.reset_run()
	dead.is_active = false
	dead.health_halves = 0
	check("a finished run cannot be healed", dead.restore_health() == 0 and dead.health_halves == 0)
	dead.free()
	await _free_world(world)

func _test_other_modes() -> void:
	print("arcade only")
	var open_world := (load("res://scenes/openworld/open_world.tscn") as PackedScene).instantiate()
	root.add_child(open_world)
	await process_frame
	check("open world has no health packs", open_world.find_children("*", "HealthPack", true, false).is_empty())
	open_world.queue_free()
	await process_frame
	check("the pack scene loads", (load("res://scenes/fuel/health_pack.tscn") as PackedScene).instantiate() is HealthPack)
