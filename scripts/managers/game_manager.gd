class_name GameManager
extends Node3D
## Wires the run together: route generation, the ship, the camera, targets, obstacles, health and UI.
## All simulation goes through tick(), so tests can step the game without a real clock.

@export var player: PlayerController
@export var gameplay_camera: GameplayCamera
@export var route: RouteGenerator
@export var world_environment: WorldEnvironment
@export var discovery_manager: DiscoveryManager
@export var game_hud: GameHUD
@export var discovery_popup: DiscoveryPopup
@export var pause_menu: PauseMenu
@export var game_over_screen: GameOverScreen
@export var screen_fade: ScreenFade
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/menus/main_menu.tscn"
## Seconds the sky and fog take to blend into the next world's mood during a flight.
@export var mood_blend_time: float = 4.0
@export_group("Lasers")
## Half-angle of the cone ahead of the ship that Space aims at.
@export_range(5.0, 60.0) var aim_assist_degrees: float = 30.0
@export var aim_assist_range: float = 90.0
## Rocks are only locked on to when they are this close.
@export var obstacle_lock_range: float = 45.0

## The ship stops while a discovery popup is open so it can be read; off for long automated runs.
@export var pause_on_discovery: bool = true

var state: GameState.State = GameState.State.MAIN_MENU
var _state_before_pause: GameState.State = GameState.State.RUNNING
var _mood_tween: Tween
var _runs_started: int = 0

func _ready() -> void:
	route.target_spawned.connect(_on_target_spawned)
	route.segment_entered.connect(_on_segment_entered)
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
	route.begin_run()
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
	game_hud.show_toast("Shoot the glowing target, and blast the rocks in your way!")
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
	# Generate before moving so the ship can never reach the end of the route.
	route.update(player.distance + player.run_speed * delta)
	player.advance(delta)
	route.update(player.distance)
	for target in route.targets:
		if is_instance_valid(target):
			target.update_window(player.distance)
	_check_obstacle_collisions()
	if not is_playing():
		return
	discovery_manager.update_stats(delta, player.distance)
	game_hud.update_distance(player.distance)

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
	elif event.is_action_pressed("fire") and not event.is_echo():
		if is_playing():
			fire_forward()

## Fires a laser at the cursor. A wonder is only discovered by hitting its target inside its open
## window; a rock is destroyed by hitting it. Returns true only for a discovery.
func click_at(screen_pos: Vector2) -> bool:
	var aim: Dictionary = gameplay_camera.aim_ray(screen_pos)
	player.fire_laser(aim["point"])
	var obstacle: Obstacle = aim["obstacle"]
	if obstacle != null:
		blast_obstacle(obstacle)
		return false
	var target: LandmarkTarget = aim["target"]
	if target == null:
		return false
	return target.attempt_interact(player.distance)

## Fires straight ahead. Open wonder targets in the aim-assist cone come first; otherwise it locks
## on to the nearest rock ahead. Returns true only for a discovery.
func fire_forward() -> bool:
	var forward: Vector3 = player.get_forward()
	var best: LandmarkTarget = null
	var best_angle: float = deg_to_rad(aim_assist_degrees)
	for target in route.targets:
		if not is_instance_valid(target) or not target.is_active():
			continue
		var to_target: Vector3 = target.global_position - player.global_position
		if to_target.length() > aim_assist_range:
			continue
		var angle: float = forward.angle_to(to_target)
		if angle < best_angle:
			best_angle = angle
			best = target
	if best != null:
		player.fire_laser(best.global_position)
		return best.attempt_interact(player.distance)
	var rock: Obstacle = _nearest_obstacle_ahead()
	if rock != null:
		player.fire_laser(rock.global_position)
		blast_obstacle(rock)
		return false
	player.fire_laser(player.global_position + forward * 80.0)
	return false

func blast_obstacle(obstacle: Obstacle) -> void:
	if obstacle.is_active():
		obstacle.destroy(true)
		discovery_manager.register_obstacle_destroyed()
		GameSound.play(&"explosion")

func _nearest_obstacle_ahead() -> Obstacle:
	var best: Obstacle = null
	var best_distance: float = obstacle_lock_range
	for obstacle in route.obstacles:
		if not is_instance_valid(obstacle) or not obstacle.is_active():
			continue
		var ahead: float = obstacle.route_distance - player.distance
		if ahead < 0.0 or ahead >= best_distance:
			continue
		if absf(obstacle.lane_offset - player.lane.offset) > route.lane_width * 1.6:
			continue
		best_distance = ahead
		best = obstacle
	return best

# --- events -----------------------------------------------------------------------------------------

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
		game_hud.show_toast("Arrived at %s" % (segment.planet as PlanetController).planet_name)
		GameSound.play(&"arrive")

func _on_game_over(stats: Dictionary) -> void:
	set_state(GameState.State.GAME_OVER)
	player.stop()
	route.disable_targets()
	discovery_popup.hide_popup(false)
	game_hud.visible = false
	GameSound.set_engine(false)
	GameSound.play(&"game_over")
	game_over_screen.show_game_over(stats)
