class_name GameManager
extends Node3D
## Wires the run together: route generation, the ship, the camera, targets, obstacles, health and UI.
## All simulation goes through tick(), so tests can step the game without a real clock.

@export var player: PlayerController
@export var gameplay_camera: GameplayCamera
@export var route: RouteGenerator
@export var world_environment: WorldEnvironment
@export var discovery_manager: DiscoveryManager
@export var fuel: FuelSystem
@export var ammo: AmmoSystem
## Puff of sparks for pickups and shattered rocks.
@export var burst_scene: PackedScene
@export var game_hud: GameHUD
@export var discovery_popup: DiscoveryPopup
@export var pause_menu: PauseMenu
@export var game_over_screen: GameOverScreen
@export var screen_fade: ScreenFade
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/menus/main_menu.tscn"
## Seconds the sky and fog take to blend into the next world's mood during a flight.
@export var mood_blend_time: float = 4.0
@export_group("Fuel")
## Arcade only: the ship burns fuel, gas tanks refill it, and an empty tank ends the run.
@export var fuel_enabled: bool = true
## Seconds the ship must sit still with an empty tank before the run is over.
@export var stall_seconds: float = 0.8
@export_group("Ammo")
## Arcade only: every shot costs a round, and ammo crates give a few back.
@export var ammo_enabled: bool = true
@export_group("Difficulty")
## The run speeds up on every planet from this one on, up to `max_speed_multiplier`.
@export var speed_up_after_planets: int = 3
@export var speed_per_level: float = 0.12
@export var max_speed_multiplier: float = 1.8
@export_group("Run")
## The ship stops while a discovery popup is open so it can be read; off for long automated runs.
@export var pause_on_discovery: bool = true
## Where the local high-score table is kept.
@export var leaderboard_path: String = "user://leaderboard.json"
## Every run gets its own random world; turn off for a fixed seed (tests, debugging).
@export var random_seed_each_run: bool = true

var state: GameState.State = GameState.State.MAIN_MENU
var _state_before_pause: GameState.State = GameState.State.RUNNING
var _mood_tween: Tween
var _runs_started: int = 0
var _stall_time: float = 0.0
var leaderboard: Leaderboard

func _ready() -> void:
	leaderboard = Leaderboard.new(leaderboard_path)
	route.target_spawned.connect(_on_target_spawned)
	route.segment_entered.connect(_on_segment_entered)
	route.tank_spawned.connect(_on_tank_spawned)
	route.crate_spawned.connect(_on_tank_spawned)
	route.health_spawned.connect(_on_tank_spawned)
	ammo.changed.connect(game_hud.update_ammo)
	ammo.low_ammo.connect(_on_low_ammo)
	ammo.emptied.connect(_on_ammo_emptied)
	fuel.changed.connect(game_hud.update_fuel)
	fuel.low_fuel.connect(_on_low_fuel)
	fuel.ran_out.connect(_on_ran_out)
	discovery_manager.wonder_discovered.connect(_on_wonder_discovered)
	discovery_manager.wonder_missed.connect(_on_wonder_missed)
	discovery_manager.obstacle_hit.connect(_on_obstacle_hit)
	discovery_manager.hearts_changed.connect(game_hud.update_hearts)
	discovery_manager.game_over_reached.connect(_on_game_over)
	game_hud.pause_requested.connect(toggle_pause)
	discovery_popup.popup_closed.connect(_on_popup_closed)
	pause_menu.resume_requested.connect(toggle_pause)
	pause_menu.restart_requested.connect(start_new_run)
	pause_menu.main_menu_requested.connect(return_to_main_menu)
	game_over_screen.restart_requested.connect(start_new_run)
	game_over_screen.main_menu_requested.connect(return_to_main_menu)
	start_new_run()

func _exit_tree() -> void:
	GameSound.set_engine(false)

# --- state ----------------------------------------------------------------------------------------

func set_state(new_state: GameState.State) -> bool:
	if new_state == state:
		return true
	if not GameState.can_transition(state, new_state):
		push_warning("Rejected state change %s -> %s" % [
			GameState.state_name(state), GameState.state_name(new_state)])
		return false
	state = new_state
	return true

func is_playing() -> bool:
	return GameState.is_playing(state)

func start_new_run() -> void:
	get_tree().paused = false
	if not set_state(GameState.State.STARTING_RUN):
		return
	discovery_manager.reset_run()
	_stall_time = 0.0
	fuel.reset()
	ammo.reset()
	game_hud.set_fuel_visible(fuel_enabled)
	game_hud.set_ammo_visible(ammo_enabled)
	game_hud.update_level(0)
	route.begin_run(randi() if random_seed_each_run else -1)
	apply_mood(route.start_planet, true)
	player.begin_run(route)
	gameplay_camera.snap()
	pause_menu.hide_pause()
	game_over_screen.hide_screen()
	discovery_popup.hide_popup(false)
	UiCursor.set_crosshair()
	game_hud.visible = true
	game_hud.update_wonders(0)
	game_hud.update_distance(0.0)
	game_hud.play_intro()
	game_hud.show_toast("A and D steer, W and S set speed. Aim and click: every shot counts!")
	if _runs_started > 0:
		screen_fade.blink()
	else:
		screen_fade.fade_in()
	_runs_started += 1
	GameSound.start_music()
	GameSound.set_engine(true)
	set_state(GameState.State.RUNNING)

func toggle_pause() -> void:
	if is_playing():
		_state_before_pause = state
		set_state(GameState.State.PAUSED)
		get_tree().paused = true
		GameSound.set_engine(false)
		pause_menu.show_pause()
	elif state == GameState.State.PAUSED:
		get_tree().paused = false
		pause_menu.hide_pause()
		set_state(_state_before_pause)
		GameSound.set_engine(true)

func return_to_main_menu() -> void:
	GameSound.set_engine(false)
	if state == GameState.State.PAUSED or state == GameState.State.GAME_OVER:
		set_state(GameState.State.MAIN_MENU)
	# Fade to black while the tree is still paused, then switch scenes.
	await screen_fade.fade_out(0.35).finished
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)

# --- simulation -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not is_playing():
		return
	if fuel_enabled:
		_update_fuel(delta)
		if not is_playing():
			return
	# Generate before moving so the ship can never reach the end of the route.
	route.update(player.distance + player.current_speed() * delta)
	player.advance(delta)
	route.update(player.distance)
	for target in route.targets:
		if is_instance_valid(target):
			target.update_window(player.distance)
	for tank in route.fuel_tanks:
		if is_instance_valid(tank):
			tank.update_window(player.distance)
	_check_obstacle_collisions()
	if not is_playing():
		return
	discovery_manager.update_stats(delta, player.distance)
	game_hud.update_distance(player.distance)
	game_hud.update_score(discovery_manager.score())

## Burns fuel. With an empty tank the ship slows down and stops, and once it has stood still for a
## moment the run is over. A tank shot while it is still rolling brings the engine back.
func _update_fuel(delta: float) -> void:
	fuel.drain(delta, player.speed_scale)
	var empty: bool = fuel.is_empty()
	if empty != player.engine_cut:
		player.engine_cut = empty
		GameSound.set_engine(not empty)
	if empty and player.is_stopped():
		_stall_time += delta
		if _stall_time >= stall_seconds:
			discovery_manager.register_out_of_fuel()
	else:
		_stall_time = 0.0

func _check_obstacle_collisions() -> void:
	for obstacle in route.obstacles:
		if not is_instance_valid(obstacle) or not obstacle.is_active():
			continue
		if not obstacle.overlaps(player.distance, player.lane.offset, player.hit_half_width, player.hit_half_depth):
			continue
		# Blinking after a crash keeps one rock from costing more than half a heart.
		if player.is_invulnerable():
			continue
		obstacle.destroy(false)
		player.kick()
		discovery_manager.register_obstacle_hit()
		if not is_playing():
			return

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if is_playing():
			toggle_pause()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_action_pressed("interact_target"):
		if is_playing():
			click_at((event as InputEventMouseButton).position)

## Shooting is by mouse only: aim with the cursor and click. There is no auto-aim.
## Fires a laser at the cursor. A wonder is only discovered by hitting its target inside its open
## window; a rock is destroyed by hitting it; a gas tank or an ammo crate is claimed. Every shot
## costs a round (a crate may be shot for free when the magazine is empty). Returns true only for a
## discovery.
func click_at(screen_pos: Vector2) -> bool:
	var aim: Dictionary = gameplay_camera.aim_ray(screen_pos)
	var tank: FuelTank = aim["tank"]
	if not _spend_ammo(tank is AmmoCrate):
		return false
	player.fire_laser(aim["point"])
	_on_laser_fired()
	var obstacle: Obstacle = aim["obstacle"]
	if obstacle != null:
		blast_obstacle(obstacle)
		return false
	if tank != null:
		shoot_tank(tank)
		return false
	var target: LandmarkTarget = aim["target"]
	if target == null:
		return false
	return target.attempt_interact(player.distance)

## Takes one round for a shot. Returns false, with a dry click, when the magazine is empty.
func _spend_ammo(free: bool) -> bool:
	if not ammo_enabled or free and ammo.is_empty():
		return true
	if ammo.spend():
		return true
	_dry_fire()
	return false

func _dry_fire() -> void:
	GameSound.play(&"empty_click")
	game_hud.pulse_ammo()
	game_hud.show_toast("Out of ammo! Shoot an ammo crate.")
	gameplay_camera.add_shake(0.05)

## Every shot nudges the camera.
func _on_laser_fired() -> void:
	gameplay_camera.add_shake(0.07)
	gameplay_camera.kick_fov(1.3)

## A laser hit a gas tank: it explodes into fuel.
func shoot_tank(tank: FuelTank) -> void:
	tank.collect()

func blast_obstacle(obstacle: Obstacle) -> void:
	if obstacle.is_active():
		_spawn_burst(obstacle.global_position + Vector3.UP * 0.8, Color(1.0, 0.55, 0.25))
		gameplay_camera.add_shake(0.3)
		obstacle.destroy(true)
		discovery_manager.register_obstacle_destroyed()
		GameSound.play(&"explosion")

# --- events -----------------------------------------------------------------------------------------

func _on_tank_spawned(tank: FuelTank) -> void:
	tank.collected.connect(_on_tank_collected, CONNECT_ONE_SHOT)

func _on_tank_collected(tank: FuelTank) -> void:
	if tank is HealthPack:
		var restored: int = discovery_manager.restore_health()
		GameSound.play(&"level_up")
		game_hud.show_toast("Health restored!" if restored > 0 else "Health is already full")
		_spawn_burst(tank.global_position, Color(1.0, 0.4, 0.5))
	elif tank is AmmoCrate:
		var rounds: int = ammo.add(int(tank.amount))
		GameSound.play(&"ammo_pickup")
		game_hud.show_toast("Ammo +%d" % rounds)
		_spawn_burst(tank.global_position, Color(0.4, 0.8, 1.0))
	else:
		var added: float = fuel.add(tank.amount)
		discovery_manager.register_tank()
		GameSound.play(&"fuel_pickup")
		game_hud.show_toast("Fuel +%d" % int(round(added)))
		_spawn_burst(tank.global_position, Color(1.0, 0.6, 0.2))
	gameplay_camera.add_shake(0.2)
	gameplay_camera.kick_fov(2.0)

func _on_low_ammo() -> void:
	if ammo_enabled:
		GameSound.play(&"low_warning")
		game_hud.show_toast("Low ammo! Make every shot count.")

func _on_ammo_emptied() -> void:
	if ammo_enabled:
		game_hud.show_toast("Out of ammo! Shoot an ammo crate.")

## A puff of sparks where something was shot.
func _spawn_burst(at: Vector3, tint: Color) -> void:
	if burst_scene == null or not is_inside_tree():
		return
	var burst := burst_scene.instantiate() as BurstEffect
	burst.tint = tint
	add_child(burst)
	burst.global_position = at

func _on_low_fuel() -> void:
	if fuel_enabled:
		GameSound.play(&"heart_lost")
		game_hud.show_toast("Low fuel! Shoot a gas tank")

func _on_ran_out() -> void:
	if fuel_enabled:
		game_hud.flash_damage()
		game_hud.show_toast("Out of fuel! Shoot a gas tank before you stop!")

func _on_target_spawned(target: LandmarkTarget) -> void:
	target.discovered.connect(_on_target_discovered, CONNECT_ONE_SHOT)
	target.missed.connect(_on_target_missed, CONNECT_ONE_SHOT)

func _on_target_discovered(target: LandmarkTarget) -> void:
	discovery_manager.register_discovery(target.landmark_data)

func _on_target_missed(target: LandmarkTarget) -> void:
	discovery_manager.register_miss(target.landmark_data)

func _on_wonder_discovered(landmark: LandmarkData, total: int) -> void:
	game_hud.update_wonders(total)
	discovery_popup.show_discovery(landmark, total)
	GameSound.play(&"discover")
	if state == GameState.State.RUNNING and pause_on_discovery:
		set_state(GameState.State.DISCOVERY_FEEDBACK)
		GameSound.set_engine(false)
		UiCursor.set_arrow()

func _on_wonder_missed(_landmark: LandmarkData, remaining: float) -> void:
	GameSound.play(&"heart_lost")
	game_hud.flash_damage()
	if remaining > 0.0:
		game_hud.show_toast("Wonder missed! %s hearts left" % _hearts_text(remaining))

func _on_obstacle_hit(_remaining: float) -> void:
	GameSound.play(&"hit")
	game_hud.flash_damage()
	gameplay_camera.add_shake(0.8)

func _hearts_text(hearts: float) -> String:
	return "%d" % int(hearts) if is_equal_approx(hearts, floorf(hearts)) else "%.1f" % hearts

func _on_popup_closed() -> void:
	if state == GameState.State.DISCOVERY_FEEDBACK:
		set_state(GameState.State.RUNNING)
		GameSound.set_engine(true)
		UiCursor.set_crosshair()

## Tints the ambient light and fog to a world's mood, instantly or as a slow blend.
func apply_mood(planet: PlanetController, instant: bool = false) -> void:
	if planet == null or world_environment == null or world_environment.environment == null:
		return
	var env: Environment = world_environment.environment
	if _mood_tween:
		_mood_tween.kill()
	if instant:
		env.ambient_light_color = planet.ambient_color
		env.fog_light_color = planet.fog_color
		return
	_mood_tween = create_tween().set_parallel(true)
	_mood_tween.tween_property(env, "ambient_light_color", planet.ambient_color, mood_blend_time)
	_mood_tween.tween_property(env, "fog_light_color", planet.fog_color, mood_blend_time)

func _on_segment_entered(segment: RouteSegment) -> void:
	if segment.type == RouteTypes.SegmentType.PLANET_TRANSITION and segment.destination_planet is PlanetController:
		apply_mood(segment.destination_planet as PlanetController)
		GameSound.play(&"launch")
	if segment.type == RouteTypes.SegmentType.PLANET_ARRIVAL and segment.planet is PlanetController:
		discovery_manager.register_planet_arrival()
		_apply_difficulty()
		game_hud.show_toast("Arrived at %s" % (segment.planet as PlanetController).planet_name)
		GameSound.play(&"arrive")

## From the third planet on every planet makes the run faster, up to a top speed.
func speed_level() -> int:
	return maxi(0, discovery_manager.planets_reached - speed_up_after_planets + 1)

func _apply_difficulty() -> void:
	var level: int = speed_level()
	var multiplier: float = minf(1.0 + speed_per_level * float(level), max_speed_multiplier)
	var faster: bool = multiplier > player.level_speed_target + 0.001
	player.level_speed_target = multiplier
	game_hud.update_level(level)
	if faster:
		GameSound.play(&"level_up")
		game_hud.show_toast("Faster! Level %d" % level if multiplier < max_speed_multiplier else "Top speed! Level %d" % level)
		gameplay_camera.add_shake(0.25)

func _on_game_over(stats: Dictionary) -> void:
	set_state(GameState.State.GAME_OVER)
	player.engine_cut = false
	player.stop()
	route.disable_targets()
	discovery_popup.hide_popup(false)
	game_hud.visible = false
	GameSound.set_engine(false)
	GameSound.play(&"game_over")
	game_over_screen.show_game_over(stats, leaderboard)
