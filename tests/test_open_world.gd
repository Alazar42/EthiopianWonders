extends SceneTree
## Open-world mode tests. Run from the project folder:
##   godot --headless --path . --script res://tests/test_open_world.gd
## Exits with the number of failed checks.

const DT: float = 1.0 / 60.0
const MENU_SCENE: String = "res://scenes/menus/main_menu.tscn"
const WORLD_SCENE: String = "res://scenes/openworld/open_world.tscn"
const TEST_PHOTOS: String = "user://test_photos"

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
	_clean_photos()
	await _test_menu()
	_test_library()
	await _test_world_setup()
	await _test_flight()
	await _test_detector_and_camera()
	await _test_photos_and_challenge()
	await _test_gate_and_teleport()
	await _test_random_counts()
	await _test_pause_and_input()
	_clean_photos()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(_failed)

# --- helpers -------------------------------------------------------------------------------------------

func _clean_photos() -> void:
	for file in PhotoStore.list_photos(TEST_PHOTOS):
		DirAccess.remove_absolute(file)

func _new_world() -> OpenWorldManager:
	var world := (load(WORLD_SCENE) as PackedScene).instantiate() as OpenWorldManager
	world.random_seed_each_run = false
	world.photo_folder = TEST_PHOTOS
	root.add_child(world)
	world.set_process(false) # tests drive tick() themselves
	await process_frame
	return world

func _free_world(world: OpenWorldManager) -> void:
	world.queue_free()
	await process_frame

func _step(world: OpenWorldManager, seconds: float) -> void:
	for i in int(seconds / DT):
		world.tick(DT)
		world.open_camera.update_follow(DT)

## Puts the ship `distance` metres from `artifact` along the ground, looking its way.
func _park_near(world: OpenWorldManager, artifact: ArtifactNode, distance: float) -> void:
	var center: Vector3 = world.planet.global_position
	var radius: float = world.planet.radius
	var up: Vector3 = (artifact.global_position - center).normalized()
	var side: Vector3 = up.cross(Vector3.RIGHT)
	if side.length_squared() < 0.01:
		side = up.cross(Vector3.FORWARD)
	side = side.normalized()
	var angle: float = distance / radius
	var spot: Vector3 = (up * cos(angle) + side * sin(angle)).normalized()
	var toward: Vector3 = (artifact.global_position - (center + spot * radius)).normalized()
	world.ship.place_on(center, radius, spot, toward)

func _synthetic_image() -> Image:
	var image := Image.create(32, 24, false, Image.FORMAT_RGB8)
	image.fill(Color(0.2, 0.5, 0.3))
	return image

func _count_nodes_of(node: Node, script_class: String) -> int:
	var total: int = 1 if node.get_class() == script_class or (node.get_script() != null and node.get_script().get_global_name() == script_class) else 0
	for child in node.get_children():
		total += _count_nodes_of(child, script_class)
	return total

# --- tests ---------------------------------------------------------------------------------------------

func _test_menu() -> void:
	print("main menu has two modes")
	var menu := (load(MENU_SCENE) as PackedScene).instantiate() as MainMenu
	root.add_child(menu)
	await process_frame
	check("arcade and open world buttons exist", menu.get_node("%PlayButton") is Button and menu.get_node("%OpenWorldButton") is Button)
	check("the arcade button says ARCADE", (menu.get_node("%PlayButton") as Button).text == "ARCADE")
	check("the open world button says OPEN WORLD", (menu.get_node("%OpenWorldButton") as Button).text == "OPEN WORLD")
	check("arcade still points at the arcade game", (load(menu.game_scene) as PackedScene).instantiate() is GameManager)
	check("open world points at the open world game", (load(menu.open_world_scene) as PackedScene).instantiate() is OpenWorldManager)
	menu.queue_free()
	await process_frame

func _test_library() -> void:
	print("artifact folder")
	var models: PackedStringArray = ArtifactLibrary.list_models()
	check("the artifact folder yields its models", models.size() >= 3, str(models))
	check("model paths point at real files (no .import suffix)", models.size() > 0 and models.size() == models.size() and not str(models).contains(".import"))
	check("names are read from file names", ArtifactLibrary.display_name("res://assets/artifacts/fasiledes gondor.fbx") == "Fasiledes Gondor")
	check("material is found by file name", ArtifactLibrary.find_material("res://assets/artifacts/axum.fbx") != null)
	check("material is found by first word", ArtifactLibrary.find_material("res://assets/artifacts/fasiledes gondor.fbx") != null)
	check("an unknown model has no material", ArtifactLibrary.find_material("res://assets/artifacts/zzz_new.fbx") == null)
	var temp := "user://test_models"
	DirAccess.make_dir_recursive_absolute(temp)
	for name in ["new_stele.glb.import", "plain.tres", "rock.obj", "notes.txt", "castle.fbx.remap", "castle.fbx"]:
		var file := FileAccess.open(temp.path_join(name), FileAccess.WRITE)
		file.close()
	var found: PackedStringArray = ArtifactLibrary.list_models(temp)
	check("new model files are picked up, others ignored, exported suffixes stripped",
		found == PackedStringArray([temp + "/castle.fbx", temp + "/new_stele.glb", temp + "/rock.obj"]), str(found))
	for file in DirAccess.get_files_at(temp):
		DirAccess.remove_absolute(temp.path_join(file))
	var model := ArtifactLibrary.instantiate(models[0])
	check("a model instantiates", model != null)
	var height: float = ArtifactLibrary.fit(model, 14.0)
	var bounds: AABB = ArtifactLibrary.local_bounds(model)
	var scaled: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) * model.scale.x
	check("models are scaled to a common size", absf(scaled - 14.0) < 0.05, str(scaled))
	check("models stand on the ground", absf(model.position.y + bounds.position.y * model.scale.y) < 0.01 and height > 0.0)
	model.free()

func _test_world_setup() -> void:
	print("open world setup")
	var world := await _new_world()
	check("the mode starts in flight", world.mode == OpenWorldManager.Mode.FLYING)
	check("the challenge is 3 to 6 pictures", world.required >= 3 and world.required <= 6, str(world.required))
	check("exactly that many artifacts are on the planet", world.artifacts.size() == world.required, "%d vs %d" % [world.artifacts.size(), world.required])
	check("no stone obstacles exist in open world", _count_nodes_of(world, "Obstacle") == 0)
	check("the gate starts shut", world.gate != null and not world.gate.unlocked)
	var on_surface: bool = true
	var apart: bool = true
	var has_model: bool = true
	for i in world.artifacts.size():
		var artifact: ArtifactNode = world.artifacts[i]
		var distance: float = artifact.global_position.distance_to(world.planet.global_position)
		on_surface = on_surface and absf(distance - world.planet.radius) < 0.5
		has_model = has_model and artifact.get_node("Model").get_child_count() == 1
		for j in range(i + 1, world.artifacts.size()):
			if artifact.global_position.distance_to(world.artifacts[j].global_position) < 20.0:
				apart = false
	check("artifacts stand on the planet's surface", on_surface)
	check("artifacts are spread apart", apart)
	check("every artifact shows a model from the artifact folder", has_model)
	var names: Dictionary = {}
	for artifact in world.artifacts:
		names[artifact.model_path] = true
	check("different models are used before any repeat", names.size() >= mini(world.artifacts.size(), ArtifactLibrary.list_models().size()))
	var up: bool = true
	for artifact in world.artifacts:
		up = up and artifact.global_basis.y.dot((artifact.global_position - world.planet.global_position).normalized()) > 0.999
	check("artifacts stand upright on the ground", up)
	check("the HUD shows the challenge", world.hud.get_node("%ChallengeLabel").text.ends_with("0 / %d" % world.required), world.hud.get_node("%ChallengeLabel").text)
	var altitude: float = world.ship.global_position.distance_to(world.planet.global_position)
	check("the jet hovers above the surface", absf(altitude - (world.planet.radius + world.ship.hover_height)) < 0.01)
	await _free_world(world)

func _test_flight() -> void:
	print("free flight")
	var world := await _new_world()
	var ship := world.ship
	var start: Vector3 = ship.global_position
	Input.action_press("move_forward")
	_step(world, 1.5)
	Input.action_release("move_forward")
	check("W drives the jet forward", ship.speed > 5.0 and ship.global_position.distance_to(start) > 5.0, str(ship.speed))
	var moved: Vector3 = (ship.global_position - start).normalized()
	check("it moves where it points", moved.dot(ship.get_forward()) > 0.9, str(moved.dot(ship.get_forward())))
	var heading_before: Vector3 = ship.get_forward()
	world.look(Vector2(100, 0))
	var turned: float = heading_before.angle_to(ship.get_forward())
	check("moving the mouse right turns the jet sideways", turned > 0.1 and ship.get_forward().cross(heading_before).dot(ship.get_up()) > 0.0, str(turned))
	var after_right: Vector3 = ship.get_forward()
	world.look(Vector2(-100, 0))
	check("moving the mouse left turns it back", after_right.cross(ship.get_forward()).dot(ship.get_up()) < 0.0 or after_right.angle_to(ship.get_forward()) > 0.05)
	var pitch_before: Vector3 = ship.global_basis.y
	world.look(Vector2(0, 300))
	check("the mouse cannot tilt the jet up or down", ship.global_basis.y.is_equal_approx(pitch_before))
	Input.action_press("move_back")
	_step(world, 3.0)
	Input.action_release("move_back")
	check("S reverses", ship.speed < -1.0, str(ship.speed))
	var backwards_check: bool = ship.speed < 0.0
	Input.action_press("ship_stop")
	_step(world, 1.0)
	Input.action_release("ship_stop")
	check("Space stops the jet", absf(ship.speed) < 0.01 and backwards_check, str(ship.speed))
	var rest: Vector3 = ship.global_position
	_step(world, 0.5)
	check("a stopped jet stays put", ship.global_position.distance_to(rest) < 0.001)
	Input.action_press("move_forward")
	_step(world, 1.0)
	Input.action_release("move_forward")
	_step(world, 4.0)
	check("without keys the jet slows to a halt", absf(ship.speed) < 0.5, str(ship.speed))
	# Fly all the way around the world.
	Input.action_press("move_forward")
	var radial_ok: bool = true
	var height_ok: bool = true
	var travelled: float = 0.0
	for i in 2200:
		var before: Vector3 = ship.global_position
		world.tick(DT)
		travelled += before.distance_to(ship.global_position)
		var offset: Vector3 = ship.global_position - world.planet.global_position
		radial_ok = radial_ok and ship.get_up().dot(offset.normalized()) > 0.9999 and ship.global_basis.y.dot(offset.normalized()) > 0.999
		height_ok = height_ok and absf(offset.length() - (world.planet.radius + ship.hover_height)) < 0.01
	Input.action_release("move_forward")
	check("it flew farther than once around the planet", travelled > TAU * world.planet.radius, str(travelled))
	check("the jet stays upright over the whole planet", radial_ok)
	check("it keeps a steady height over the whole planet", height_ok)
	check("the jet basis stays orthonormal", absf(ship.global_basis.determinant() - 1.0) < 0.01 and absf(ship.get_forward().length() - 1.0) < 0.001)
	await _free_world(world)

func _test_detector_and_camera() -> void:
	print("detector and photo camera")
	var world := await _new_world()
	var target: ArtifactNode = world.artifacts[0]
	_park_near(world, target, 120.0)
	world.tick(DT)
	check("far from an artifact the detector is quiet", not target.in_range)
	check("nothing is in range far away", world.nearest_in_range() == null or world.nearest_in_range() != target)
	check("the camera refuses to open with nothing nearby", not world.enter_photo_mode() or world.nearest_in_range() != null)
	world.exit_photo_mode()
	_park_near(world, target, 26.0)
	world.tick(DT)
	check("close to an artifact the detector triggers", target.in_range)
	check("the HUD prompts the player to take a picture", world.hud.get_node("%PromptPanel").visible)
	_park_near(world, target, 80.0)
	world.tick(DT)
	check("the detector switches off when the jet leaves", not target.in_range)
	if world.nearest_in_range() == null:
		check("the prompt disappears with it", not world.hud.get_node("%PromptPanel").visible)
	_park_near(world, target, 26.0)
	world.tick(DT)
	var cam := world.open_camera
	check("the camera starts in the chase view", cam.mode == OpenWorldCamera.Mode.CHASE and absf(cam.fov - cam.chase_fov) < 0.01)
	check("the camera opens when an artifact is detected", world.enter_photo_mode())
	check("the view switches to the photo camera", cam.mode == OpenWorldCamera.Mode.PHOTO and world.mode == OpenWorldManager.Mode.PHOTO)
	check("the viewfinder replaces the flight overlay", world.hud.is_viewfinder_open())
	_step(world, 1.0)
	check("the swing between cameras finishes", cam.is_photo_ready())
	check("the jet is hidden while looking through its nose", not world.ship.visuals.visible)
	check("the camera sits in the jet's nose", cam.global_position.distance_to(world.ship.global_position) < 3.0)
	check("the camera looks at the artifact", cam.point_in_frame(target.focus_point(), 0.3))
	var start_fov: float = cam.fov
	cam.zoom(0.5)
	_step(world, 0.5)
	check("zooming in narrows the field of view", cam.fov < start_fov - 5.0 and cam.zoom_factor() > 1.3, "%f %f" % [cam.fov, cam.zoom_factor()])
	cam.zoom(-0.5)
	cam.zoom(-0.5)
	_step(world, 0.5)
	check("zooming out widens it", cam.fov > start_fov, str(cam.fov))
	for i in 20:
		cam.zoom(1.0)
	check("zoom has a limit", cam.photo_fov >= cam.min_fov - 0.001)
	for i in 20:
		cam.zoom(-1.0)
	check("zoom out has a limit", cam.photo_fov <= cam.max_fov + 0.001)
	var yaw_before: float = cam.photo_yaw
	world.look(Vector2(60, 0))
	check("the mouse looks around in photo view", cam.photo_yaw < yaw_before)
	for i in 60:
		world.look(Vector2(1000, 0))
	check("looking around is limited", absf(cam.photo_yaw) <= cam.max_yaw + 0.001)
	var rest: Vector3 = world.ship.global_position
	_step(world, 0.5)
	check("the jet stays parked during the shot", world.ship.global_position.distance_to(rest) < 0.001)
	world.exit_photo_mode()
	_step(world, 1.0)
	check("leaving the camera returns to the jet view", cam.mode == OpenWorldCamera.Mode.CHASE and world.mode == OpenWorldManager.Mode.FLYING and world.ship.visuals.visible)
	check("the field of view returns to normal", absf(cam.fov - cam.chase_fov) < 0.1, str(cam.fov))
	await _free_world(world)

func _test_photos_and_challenge() -> void:
	print("pictures and challenge")
	var world := await _new_world()
	var target: ArtifactNode = world.artifacts[0]
	_park_near(world, target, 24.0)
	world.tick(DT)
	world.enter_photo_mode()
	_step(world, 1.0)
	check("a framed artifact is a valid shot", world.shot_candidate() == target)
	check("the viewfinder turns green when framed", world.hud.get_node("%FramedLabel").text.begins_with("Framed"))
	world.look(Vector2(0, 0))
	world.open_camera.photo_yaw = 1.2
	_step(world, 0.2)
	check("an artifact outside the frame is not a valid shot", world.shot_candidate() == null)
	check("the viewfinder warns when nothing is framed", not world.hud.get_node("%FramedLabel").text.begins_with("Framed"))
	check("taking a picture of nothing counts for nothing", not await world.take_picture() and world.captured_count == 0)
	world.open_camera.look_toward(target.focus_point())
	world.open_camera.photo_fov = world.open_camera.max_fov
	_step(world, 0.2)
	world.open_camera.photo_fov = 6.0
	world.open_camera.min_fov = 2.0
	world.open_camera.zoom(0.0)
	_step(world, 0.5)
	check("zoomed in too far, the whole artifact no longer fits", world.shot_candidate() == null)
	world.open_camera.photo_fov = world.open_camera.start_fov
	world.open_camera.look_toward(target.focus_point())
	_step(world, 0.5)
	check("the shot is valid again once framed", world.shot_candidate() == target)
	var shots_before: int = PhotoStore.list_photos(TEST_PHOTOS).size()
	check("a valid picture is accepted and saved", world.register_shot(target, _synthetic_image()))
	var files: PackedStringArray = PhotoStore.list_photos(TEST_PHOTOS)
	check("the picture is a file on disk", files.size() == shots_before + 1 and FileAccess.file_exists(world.last_photo_path), world.last_photo_path)
	var saved := Image.load_from_file(world.last_photo_path)
	check("the saved file is a readable PNG", saved != null and saved.get_width() == 32 and saved.get_height() == 24)
	check("the file name mentions the artifact", world.last_photo_path.get_file().begins_with(PhotoStore.slug(target.artifact_name)))
	check("the artifact counts as captured", target.is_captured and world.captured_count == 1 and world.total_photos == 1)
	check("the HUD updates the picture count", world.hud.get_node("%ChallengeLabel").text.begins_with("Pictures  1"), world.hud.get_node("%ChallengeLabel").text)
	check("the same artifact cannot be counted twice", not world.register_shot(target, _synthetic_image()) and world.captured_count == 1)
	check("a captured artifact is no longer a candidate", world.shot_candidate() == null)
	check("its detector is switched off", not target.in_range)
	check("the gate is still shut", not world.gate.unlocked or world.required == 1)
	check("a failed save does not count", not world.register_shot(world.artifacts[1], null) and world.captured_count == 1)
	world.exit_photo_mode()
	for i in range(1, world.artifacts.size()):
		var artifact: ArtifactNode = world.artifacts[i]
		check("picture %d of %d is accepted" % [i + 1, world.required], world.register_shot(artifact, _synthetic_image()))
	check("all pictures taken completes the challenge", world.challenge_complete and world.captured_count == world.required)
	check("the gate opens", world.gate.unlocked)
	check("the planet counts as cleared", world.planets_cleared == 1)
	await _free_world(world)

func _test_gate_and_teleport() -> void:
	print("gate and teleport")
	var world := await _new_world()
	var first_planet: PlanetController = world.planet
	var gate_dir: Vector3 = (world.gate.global_position - world.planet.global_position).normalized()
	var approach: Vector3 = (world.gate.global_position - world.gate.axis() * 9.0 - world.planet.global_position).normalized()
	world.ship.place_on(world.planet.global_position, world.planet.radius, approach, world.gate.axis())
	world.tick(DT)
	check("the ship starts in front of the gate", (world.ship.global_position - world.gate.ring_center()).dot(world.gate.axis()) < -4.0)
	Input.action_press("move_forward")
	_step(world, 2.0)
	Input.action_release("move_forward")
	check("a shut gate does not teleport", world.planet == first_planet and world.mode == OpenWorldManager.Mode.FLYING)
	check("a shut gate tells the player why", world.hud.get_node("%ToastLabel").text.contains("shut"), world.hud.get_node("%ToastLabel").text)
	for artifact in world.artifacts:
		world.register_shot(artifact, _synthetic_image())
	check("the challenge is done", world.gate.unlocked)
	var scene_before := world._current_scene
	world.ship.place_on(world.planet.global_position, world.planet.radius, approach, world.gate.axis())
	world.tick(DT)
	Input.action_press("move_forward")
	_step(world, 0.8)
	Input.action_release("move_forward")
	await create_timer(1.2).timeout
	check("flying through the open gate teleports to another world", world.planet != first_planet and world._current_scene != scene_before)
	check("the old world is gone", not is_instance_valid(first_planet) or first_planet.is_queued_for_deletion() or first_planet.get_parent() == null)
	check("the new world has its own challenge", world.captured_count == 0 and not world.challenge_complete and world.artifacts.size() == world.required)
	check("the new world's gate is shut again", not world.gate.unlocked)
	check("the player is flying again", world.mode == OpenWorldManager.Mode.FLYING)
	check("the new planet counts as a visit", world.planets_visited == 2)
	check("the jet sits above the new planet", absf(world.ship.global_position.distance_to(world.planet.global_position) - (world.planet.radius + world.ship.hover_height)) < 0.01)
	check("the total picture count is kept", world.total_photos > 0)
	check("the screen fades back in", world.screen_fade.opacity() < 0.5, str(world.screen_fade.opacity()))
	world.gate_requires_challenge = false
	world.gate.set_unlocked(true)
	check("the gate can be set to always open", world.gate.unlocked)
	await _free_world(world)

func _test_random_counts() -> void:
	print("random challenge sizes")
	var world := await _new_world()
	world.random_seed_each_run = true
	var seen: Dictionary = {}
	var all_match: bool = true
	var in_range: bool = true
	var model_use: Dictionary = {}
	for i in 40:
		world.rng.seed = i * 7919 + 3
		world.enter_planet(world._pick_planet_scene())
		seen[world.required] = true
		in_range = in_range and world.required >= 3 and world.required <= 6
		all_match = all_match and world.artifacts.size() == world.required
		for artifact in world.artifacts:
			model_use[artifact.model_path] = true
	check("challenge size is always 3 to 6", in_range, str(seen.keys()))
	check("the number of artifacts always matches the challenge", all_match)
	check("the challenge size varies", seen.size() >= 3, str(seen.keys()))
	check("every model in the folder shows up", model_use.size() == ArtifactLibrary.list_models().size(), str(model_use.keys()))
	var planets: Dictionary = {}
	for i in 30:
		world.enter_planet(world._pick_planet_scene())
		planets[world.planet.planet_name] = true
	check("the planets vary from world to world", planets.size() >= 3, str(planets.keys()))
	await _free_world(world)

func _test_pause_and_input() -> void:
	print("pause and input")
	var world := await _new_world()
	# A headless run has no window, so the engine ignores mouse-mode changes there.
	var has_window: bool = DisplayServer.get_name() != "headless"
	check("the mouse is captured while flying", Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not has_window)
	world.toggle_pause()
	check("pausing frees the mouse", world.mode == OpenWorldManager.Mode.PAUSED and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and paused)
	var heading: Vector3 = world.ship.get_forward()
	world.look(Vector2(200, 0))
	check("the mouse does not steer while paused", world.ship.get_forward().is_equal_approx(heading))
	world.toggle_pause()
	check("resuming captures the mouse again", world.mode == OpenWorldManager.Mode.FLYING and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or not has_window) and not paused)
	var target: ArtifactNode = world.artifacts[0]
	_park_near(world, target, 24.0)
	world.tick(DT)
	var key := InputEventKey.new()
	key.keycode = KEY_C
	key.pressed = true
	world._unhandled_input(key)
	check("the C key opens the camera", world.mode == OpenWorldManager.Mode.PHOTO)
	world._unhandled_input(key)
	check("the C key closes it again", world.mode == OpenWorldManager.Mode.FLYING)
	world.enter_photo_mode()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	world._unhandled_input(escape)
	check("Escape leaves the camera instead of pausing", world.mode == OpenWorldManager.Mode.FLYING and not paused)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	world.enter_photo_mode()
	var fov_before: float = world.open_camera.photo_fov
	world._unhandled_input(wheel)
	check("the mouse wheel zooms in the camera", world.open_camera.photo_fov < fov_before)
	world.exit_photo_mode()
	world.start_new_run()
	check("restarting resets the run", world.total_photos == 0 and world.planets_visited == 1 and world.mode == OpenWorldManager.Mode.FLYING)
	await _free_world(world)
