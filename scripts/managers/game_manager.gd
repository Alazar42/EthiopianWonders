class_name GameManager
extends Node3D

@export var player: PlayerController
@export var gameplay_camera: GameplayCamera
@export var initial_planet: SphericalPlanet
@export var all_planets: Array[SphericalPlanet] = []

@onready var discovery_manager: DiscoveryManager = $DiscoveryManager
@onready var game_hud: GameHUD = $UI/GameHUD
@onready var discovery_popup: DiscoveryPopup = $UI/DiscoveryPopup
@onready var pause_menu: PauseMenu = $UI/PauseMenu
@onready var game_over_screen: GameOverScreen = $UI/GameOverScreen

var current_state: GameState.State = GameState.State.RUNNING
var _planet_distance: float = 0.0
var _transition_trigger_distance: float = 85.0
var _current_target: LandmarkTarget = null

func _ready() -> void:
	_setup_connections()
	start_new_run()

func _setup_connections() -> void:
	if discovery_manager:
		discovery_manager.wonder_discovered.connect(_on_wonder_discovered)
		discovery_manager.wonder_missed.connect(_on_wonder_missed)
		discovery_manager.hearts_changed.connect(_on_hearts_changed)
		discovery_manager.game_over_reached.connect(_on_game_over_reached)
	
	if player:
		player.distance_updated.connect(_on_player_distance_updated)
		player.planet_arrived.connect(_on_planet_arrived)
	
	if game_hud:
		game_hud.pause_requested.connect(_toggle_pause)
	
	if pause_menu:
		pause_menu.resume_requested.connect(_resume_game)
		pause_menu.restart_requested.connect(start_new_run)
		pause_menu.main_menu_requested.connect(_return_to_main_menu)
	
	if game_over_screen:
		game_over_screen.restart_requested.connect(start_new_run)
		game_over_screen.main_menu_requested.connect(_return_to_main_menu)

func _unhandled_input(event: InputEvent) -> void:
	if current_state == GameState.State.RUNNING:
		if event.is_action_pressed("pause_game"):
			_toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact_target") and event is InputEventMouseButton:
			_handle_target_click(event.position)
	elif current_state == GameState.State.PAUSED:
		if event.is_action_pressed("pause_game"):
			_resume_game()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if current_state == GameState.State.RUNNING and player and not player.is_transitioning:
		discovery_manager.update_stats(delta, player.distance_travelled)
		_planet_distance += player.run_speed * delta
		
		# Check interaction deadline for current planet landmark
		if _current_target and is_instance_valid(_current_target):
			# If player runs past 60 meters on this planet without clicking, it's missed!
			if _planet_distance > 60.0 and _current_target.is_active and not _current_target.is_discovered:
				_current_target.mark_missed()
		
		# Check if ready to launch to next planet
		if _planet_distance >= _transition_trigger_distance and player.current_planet:
			if player.current_planet.next_planet:
				player.launch_to_planet(player.current_planet.next_planet)
				_planet_distance = 0.0

func _handle_target_click(screen_pos: Vector2) -> void:
	if not gameplay_camera or not player:
		return
	
	var target = gameplay_camera.pick_landmark_target(screen_pos)
	if target and is_instance_valid(target) and target.is_active:
		target.attempt_interact(player.global_position)

func _on_planet_arrived(planet: SphericalPlanet) -> void:
	_planet_distance = 0.0
	_setup_planet_target(planet)
	if game_hud:
		game_hud.show_toast("✦ Arrived at %s! ✦" % planet.planet_name, true)

func _setup_planet_target(planet: SphericalPlanet) -> void:
	if not planet:
		return
	_current_target = planet.active_target
	if _current_target and is_instance_valid(_current_target):
		_current_target.target_discovered.connect(func(lm):
			discovery_manager.register_discovery(lm)
		)
		_current_target.target_missed.connect(func(lm):
			discovery_manager.register_miss(lm)
		)

func _on_wonder_discovered(landmark: LandmarkData, total_count: int) -> void:
	if game_hud:
		game_hud.update_wonders_count(total_count)
		game_hud.show_toast("✓ Discovered: %s!" % landmark.name, true)
	if discovery_popup:
		discovery_popup.show_discovery(landmark, total_count)

func _on_wonder_missed(landmark: LandmarkData, remaining_hearts: int) -> void:
	if game_hud:
		game_hud.show_toast("✗ Landmark Missed! (%d hearts left)" % remaining_hearts, false)

func _on_hearts_changed(current: int, max_h: int) -> void:
	if game_hud:
		game_hud.update_hearts(current, max_h)

func _on_player_distance_updated(dist: float) -> void:
	if game_hud:
		game_hud.update_distance(dist)

func _on_game_over_reached(total_wonders: int, distance_m: float, elapsed_sec: float) -> void:
	current_state = GameState.State.GAME_OVER
	if player:
		player.is_running = false
	if game_hud:
		game_hud.visible = false
	if discovery_popup:
		discovery_popup.hide_popup()
	if game_over_screen:
		game_over_screen.show_game_over(total_wonders, distance_m, elapsed_sec)

func _toggle_pause() -> void:
	if current_state == GameState.State.RUNNING:
		current_state = GameState.State.PAUSED
		get_tree().paused = true
		if pause_menu:
			pause_menu.show_pause()
	elif current_state == GameState.State.PAUSED:
		_resume_game()

func _resume_game() -> void:
	current_state = GameState.State.RUNNING
	get_tree().paused = false
	if pause_menu:
		pause_menu.hide_pause()

func start_new_run() -> void:
	get_tree().paused = false
	current_state = GameState.State.RUNNING
	_planet_distance = 0.0
	
	if pause_menu:
		pause_menu.hide_pause()
	if game_over_screen:
		game_over_screen.visible = false
	if discovery_popup:
		discovery_popup.hide_popup()
	if game_hud:
		game_hud.visible = true
	
	if discovery_manager:
		discovery_manager.reset_run()
	
	if initial_planet and player:
		player.reset_player(initial_planet)
		_setup_planet_target(initial_planet)
		if gameplay_camera:
			gameplay_camera.reset_camera()

func _return_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
