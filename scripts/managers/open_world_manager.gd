class_name OpenWorldManager
extends Node3D
## Open-world mode. The jet flies freely over a planet. Each planet sets a challenge: photograph
## a random handful of its artifacts (their models come from assets/artifacts). Once the challenge
## is done the gate opens, and flying through it teleports the jet to another world.
## All simulation goes through tick(), so tests can step the game without a real clock.

enum Mode { FLYING, PHOTO, PAUSED, TELEPORTING }

signal planet_entered(planet: PlanetController, required: int)
signal artifact_captured(artifact: ArtifactNode, captured: int, required: int)
signal challenge_completed(planet_name: String)

@export var ship: FreeFlightShip
@export var open_camera: OpenWorldCamera
@export var world_environment: WorldEnvironment
## Everything that belongs to the current planet (the planet, its artifacts and its gate) lives here.
@export var world_root: Node3D
@export var hud: OpenWorldHUD
@export var pause_menu: PauseMenu
@export var screen_fade: ScreenFade
@export var planet_scenes: Array[PackedScene] = []
@export var artifact_scene: PackedScene
@export var gate_scene: PackedScene
@export_file("*.tscn") var main_menu_scene: String = "res://scenes/menus/main_menu.tscn"
@export_group("Challenge")
## How many artifacts a planet hides: a random number from `min_artifacts` to `max_artifacts`.
@export var min_artifacts: int = 3
@export var max_artifacts: int = 6
## Closest two artifacts (and the gate) may be, measured through space.
@export var artifact_spacing: float = 36.0
## Scenery nearer than this to an artifact or the gate is cleared away.
@export var scenery_clearance: float = 12.0
## When off, the gate is open from the start.
@export var gate_requires_challenge: bool = true
@export_group("Photo camera")
@export var mouse_sensitivity: float = 0.0028
@export var photo_look_sensitivity: float = 0.0022
@export var zoom_per_wheel_step: float = 0.2
@export var zoom_per_second: float = 1.2
## A shot only counts when the artifact is at least this tall on screen (fraction of screen height).
@export_range(0.0, 0.8) var min_screen_fraction: float = 0.08
## Keeps the artifact this far inside the screen edges (fraction of the screen size).
@export_range(0.0, 0.3) var frame_margin: float = 0.05
@export var photo_folder: String = PhotoStore.FOLDER
## Every run gets its own random worlds; turn off for a fixed seed (tests, debugging).
@export var random_seed_each_run: bool = true
@export var seed_value: int = 20260607

var mode: Mode = Mode.FLYING
var planet: PlanetController
var artifacts: Array[ArtifactNode] = []
var gate: OpenWorldGate
var required: int = 0
var captured_count: int = 0
var total_photos: int = 0
var planets_visited: int = 0
var planets_cleared: int = 0
var last_photo_path: String = ""
var challenge_complete: bool = false

var rng := RandomNumberGenerator.new()
var _current_scene: PackedScene
var _mode_before_pause: Mode = Mode.FLYING
var _capturing: bool = false
var _gate_toast_cooldown: float = 0.0
var _model_paths: PackedStringArray = PackedStringArray()

func _ready() -> void:
	hud.pause_requested.connect(toggle_pause)
	pause_menu.resume_requested.connect(toggle_pause)
	pause_menu.restart_requested.connect(start_new_run)
	pause_menu.main_menu_requested.connect(return_to_main_menu)
	start_new_run()

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameSound.set_engine(false)

# --- runs and worlds ---------------------------------------------------------------------------------

func start_new_run() -> void:
	get_tree().paused = false
	rng.seed = randi() if random_seed_each_run else seed_value
	total_photos = 0
	planets_visited = 0
	planets_cleared = 0
	_current_scene = null
	_capturing = false
	pause_menu.hide_pause()
	hud.show_viewfinder(false)
	open_camera.exit_photo()
	ship.set_visuals_visible(true)
	ship.input_enabled = true
	enter_planet(_pick_planet_scene())
	_set_mode(Mode.FLYING)
	screen_fade.fade_in()
	GameSound.start_music()
	GameSound.set_engine(true)
	hud.show_toast("Welcome pilot! Mouse turns the jet, W and S drive, Space brakes. Follow the beams of light.")

## Replaces the current world with `scene`'s planet and sets its challenge.
func enter_planet(scene: PackedScene) -> void:
	_clear_world()
	_current_scene = scene
	planet = scene.instantiate() as PlanetController
	world_root.add_child(planet)
	planet.global_transform = Transform3D(Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)), Vector3.ZERO)
	apply_mood(planet)
	planets_visited += 1
	required = rng.randi_range(mini(min_artifacts, max_artifacts), maxi(min_artifacts, max_artifacts))
	captured_count = 0
	challenge_complete = false
	_model_paths = ArtifactLibrary.list_models()

	var start_dir: Vector3 = _random_direction()
	ship.place_on(planet.global_position, planet.radius, start_dir, _random_tangent(start_dir))
	var occupied: Array[Vector3] = [start_dir]
	var spots: Array[Vector3] = _scatter(required + 1, occupied)
	var gate_dir: Vector3 = spots.pop_back()
	_spawn_artifacts(spots)
	_spawn_gate(gate_dir)
	open_camera.snap()
	hud.set_planet(planet.planet_name, required)
	hud.set_detector("Detector: searching")
	hud.show_toast("%s: photograph %d artifact%s" % [planet.planet_name, required, "" if required == 1 else "s"])
	planet_entered.emit(planet, required)

func _clear_world() -> void:
	artifacts.clear()
	gate = null
	for child in world_root.get_children():
		child.queue_free()
		world_root.remove_child(child)

func _pick_planet_scene() -> PackedScene:
	var options: Array = planet_scenes.filter(func(scene: PackedScene) -> bool: return scene != _current_scene)
	if options.is_empty():
		options = planet_scenes
	return options[rng.randi() % options.size()]

func _spawn_artifacts(directions: Array[Vector3]) -> void:
	# Different models first; the list repeats only when there are fewer models than artifacts.
	var model_order: Array[int] = []
	for i in _model_paths.size():
		model_order.append(i)
	for i in range(model_order.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var swap: int = model_order[i]
		model_order[i] = model_order[j]
		model_order[j] = swap
	var clear_points := PackedVector3Array()
	for i in directions.size():
		var node := artifact_scene.instantiate() as ArtifactNode
		world_root.add_child(node)
		if model_order.is_empty() or not node.setup(_model_paths[model_order[i % model_order.size()]]):
			node.artifact_name = "Artifact %d" % (i + 1)
		var dir: Vector3 = directions[i]
		var surface: Vector3 = planet.global_position + dir * (planet.radius - 0.2)
		node.global_transform = Transform3D(PlanetaryGravity.surface_basis(dir, _random_tangent(dir)), surface)
		node.detected_changed.connect(_on_artifact_detected)
		artifacts.append(node)
		clear_points.append(surface)
	planet.clear_decorations_near(clear_points, scenery_clearance + 7.0)

func _spawn_gate(dir: Vector3) -> void:
	gate = gate_scene.instantiate() as OpenWorldGate
	world_root.add_child(gate)
	var surface: Vector3 = planet.global_position + dir * planet.radius
	gate.global_transform = Transform3D(PlanetaryGravity.surface_basis(dir, _random_tangent(dir)), surface)
	gate.set_unlocked(not gate_requires_challenge)
	planet.clear_decorations_near(PackedVector3Array([surface]), scenery_clearance + 4.0)

func _random_direction() -> Vector3:
	var z: float = rng.randf_range(-1.0, 1.0)
	var angle: float = rng.randf() * TAU
	var flat: float = sqrt(1.0 - z * z)
	return Vector3(flat * cos(angle), z, flat * sin(angle))

func _random_tangent(up: Vector3) -> Vector3:
	var hint: Vector3 = _random_direction()
	var tangent: Vector3 = hint - up * hint.dot(up)
	return tangent.normalized() if tangent.length_squared() > 0.001 else up.cross(Vector3.RIGHT).normalized()

## `count` surface directions at least `artifact_spacing` apart from each other and from `existing`;
## the spacing relaxes a little if the planet is too small to fit them all.
func _scatter(count: int, existing: Array[Vector3]) -> Array[Vector3]:
	var picked: Array[Vector3] = []
	var gap: float = artifact_spacing
	var failures: int = 0
	while picked.size() < count:
		var candidate: Vector3 = _random_direction()
		var clear: bool = true
		for other in existing + picked:
			if candidate.distance_to(other) * planet.radius < gap:
				clear = false
				break
		if clear:
			picked.append(candidate)
			failures = 0
		else:
			failures += 1
			if failures > 80:
				gap *= 0.85
				failures = 0
	return picked

## Tints the ambient light and fog to a world's mood.
func apply_mood(target: PlanetController) -> void:
	if target == null or world_environment == null or world_environment.environment == null:
		return
	world_environment.environment.ambient_light_color = target.ambient_color
	world_environment.environment.fog_light_color = target.fog_color

# --- state -------------------------------------------------------------------------------------------

func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	var flying: bool = mode == Mode.FLYING or mode == Mode.PHOTO
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if flying else Input.MOUSE_MODE_VISIBLE

func is_flying() -> bool:
	return mode == Mode.FLYING

func toggle_pause() -> void:
	if mode == Mode.FLYING:
		_mode_before_pause = mode
		_set_mode(Mode.PAUSED)
		get_tree().paused = true
		GameSound.set_engine(false)
		pause_menu.show_pause()
	elif mode == Mode.PAUSED:
		get_tree().paused = false
		pause_menu.hide_pause()
		_set_mode(_mode_before_pause)
		GameSound.set_engine(true)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func return_to_main_menu() -> void:
	GameSound.set_engine(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await screen_fade.fade_out(0.35).finished
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene)

# --- simulation --------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	_gate_toast_cooldown = maxf(0.0, _gate_toast_cooldown - delta)
	match mode:
		Mode.FLYING:
			_tick_flying(delta)
		Mode.PHOTO:
			_tick_photo(delta)

func _tick_flying(delta: float) -> void:
	var pilot: bool = is_inside_tree() and not get_tree().paused
	var throttle: float = Input.get_axis("move_back", "move_forward") if pilot else 0.0
	var steer: float = Input.get_axis("move_left", "move_right") if pilot else 0.0
	var braking: bool = pilot and Input.is_action_pressed("ship_stop")
	ship.advance(delta, throttle, braking, steer)
	_update_detectors()
	_update_hud()
	if gate and gate.crossed_by(ship.global_position):
		_on_gate_crossed()

func _tick_photo(delta: float) -> void:
	ship.advance(delta, 0.0, true, 0.0)
	var zoom_input: float = Input.get_axis("move_back", "move_forward") if not get_tree().paused else 0.0
	if zoom_input != 0.0:
		open_camera.zoom(zoom_input * zoom_per_second * delta)
	ship.set_visuals_visible(open_camera.blend < 0.5)
	var candidate: ArtifactNode = shot_candidate()
	hud.set_framed(candidate != null, candidate.artifact_name if candidate else "")
	hud.set_zoom(open_camera.zoom_factor())

func _update_detectors() -> void:
	for artifact in artifacts:
		if is_instance_valid(artifact):
			artifact.update_detection(ship.global_position)

func _update_hud() -> void:
	var nearest: ArtifactNode = nearest_artifact()
	var near: ArtifactNode = nearest_in_range()
	if near != null:
		hud.set_prompt("%s detected! Press C or right-click to open the camera" % near.artifact_name)
	else:
		hud.set_prompt("")
	if nearest != null:
		hud.set_detector("Nearest artifact: %d m" % int(nearest.distance_to(ship.global_position)))
	elif gate != null and gate.unlocked:
		hud.set_detector("Gate open: %d m" % int(gate.distance_to(ship.global_position)))
	else:
		hud.set_detector("")

## The nearest artifact that has not been photographed yet, or null.
func nearest_artifact() -> ArtifactNode:
	var best: ArtifactNode = null
	var best_distance: float = INF
	for artifact in artifacts:
		if not is_instance_valid(artifact) or artifact.is_captured:
			continue
		var distance: float = artifact.distance_to(ship.global_position)
		if distance < best_distance:
			best_distance = distance
			best = artifact
	return best

## The nearest artifact whose detector is currently triggered, or null.
func nearest_in_range() -> ArtifactNode:
	var best: ArtifactNode = null
	var best_distance: float = INF
	for artifact in artifacts:
		if not is_instance_valid(artifact) or not artifact.in_range:
			continue
		var distance: float = artifact.distance_to(ship.global_position)
		if distance < best_distance:
			best_distance = distance
			best = artifact
	return best

func _on_artifact_detected(artifact: ArtifactNode, in_range: bool) -> void:
	if in_range and mode == Mode.FLYING:
		GameSound.play(&"arrive")

# --- photo camera ------------------------------------------------------------------------------------

## Switches from the jet's view to the camera, turned toward the nearest detected artifact.
func enter_photo_mode() -> bool:
	if mode != Mode.FLYING:
		return false
	var target: ArtifactNode = nearest_in_range()
	if target == null:
		hud.show_toast("No artifact nearby. Fly toward a beam of light until the detector triggers.")
		return false
	ship.speed = 0.0
	open_camera.enter_photo(target.focus_point())
	hud.show_viewfinder(true)
	_set_mode(Mode.PHOTO)
	GameSound.play(&"ui_click")
	return true

func exit_photo_mode() -> void:
	if mode != Mode.PHOTO:
		return
	open_camera.exit_photo()
	ship.set_visuals_visible(true)
	hud.show_viewfinder(false)
	_set_mode(Mode.FLYING)

## The uncaptured artifact that would count if the shutter were pressed now: in detector range
## and wholly inside the frame at a readable size. The one closest to the screen's middle wins.
func shot_candidate() -> ArtifactNode:
	var best: ArtifactNode = null
	var best_score: float = INF
	var viewport_size: Vector2 = open_camera.get_viewport().get_visible_rect().size
	for artifact in artifacts:
		if not is_instance_valid(artifact) or artifact.is_captured:
			continue
		if artifact.distance_to(ship.global_position) > artifact.detect_radius:
			continue
		var points: PackedVector3Array = artifact.sample_points()
		var framed: bool = true
		for point in points:
			if not open_camera.point_in_frame(point, frame_margin):
				framed = false
				break
		if not framed:
			continue
		var base: Vector2 = open_camera.unproject_position(points[0])
		var top: Vector2 = open_camera.unproject_position(points[2])
		if absf(base.y - top.y) < min_screen_fraction * viewport_size.y:
			continue
		var score: float = open_camera.unproject_position(artifact.focus_point()).distance_to(viewport_size * 0.5)
		if score < best_score:
			best_score = score
			best = artifact
	return best

## Takes the picture: hides the overlay for one frame, grabs the screen and saves it. Returns true
## when a valid picture of an artifact was saved.
func take_picture() -> bool:
	if mode != Mode.PHOTO or not open_camera.is_photo_ready() or _capturing:
		return false
	var target: ArtifactNode = shot_candidate()
	if target == null:
		hud.show_toast("Fit a whole artifact inside the frame, then shoot")
		GameSound.play(&"hit")
		return false
	_capturing = true
	hud.hide_for_capture(true)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	hud.hide_for_capture(false)
	_capturing = false
	return register_shot(target, image)

## Saves `image` as a picture of `target` and counts it. Returns false when the file could not be written.
func register_shot(target: ArtifactNode, image: Image) -> bool:
	if target == null or target.is_captured:
		return false
	var path: String = PhotoStore.save(image, target.artifact_name, photo_folder)
	if path.is_empty():
		hud.show_toast("The picture could not be saved")
		return false
	last_photo_path = path
	target.mark_captured()
	captured_count += 1
	total_photos += 1
	hud.set_progress(captured_count, required)
	hud.flash_shutter()
	GameSound.play(&"discover")
	artifact_captured.emit(target, captured_count, required)
	if captured_count >= required:
		_complete_challenge()
	else:
		var where: String = PhotoStore.folder_on_disk(photo_folder) if captured_count == 1 else path.get_file()
		hud.show_toast("%s captured (%d of %d). Saved to %s" % [target.artifact_name, captured_count, required, where])
	return true

func _complete_challenge() -> void:
	challenge_complete = true
	planets_cleared += 1
	if gate:
		gate.set_unlocked(true)
	hud.show_toast("Challenge complete! Pictures are in %s. Fly through the glowing gate to reach the next world." % PhotoStore.folder_on_disk(photo_folder))
	challenge_completed.emit(planet.planet_name)

# --- teleport ----------------------------------------------------------------------------------------

func _on_gate_crossed() -> void:
	if gate.unlocked or not gate_requires_challenge:
		teleport_to_next_world()
	elif _gate_toast_cooldown <= 0.0:
		_gate_toast_cooldown = 3.0
		var left: int = required - captured_count
		hud.show_toast("The gate is shut. Photograph %d more artifact%s first." % [left, "" if left == 1 else "s"])
		GameSound.play(&"hit")

## Flies the jet through to another planet. `animated` fades the screen out and back in.
func teleport_to_next_world(animated: bool = true) -> void:
	if mode != Mode.FLYING:
		return
	_set_mode(Mode.TELEPORTING)
	GameSound.play(&"launch")
	if animated:
		await screen_fade.fade_out(0.35).finished
	enter_planet(_pick_planet_scene())
	_set_mode(Mode.FLYING)
	if animated:
		screen_fade.fade_in(0.7)
	GameSound.play(&"arrive")

# --- input -------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look((event as InputEventMouseMotion).relative)
		return
	if event is InputEventMouseButton and mode == Mode.PHOTO and (event as InputEventMouseButton).pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_WHEEL_UP:
				open_camera.zoom(zoom_per_wheel_step)
			MOUSE_BUTTON_WHEEL_DOWN:
				open_camera.zoom(-zoom_per_wheel_step)
	if event.is_action_pressed("pause_game"):
		if mode == Mode.PHOTO:
			exit_photo_mode()
			get_viewport().set_input_as_handled()
		elif mode == Mode.FLYING:
			toggle_pause()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("photo_mode") and not event.is_echo():
		if mode == Mode.FLYING:
			enter_photo_mode()
		elif mode == Mode.PHOTO:
			exit_photo_mode()
		get_viewport().set_input_as_handled()
	elif mode == Mode.PHOTO and not event.is_echo() \
			and (event.is_action_pressed("photo_shoot") or event.is_action_pressed("ship_stop")):
		take_picture()
		get_viewport().set_input_as_handled()

## Mouse movement: turns the jet, or looks around with the camera.
func look(relative: Vector2) -> void:
	match mode:
		Mode.FLYING:
			ship.rotate_heading(-relative.x * mouse_sensitivity)
		Mode.PHOTO:
			open_camera.look(relative, photo_look_sensitivity)
