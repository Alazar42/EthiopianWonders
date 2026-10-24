class_name LandmarkBlockoutBuilder
extends RefCounted

## Builds stylized low-poly grayboxed blockouts for Ethiopian wonders.
## Easily replaced with final FBX/GLTF models later via exported scene references.

static func create_graybox(landmark_data: LandmarkData) -> Node3D:
	var root = Node3D.new()
	root.name = "LandmarkBlockout_" + (landmark_data.id if landmark_data else "Generic")
	
	var type = landmark_data.graybox_type if landmark_data else "generic"
	match type:
		"lalibela":
			_build_lalibela(root, landmark_data.color)
		"aksum":
			_build_aksum(root, landmark_data.color)
		"gondar":
			_build_gondar(root, landmark_data.color)
		"simien":
			_build_simien(root, landmark_data.color)
		"danakil":
			_build_danakil(root, landmark_data.color)
		"harar":
			_build_harar(root, landmark_data.color)
		"tiya":
			_build_tiya(root, landmark_data.color)
		"bale":
			_build_bale(root, landmark_data.color)
		_:
			_build_generic_monument(root, landmark_data.color if landmark_data else Color.ORANGE)
	
	return root

static func _build_lalibela(parent: Node3D, tint: Color) -> void:
	# Monolithic rock-hewn cross church blockout (e.g. Biete Ghyorgis)
	var rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.72, 0.38, 0.28) # Red volcanic tuff
	rock_mat.roughness = 0.9

	# Sunken courtyard trench blockout
	var pit = _create_box(Vector3(12, 1.0, 12), Color(0.55, 0.28, 0.20))
	pit.position = Vector3(0, -0.2, 0)
	parent.add_child(pit)

	# Central Greek cross church body
	var center = _create_box(Vector3(3.5, 6.0, 3.5), Color(0.75, 0.40, 0.30))
	center.position = Vector3(0, 3.0, 0)
	parent.add_child(center)

	var arm_x = _create_box(Vector3(7.5, 5.5, 2.5), Color(0.78, 0.42, 0.32))
	arm_x.position = Vector3(0, 2.75, 0)
	parent.add_child(arm_x)

	var arm_z = _create_box(Vector3(2.5, 5.5, 7.5), Color(0.78, 0.42, 0.32))
	arm_z.position = Vector3(0, 2.75, 0)
	parent.add_child(arm_z)

	# Stepped roof cross
	var roof = _create_box(Vector3(3.8, 0.4, 3.8), Color(0.85, 0.50, 0.38))
	roof.position = Vector3(0, 6.1, 0)
	parent.add_child(roof)

static func _build_aksum(parent: Node3D, tint: Color) -> void:
	# Tall monolithic granite stele
	var granite_mat = StandardMaterial3D.new()
	granite_mat.albedo_color = Color(0.68, 0.70, 0.74)
	granite_mat.roughness = 0.8

	# Stepped stone base
	var base1 = _create_box(Vector3(6, 0.8, 6), Color(0.55, 0.57, 0.60))
	base1.position = Vector3(0, 0.4, 0)
	parent.add_child(base1)

	var base2 = _create_box(Vector3(4.5, 0.8, 4.5), Color(0.60, 0.62, 0.65))
	base2.position = Vector3(0, 1.2, 0)
	parent.add_child(base2)

	# Main tapered obelisk shaft
	var shaft = _create_box(Vector3(2.2, 12.0, 1.8), Color(0.72, 0.74, 0.78))
	shaft.position = Vector3(0, 7.2, 0)
	parent.add_child(shaft)

	# Decorative horizontal bands
	for i in range(4):
		var band = _create_box(Vector3(2.4, 0.25, 2.0), Color(0.50, 0.52, 0.56))
		band.position = Vector3(0, 3.0 + i * 2.5, 0)
		parent.add_child(band)

	# Rounded apex crest
	var apex = _create_cylinder(0.9, 0.9, 1.2, Color(0.78, 0.80, 0.85))
	apex.position = Vector3(0, 13.5, 0)
	apex.rotation.x = PI / 2.0
	parent.add_child(apex)

static func _build_gondar(parent: Node3D, tint: Color) -> void:
	# Castle of Emperor Fasilides blockout
	var stone_color = Color(0.78, 0.68, 0.52)
	
	# Main keep fortress
	var keep = _create_box(Vector3(6.5, 6.0, 6.5), stone_color)
	keep.position = Vector3(0, 3.0, 0)
	parent.add_child(keep)

	# 4 Corner rounded towers
	var offsets = [Vector3(-3.2, 0, -3.2), Vector3(3.2, 0, -3.2), Vector3(-3.2, 0, 3.2), Vector3(3.2, 0, 3.2)]
	for off in offsets:
		var tower = _create_cylinder(1.2, 1.2, 7.5, Color(0.72, 0.62, 0.48))
		tower.position = off + Vector3(0, 3.75, 0)
		parent.add_child(tower)
		
		# Tower dome
		var dome = _create_sphere(1.3, Color(0.60, 0.48, 0.35))
		dome.position = off + Vector3(0, 7.5, 0)
		parent.add_child(dome)

	# Central watchtower
	var center_tower = _create_box(Vector3(3.0, 8.5, 3.0), Color(0.82, 0.72, 0.55))
	center_tower.position = Vector3(0, 4.25, 0)
	parent.add_child(center_tower)

static func _build_simien(parent: Node3D, tint: Color) -> void:
	# Dramatic jagged basalt peaks & escarpments
	var peak_color = Color(0.38, 0.42, 0.46)
	var snow_color = Color(0.65, 0.75, 0.60) # Alpine vegetation

	var p1 = _create_prism(Vector3(7, 9, 6), peak_color)
	p1.position = Vector3(-2, 4.5, 0)
	parent.add_child(p1)

	var p2 = _create_prism(Vector3(6, 11, 5), Color(0.34, 0.38, 0.42))
	p2.position = Vector3(2.5, 5.5, -1)
	parent.add_child(p2)

	var plateau = _create_box(Vector3(10, 2.5, 8), snow_color)
	plateau.position = Vector3(0, 1.25, 0)
	parent.add_child(plateau)

static func _build_danakil(parent: Node3D, tint: Color) -> void:
	# Shield volcano with glowing sulfur / lava crater
	var caldera = _create_cylinder(5.5, 3.5, 2.5, Color(0.30, 0.28, 0.26))
	caldera.position = Vector3(0, 1.25, 0)
	parent.add_child(caldera)

	# Glowing lava lake core
	var lava_mat = StandardMaterial3D.new()
	lava_mat.albedo_color = Color(1.0, 0.35, 0.05)
	lava_mat.emission_enabled = true
	lava_mat.emission = Color(1.0, 0.35, 0.05)
	lava_mat.emission_energy_multiplier = 3.0

	var lava = _create_cylinder(2.8, 2.8, 0.4, Color(1.0, 0.35, 0.05))
	lava.material_override = lava_mat
	lava.position = Vector3(0, 2.4, 0)
	parent.add_child(lava)

static func _build_harar(parent: Node3D, tint: Color) -> void:
	# Fortified historic gatehouse
	var wall_color = Color(0.88, 0.85, 0.78)
	var gate1 = _create_box(Vector3(2.2, 5.5, 2.2), wall_color)
	gate1.position = Vector3(-3.0, 2.75, 0)
	parent.add_child(gate1)

	var gate2 = _create_box(Vector3(2.2, 5.5, 2.2), wall_color)
	gate2.position = Vector3(3.0, 2.75, 0)
	parent.add_child(gate2)

	var lintel = _create_box(Vector3(7.5, 1.5, 2.0), Color(0.78, 0.72, 0.65))
	lintel.position = Vector3(0, 4.8, 0)
	parent.add_child(lintel)

	var arch = _create_box(Vector3(3.6, 3.8, 0.4), Color(0.2, 0.15, 0.1))
	arch.position = Vector3(0, 1.9, 0)
	parent.add_child(arch)

static func _build_tiya(parent: Node3D, tint: Color) -> void:
	# Cluster of carved megaliths
	for i in range(5):
		var angle = i * (PI * 2.0 / 5.0)
		var rad = 2.5 + (i % 2) * 1.0
		var h = 3.0 + (i % 3) * 0.8
		var stone = _create_box(Vector3(0.8, h, 0.3), Color(0.58, 0.56, 0.52))
		stone.position = Vector3(cos(angle) * rad, h * 0.5, sin(angle) * rad)
		stone.rotation.y = angle + 0.3
		parent.add_child(stone)

static func _build_bale(parent: Node3D, tint: Color) -> void:
	# Afro-alpine boulder formation & high peaks
	var b1 = _create_sphere(2.5, Color(0.45, 0.48, 0.40))
	b1.position = Vector3(-1.5, 1.8, 0)
	b1.scale = Vector3(1.2, 0.8, 1.0)
	parent.add_child(b1)

	var b2 = _create_sphere(2.0, Color(0.38, 0.42, 0.35))
	b2.position = Vector3(1.8, 1.5, 0.5)
	b2.scale = Vector3(1.0, 0.9, 1.1)
	parent.add_child(b2)

static func _build_generic_monument(parent: Node3D, color: Color) -> void:
	var b = _create_box(Vector3(4, 5, 4), color)
	b.position = Vector3(0, 2.5, 0)
	parent.add_child(b)

static func _create_box(size: Vector3, color: Color) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.mesh = mesh
	mi.material_override = mat
	return mi

static func _create_cylinder(r_top: float, r_bottom: float, h: float, color: Color) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = r_top
	mesh.bottom_radius = r_bottom
	mesh.height = h
	mesh.radial_segments = 12
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.mesh = mesh
	mi.material_override = mat
	return mi

static func _create_sphere(r: float, color: Color) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.mesh = mesh
	mi.material_override = mat
	return mi

static func _create_prism(size: Vector3, color: Color) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var mesh = PrismMesh.new()
	mesh.size = size
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mi.mesh = mesh
	mi.material_override = mat
	return mi
