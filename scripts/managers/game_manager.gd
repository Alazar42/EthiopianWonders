class_name GameManager
extends Node3D
## Wires the run together: route generation, the runner, the camera, targets, hearts and UI.
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
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/menus/main_menu.tscn"
## Seconds the sky and fog take to blend into the next world's mood during a flight.
@export var mood_blend_time: float = 4.0

var state: GameState.State = GameState.State.MAIN_MENU
var _state_before_pause: GameState.State = GameState.State.RUNNING
var _mood_tween: Tween

func _ready() -> void:
	route.target_spawned.connect(_on_target_spawned)
	route.segment_entered.connect(_on_segment_entered)
	discovery_manager.wonder_discovered.connect(_on_wonder_discovered)
	discovery_manager.wonder_missed.connect(_on_wonder_missed)
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
	game_hud.visible = true
	game_hud.update_wonders(0)
	game_hud.update_distance(0.0)
	game_hud.show_toast("Click the glowing target before you run past it!")
	set_state(GameState.State.RUNNING)

func toggle_pause() -> void:
	if is_playing():
		_state_before_pause = state
		set_state(GameState.State.PAUSED)
		get_tree().paused = true
		pause_menu.show_pause()
	elif state == GameState.State.PAUSED:
		get_tree().paused = false
		pause_menu.hide_pause()
		set_state(_state_before_pause)

func return_to_main_menu() -> void:
	get_tree().paused = false
	if state == GameState.State.PAUSED or state == GameState.State.GAME_OVER:
		set_state(GameState.State.MAIN_MENU)
	get_tree().change_scene_to_file(main_menu_scene)

# --- simulation -------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not is_playing():
		return
	# Generate before moving so the runner can never reach the end of the route.
	route.update(player.distance + player.run_speed * delta)
	player.advance(delta)
	route.update(player.distance)
	for target in route.targets:
		if is_instance_valid(target):
			target.update_window(player.distance)
	if not is_playing():
		return
	discovery_manager.update_stats(delta, player.distance)
	game_hud.update_distance(player.distance)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if is_playing():
			toggle_pause()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.is_action_pressed("interact_target"):
		if is_playing():
			click_at((event as InputEventMouseButton).position)

## Mouse picking. Only a real target hit inside its open window can discover anything.
func click_at(screen_pos: Vector2) -> bool:
	var target: LandmarkTarget = gameplay_camera.pick_target(screen_pos)
	if target == null:
		return false
	return target.attempt_interact(player.distance)

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
	if state == GameState.State.RUNNING:
		set_state(GameState.State.DISCOVERY_FEEDBACK)

func _on_wonder_missed(_landmark: LandmarkData, remaining: int) -> void:
	if remaining > 0:
		game_hud.show_toast("Wonder missed! %d heart%s left" % [remaining, "" if remaining == 1 else "s"])

func _on_popup_closed() -> void:
	if state == GameState.State.DISCOVERY_FEEDBACK:
		set_state(GameState.State.RUNNING)

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
	if segment.type == RouteTypes.SegmentType.PLANET_ARRIVAL and segment.planet is PlanetController:
		game_hud.show_toast("Arrived at %s" % (segment.planet as PlanetController).planet_name)

func _on_game_over(total_wonders: int, distance_m: float, elapsed: float) -> void:
	set_state(GameState.State.GAME_OVER)
	player.stop()
	route.disable_targets()
	discovery_popup.hide_popup(false)
	game_hud.visible = false
	game_over_screen.show_game_over(total_wonders, distance_m, elapsed)
