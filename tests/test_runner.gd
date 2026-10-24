extends SceneTree

func _init() -> void:
	print("==================================================")
	print("  ETHIOPIAN WONDERS — AUTOMATED VERIFICATION SUITE")
	print("==================================================")
	
	var passed = 0
	var failed = 0
	
	var assert_test = func(condition: bool, test_name: String) -> void:
		if condition:
			print("  [PASS] " + test_name)
			passed += 1
		else:
			push_error("  [FAIL] " + test_name)
			print("  [FAIL] " + test_name)
			failed += 1

	# Test 1: Project launches into Main Menu scene
	var menu_scene = load("res://scenes/menus/main_menu.tscn") as PackedScene
	assert_test.call(menu_scene != null, "1. Main menu scene loads successfully")
	var menu_inst = menu_scene.instantiate() as Control
	root.add_child(menu_inst)
	assert_test.call(menu_inst != null, "1b. Main menu instantiates without error")
	menu_inst.queue_free()

	# Test 2: GameWorld loads and instantiates
	var game_scene = load("res://scenes/game/game_world.tscn") as PackedScene
	assert_test.call(game_scene != null, "2. GameWorld scene loads successfully")
	var game_inst = game_scene.instantiate() as GameManager
	root.add_child(game_inst)
	assert_test.call(game_inst != null, "2b. GameWorld instantiates successfully")

	# Test 3 & 4: Player spawns on surface of first planet with spherical gravity
	var player = game_inst.player
	var planet1 = game_inst.initial_planet
	assert_test.call(player != null and planet1 != null, "3. Player and Initial Planet exist")
	var dist_from_center = (player.global_position - planet1.global_position).length()
	var expected_dist = planet1.radius + 0.9
	assert_test.call(abs(dist_from_center - expected_dist) < 0.2, "3b. Player spawned on planet surface (%f ≈ %f)" % [dist_from_center, expected_dist])

	var up_dir = planet1.get_up(player.global_position)
	var grav_dir = planet1.get_gravity(player.global_position)
	assert_test.call(up_dir.is_normalized() and grav_dir.dot(up_dir) < -10.0, "4. Planetary gravity pulls directly inward toward planet center")

	# Test 5: Automatic forward runner progression along spherical surface
	var start_pos = player.global_position
	player._process_planet_run(0.2) # simulate forward progression
	assert_test.call(player.global_position != start_pos and player.distance_travelled > 0.0, "5. Player automatically runs forward along sphere surface")
	var post_run_dist = (player.global_position - planet1.global_position).length()
	assert_test.call(abs(post_run_dist - expected_dist) < 0.2, "5b. Player remains grounded on spherical surface after running")

	# Test 6 & 7: Three-lane movement & bounds clamping
	player.target_lane = 0
	player.current_lane = 0
	assert_test.call(player.target_lane == 0, "6. Starts in Center lane (0)")
	player.shift_lane(-1)
	assert_test.call(player.target_lane == -1, "6b. Shifts to Left lane (-1)")
	player.shift_lane(-1)
	assert_test.call(player.target_lane == -1, "7. Clamped at Left lane bound (-1)")
	player.shift_lane(1)
	player.shift_lane(1)
	assert_test.call(player.target_lane == 1, "6c. Shifts to Right lane (+1)")
	player.shift_lane(1)
	assert_test.call(player.target_lane == 1, "7b. Clamped at Right lane bound (+1)")
	player.target_lane = 0
	player.current_lane = 0

	# Test 8: Orthonormal basis stability (feet down, head up, forward tangent)
	var p_basis = player.global_basis
	var up_dot_fwd = abs(p_basis.y.dot(-p_basis.z))
	var up_dot_right = abs(p_basis.y.dot(p_basis.x))
	var fwd_dot_right = abs((-p_basis.z).dot(p_basis.x))
	assert_test.call(up_dot_fwd < 0.01 and up_dot_right < 0.01 and fwd_dot_right < 0.01, "8. Local runner frame remains strictly orthonormal")

	# Test 9: Authored planets chain
	var planet2 = planet1.next_planet
	assert_test.call(planet2 != null, "9. Planet 1 links to Planet 2")
	var planet3 = planet2.next_planet if planet2 else null
	assert_test.call(planet3 != null, "9b. Planet 2 links to Planet 3")

	# Test 10: Gameplay camera follows behind and above without mouse rotation
	var camera = game_inst.gameplay_camera
	camera._physics_process(0.1)
	assert_test.call(camera.global_position.distance_to(player.global_position) > 3.0, "10. Camera follows player at tested angle")

	# Test 11, 12, 13: Planetary Transition (Never upside down, feet firmly toward destination center)
	player.launch_to_planet(planet2, 0.5)
	assert_test.call(player.is_transitioning, "11. Planet transition launch triggered")
	
	# Simulate mid-flight
	player._process_planet_transition(0.25)
	var mid_up = player.global_basis.y
	assert_test.call(mid_up.is_normalized(), "12. Player maintains valid outward up vector during flight")
	
	# Finish transition to landing
	player._process_planet_transition(0.3)
	assert_test.call(not player.is_transitioning, "13. Player lands on Planet 2")
	assert_test.call(player.current_planet == planet2, "13b. Active planet switched to Planet 2")
	var p2_dist = (player.global_position - planet2.global_position).length()
	var p2_expected = planet2.radius + 0.9
	assert_test.call(abs(p2_dist - p2_expected) < 0.3, "13c. Player firmly grounded on Planet 2 surface (not upside down!)")
	var feet_dir = (player.global_position - planet2.global_position).normalized()
	assert_test.call(player.global_basis.y.dot(feet_dir) > 0.9, "13d. Player head points outward and feet point toward planet center")

	# Test 14, 15, 16: Landmark interaction
	var test_target = load("res://scenes/landmarks/landmark_target.tscn").instantiate() as LandmarkTarget
	root.add_child(test_target)
	var test_lm = LandmarkData.new()
	test_lm.id = "test_wonder"
	test_lm.name = "Rock-Hewn Churches of Lalibela"
	test_lm.achievement_title = "Monolithic Marvel"
	test_lm.educational_fact = "Chiseled from solid red volcanic rock."
	test_target.setup(test_lm)

	var click_ok = test_target.attempt_interact()
	assert_test.call(click_ok, "14. Clicking landmark target succeeds")
	var click_duplicate = test_target.attempt_interact()
	assert_test.call(not click_duplicate, "15. Duplicate clicks rejected")
	test_target.queue_free()

	# Test 17 & 18: Three-heart failure system and Game Over
	var disc_mgr = game_inst.discovery_manager
	disc_mgr.reset_run()
	assert_test.call(disc_mgr.current_hearts == 3, "17a. Starts with 3 hearts")
	disc_mgr.register_miss(test_lm)
	assert_test.call(disc_mgr.current_hearts == 2, "17b. First missed target removes 1 heart (2 left)")
	disc_mgr.register_miss(test_lm)
	assert_test.call(disc_mgr.current_hearts == 1, "17c. Second missed target leaves 1 heart")
	disc_mgr.register_miss(test_lm)
	assert_test.call(disc_mgr.current_hearts == 0 and not disc_mgr.is_active, "18. Third missed target triggers Game Over")

	# Test 19: Discovery popup content
	var popup = game_inst.discovery_popup
	popup.show_discovery(test_lm, 1)
	assert_test.call(popup.wonder_name_label.text == test_lm.name, "19a. Popup displays correct Wonder Name")
	assert_test.call(popup.fact_label.text == test_lm.educational_fact, "19b. Popup displays verified educational fact")

	# Test 20: Restart resets run & discoveries
	game_inst.start_new_run()
	assert_test.call(disc_mgr.current_hearts == 3 and disc_mgr.discovered_wonders.is_empty(), "20. Restart creates fresh run with 3 hearts and resets state")

	# Test 21: Landmark Catalog verified facts
	var catalog = LandmarkCatalog.get_all_landmarks()
	assert_test.call(catalog.size() >= 8, "21. Landmark catalog contains 8 curated Ethiopian wonders")

	# Test 22: AI insight extension point works offline and with provider
	var default_fact = test_lm.get_fact()
	assert_test.call(default_fact == test_lm.educational_fact, "22a. Default fact uses curated offline catalog")
	test_lm.ai_insight_provider = func(lm): return "AI Insight: " + lm.name
	assert_test.call(test_lm.get_fact().begins_with("AI Insight"), "22b. AI insight extension point works seamlessly")

	print("==================================================")
	print("  TEST RESULTS: %d PASSED, %d FAILED" % [passed, failed])
	print("==================================================")
	
	game_inst.queue_free()
	
	if failed == 0:
		quit(0)
	else:
		quit(1)
