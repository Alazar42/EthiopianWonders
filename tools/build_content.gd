extends SceneTree
## Offline content generator. Run from the project folder with:
##   godot --path . --rendering-driver opengl3 --script res://tools/build_content.gd
## (not --headless: the dummy renderer discards the grass MultiMesh instance data)
## It writes the authored assets the game loads (terrain meshes, grass, planet and landmark
## scenes). The output is plain .tscn / .res data: open it in the editor and move things around.
## Nothing here runs during gameplay.

const KENNEY: String = "res://assets/kenney_mini-forest_1.0/Models/GLB format/"
const MODEL_PATHS: Dictionary = {
	"tree": KENNEY + "tree.glb",
	"tree_high": KENNEY + "tree-high.glb",
	"rocks": KENNEY + "rocks-high.glb",
	"stones": KENNEY + "stones.glb",
	"plant": KENNEY + "plant.glb",
	"tent": KENNEY + "tent.glb",
	"flag": KENNEY + "flag.glb",
}
## Vertical offset (in model units, before scaling) so each model sits on the ground.
const MODEL_LIFT: Dictionary = {"rocks": 0.4, "plant": 0.02}

const BIOMES: Dictionary = {
	"highland": {
		"title": "Highland Meadow", "radius": 40.0, "seed": 11,
		"palette": [Color(0.30, 0.58, 0.24), Color(0.40, 0.68, 0.28), Color(0.50, 0.74, 0.30)],
		"patch": [Color(0.74, 0.62, 0.34), Color(0.62, 0.50, 0.28)],
		"patch_threshold": 0.30,
		"atmosphere": Color(0.55, 0.82, 1.0),
		"counts": {"tree": 120, "tree_high": 90, "rocks": 30, "stones": 150, "plant": 340, "tent": 3, "flag": 2},
		"grass": 3600,
	},
	"rift": {
		"title": "Rift Valley", "radius": 44.0, "seed": 23,
		"palette": [Color(0.74, 0.46, 0.26), Color(0.82, 0.58, 0.32), Color(0.88, 0.68, 0.40)],
		"patch": [Color(0.50, 0.58, 0.28), Color(0.58, 0.32, 0.20)],
		"patch_threshold": 0.35,
		"atmosphere": Color(1.0, 0.72, 0.5),
		"counts": {"tree": 46, "tree_high": 24, "rocks": 90, "stones": 220, "plant": 170, "tent": 6, "flag": 3},
		"grass": 1500,
	},
	"simien": {
		"title": "Simien Highlands", "radius": 38.0, "seed": 37,
		"palette": [Color(0.40, 0.45, 0.50), Color(0.48, 0.53, 0.56), Color(0.56, 0.60, 0.62)],
		"patch": [Color(0.36, 0.58, 0.32), Color(0.78, 0.82, 0.86)],
		"patch_threshold": 0.20,
		"atmosphere": Color(0.7, 0.85, 1.0),
		"counts": {"tree": 22, "tree_high": 44, "rocks": 150, "stones": 240, "plant": 130, "tent": 2, "flag": 4},
		"grass": 1100,
	},
	"danakil": {
		"title": "Danakil Sulfur Fields", "radius": 42.0, "seed": 41,
		"palette": [Color(0.84, 0.62, 0.22), Color(0.92, 0.78, 0.34), Color(0.74, 0.44, 0.20)],
		"patch": [Color(0.95, 0.93, 0.84), Color(0.70, 0.28, 0.16), Color(0.42, 0.36, 0.30)],
		"patch_threshold": 0.22,
		"atmosphere": Color(1.0, 0.65, 0.4),
		"counts": {"tree": 0, "tree_high": 0, "rocks": 130, "stones": 280, "plant": 40, "tent": 4, "flag": 3},
		"grass": 600,
	},
}

## Small, dense props are MultiMeshes (one draw call per kind); the rest are individual nodes that
## the route clears out of the lanes and that can be moved by hand in the editor.
const MULTIMESH_MODELS: Array = ["stones", "plant"]
const TUFT_HEIGHT: float = 0.95

## Scale range and minimum spacing (world units) per decoration type.
const SCALE_RANGE: Dictionary = {
	"tree": Vector2(2.0, 3.0), "tree_high": Vector2(2.0, 3.0), "rocks": Vector2(1.8, 4.5),
	"stones": Vector2(2.0, 3.4), "plant": Vector2(2.4, 4.0), "tent": Vector2(3.0, 3.6), "flag": Vector2(3.2, 3.8),
}
const SPACING: Dictionary = {
	"tree": 3.4, "tree_high": 3.4, "rocks": 3.2, "stones": 2.2, "plant": 1.8, "tent": 7.0, "flag": 6.0,
}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/meshes")
	DirAccess.make_dir_recursive_absolute("res://scenes/planets")
	DirAccess.make_dir_recursive_absolute("res://scenes/landmarks")
	for biome_id in BIOMES:
		_build_planet(biome_id, BIOMES[biome_id])
	_build_landmarks()
	print("build_content: done")
	quit()

# --- planets ----------------------------------------------------------------------------------------

func _build_planet(biome_id: String, cfg: Dictionary) -> void:
	var radius: float = cfg["radius"]
	var rng := RandomNumberGenerator.new()
	rng.seed = cfg["seed"]
	ResourceSaver.save(_terrain_mesh(biome_id, cfg, rng), "res://assets/meshes/terrain_%s.res" % biome_id)

	# Scenery, spaced out and kept off the tutorial runway at the planet's start point.
	var taken: Array[Dictionary] = []
	var placements: Array[Dictionary] = []
	for model_id in cfg["counts"]:
		var wanted: int = cfg["counts"][model_id]
		var tries: int = 0
		var placed: int = 0
		while placed < wanted and tries < wanted * 40:
			tries += 1
			var dir: Vector3 = _random_dir(rng)
			var pos: Vector3 = dir * radius
			if absf(pos.x) < 9.0 and pos.z < 6.0:
				continue
			var spacing: float = SPACING[model_id]
			if _too_close(dir, spacing, radius, taken):
				continue
			taken.append({"dir": dir, "spacing": spacing})
			var range_v: Vector2 = SCALE_RANGE[model_id]
			placements.append({
				"model": model_id, "dir": dir,
				"scale": rng.randf_range(range_v.x, range_v.y), "yaw": rng.randf() * TAU,
			})
			placed += 1

	# MultiMeshes: grass tufts plus the dense small props.
	var multimeshes: Dictionary = {}
	multimeshes["grass"] = _build_multimesh(_grass_tuft_mesh(), cfg["grass"], radius, rng, Vector2(0.8, 1.3), Transform3D.IDENTITY)
	for model_id in MULTIMESH_MODELS:
		var instances: Array[Dictionary] = []
		for p in placements:
			if p["model"] == model_id:
				instances.append(p)
		if instances.is_empty():
			continue
		var found: Array = _model_mesh(model_id)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = found[0]
		mm.instance_count = instances.size()
		for i in instances.size():
			var p: Dictionary = instances[i]
			var lift: float = MODEL_LIFT.get(model_id, 0.0) * p["scale"]
			mm.set_instance_transform(i, _surface_transform(p["dir"], radius, p["yaw"], p["scale"], -lift) * (found[1] as Transform3D))
		multimeshes[model_id] = mm
	for key in multimeshes:
		ResourceSaver.save(multimeshes[key], "res://assets/meshes/%s_%s.res" % [key, biome_id])

	var node_placements: Array[Dictionary] = []
	for p in placements:
		if not MULTIMESH_MODELS.has(p["model"]):
			node_placements.append(p)
	var text := _planet_scene_text(biome_id, cfg, node_placements, multimeshes.keys())
	var file := FileAccess.open("res://scenes/planets/planet_%s.tscn" % biome_id, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("planet_%s: %d scenery nodes, multimeshes %s" % [biome_id, node_placements.size(), str(multimeshes.keys())])

## A tuft of five bent blades (45 vertices), cheap enough to scatter thousands per planet.
## The wind shader bends it using height / mesh_height, so keep mesh_height at TUFT_HEIGHT.
func _grass_tuft_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in 5:
		var angle: float = TAU * float(i) / 5.0 + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var base: Vector3 = dir * rng.randf_range(0.0, 0.12)
		var height: float = rng.randf_range(0.6, TUFT_HEIGHT)
		var lean: Vector3 = dir * rng.randf_range(0.12, 0.3)
		var half_width: float = 0.085
		var bl: Vector3 = base - side * half_width
		var br: Vector3 = base + side * half_width
		var ml: Vector3 = base + lean * 0.4 + Vector3.UP * height * 0.55 - side * half_width * 0.6
		var mr: Vector3 = base + lean * 0.4 + Vector3.UP * height * 0.55 + side * half_width * 0.6
		var tip: Vector3 = base + lean + Vector3.UP * height
		for v in [bl, br, mr, bl, mr, ml, ml, mr, tip]:
			st.add_vertex(v)
	return st.commit()

func _build_multimesh(mesh: Mesh, count: int, radius: float, rng: RandomNumberGenerator, scale_range: Vector2, local: Transform3D) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	for i in count:
		var dir: Vector3 = _random_dir(rng)
		mm.set_instance_transform(i, _surface_transform(dir, radius, rng.randf() * TAU, rng.randf_range(scale_range.x, scale_range.y), 0.0) * local)
	return mm

## First mesh found in a model scene, plus that mesh node's transform inside the scene.
func _model_mesh(model_id: String) -> Array:
	var inst: Node = (load(MODEL_PATHS[model_id]) as PackedScene).instantiate()
	var found: Array = _find_mesh(inst, Transform3D.IDENTITY)
	inst.free()
	return found

func _find_mesh(node: Node, parent_xf: Transform3D) -> Array:
	var xf: Transform3D = parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		return [(node as MeshInstance3D).mesh, xf]
	for child in node.get_children():
		var result: Array = _find_mesh(child, xf)
		if not result.is_empty():
			return result
	return []

func _planet_scene_text(biome_id: String, cfg: Dictionary, placements: Array[Dictionary], multimesh_keys: Array) -> String:
	var radius: float = cfg["radius"]
	var used_models: Array[String] = []
	for p in placements:
		if not used_models.has(p["model"]):
			used_models.append(p["model"])
	var atmo: Color = cfg["atmosphere"]
	var out := PackedStringArray()
	out.append("[gd_scene load_steps=%d format=3]\n" % (used_models.size() + multimesh_keys.size() + 7))
	out.append('[ext_resource type="Script" path="res://scripts/planets/planet_controller.gd" id="1_script"]')
	out.append('[ext_resource type="ArrayMesh" path="res://assets/meshes/terrain_%s.res" id="2_terrain"]' % biome_id)
	out.append('[ext_resource type="Material" path="res://assets/materials/terrain.tres" id="3_terrain_mat"]')
	out.append('[ext_resource type="Shader" path="res://assets/shaders/atmosphere.gdshader" id="4_atmo_shader"]')
	for key in multimesh_keys:
		out.append('[ext_resource type="MultiMesh" path="res://assets/meshes/%s_%s.res" id="mm_%s"]' % [key, biome_id, key])
	out.append('[ext_resource type="Material" path="res://assets/materials/grass_%s.tres" id="6_grass_mat"]' % biome_id)
	for model_id in used_models:
		out.append('[ext_resource type="PackedScene" path="%s" id="m_%s"]' % [MODEL_PATHS[model_id], model_id])
	out.append("")
	out.append('[sub_resource type="ShaderMaterial" id="ShaderMaterial_atmo"]')
	out.append('render_priority = 1')
	out.append('shader = ExtResource("4_atmo_shader")')
	out.append('shader_parameter/glow_color = Color(%f, %f, %f, 1)' % [atmo.r, atmo.g, atmo.b])
	out.append('shader_parameter/rim_power = 3.5')
	out.append('shader_parameter/strength = 0.45')
	out.append("")
	out.append('[sub_resource type="SphereMesh" id="SphereMesh_atmo"]')
	out.append('radius = 1.0')
	out.append('height = 2.0')
	out.append('radial_segments = 40')
	out.append('rings = 20')
	out.append("")
	out.append('[node name="Planet%s" type="Node3D"]' % biome_id.capitalize())
	out.append('script = ExtResource("1_script")')
	out.append('planet_name = "%s"' % cfg["title"])
	out.append('radius = %s' % str(radius))
	out.append("")
	out.append('[node name="Terrain" type="MeshInstance3D" parent="."]')
	out.append('transform = %s' % var_to_str(Transform3D(Basis.from_scale(Vector3.ONE * radius), Vector3.ZERO)))
	out.append('material_override = ExtResource("3_terrain_mat")')
	out.append('mesh = ExtResource("2_terrain")')
	out.append("")
	out.append('[node name="Atmosphere" type="MeshInstance3D" parent="."]')
	out.append('transform = %s' % var_to_str(Transform3D(Basis.from_scale(Vector3.ONE * radius * 1.045), Vector3.ZERO)))
	out.append('cast_shadow = 0')
	out.append('material_override = SubResource("ShaderMaterial_atmo")')
	out.append('mesh = SubResource("SphereMesh_atmo")')
	out.append("")
	out.append('[node name="Scatter" type="Node3D" parent="."]')
	out.append("")
	for key in multimesh_keys:
		out.append('[node name="%s" type="MultiMeshInstance3D" parent="Scatter"]' % key.capitalize())
		if key == "grass":
			out.append('material_override = ExtResource("6_grass_mat")')
			out.append('cast_shadow = 0')
		out.append('multimesh = ExtResource("mm_%s")' % key)
		out.append("")
	out.append('[node name="Decorations" type="Node3D" parent="."]')
	out.append("")
	var counters: Dictionary = {}
	for p in placements:
		var model_id: String = p["model"]
		counters[model_id] = int(counters.get(model_id, 0)) + 1
		var lift: float = MODEL_LIFT.get(model_id, 0.0) * p["scale"]
		var xf := _surface_transform(p["dir"], radius, p["yaw"], p["scale"], -lift)
		out.append('[node name="%s_%03d" parent="Decorations" instance=ExtResource("m_%s")]' % [
			model_id.capitalize().replace(" ", ""), counters[model_id], model_id])
		out.append('transform = %s' % var_to_str(xf))
		out.append("")
	return "\n".join(out)

# --- terrain mesh -------------------------------------------------------------------------------------

func _terrain_mesh(biome_id: String, cfg: Dictionary, rng: RandomNumberGenerator) -> ArrayMesh:
	var ico := _icosphere(4)
	var verts: PackedVector3Array = ico[0]
	var faces: Array = ico[1]
	var base := FastNoiseLite.new()
	base.seed = cfg["seed"]
	base.frequency = 1.0
	var patch := FastNoiseLite.new()
	patch.seed = cfg["seed"] + 100
	patch.frequency = 1.0
	var palette: Array = cfg["palette"]
	var patches: Array = cfg["patch"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in faces:
		var a: Vector3 = verts[face[0]]
		var b: Vector3 = verts[face[1]]
		var c: Vector3 = verts[face[2]]
		var center: Vector3 = (a + b + c) / 3.0
		var outward: Vector3 = center.normalized()
		# Godot treats clockwise triangles (seen from outside) as front faces.
		if (b - a).cross(c - a).dot(outward) > 0.0:
			var swap: Vector3 = b
			b = c
			c = swap
		var n1: float = clampf(base.get_noise_3d(center.x * 2.4, center.y * 2.4, center.z * 2.4) * 0.5 + 0.5, 0.0, 0.999)
		# Smooth gradient across the palette.
		var scaled: float = n1 * float(palette.size() - 1)
		var lo: int = int(scaled)
		var color: Color = (palette[lo] as Color).lerp(palette[mini(lo + 1, palette.size() - 1)], scaled - float(lo))
		var n2: float = patch.get_noise_3d(center.x * 1.8, center.y * 1.8, center.z * 1.8)
		var threshold: float = cfg["patch_threshold"]
		if n2 > threshold:
			var strength: float = smoothstep(threshold, threshold + 0.18, n2)
			var patch_color: Color = patches[int(n1 * 5.0) % patches.size()]
			color = color.lerp(patch_color, strength)
		var shade: float = rng.randf_range(0.96, 1.04)
		color = Color(color.r * shade, color.g * shade, color.b * shade)
		for v in [a, b, c]:
			st.set_color(color)
			st.set_normal(outward)
			st.add_vertex(v)
	return st.commit()

func _icosphere(level: int) -> Array:
	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var verts := PackedVector3Array([
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1),
	])
	for i in verts.size():
		verts[i] = verts[i].normalized()
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	for _i in level:
		var cache: Dictionary = {}
		var next_faces: Array = []
		for f in faces:
			var ab: int = _midpoint(verts, cache, f[0], f[1])
			var bc: int = _midpoint(verts, cache, f[1], f[2])
			var ca: int = _midpoint(verts, cache, f[2], f[0])
			next_faces.append([f[0], ab, ca])
			next_faces.append([f[1], bc, ab])
			next_faces.append([f[2], ca, bc])
			next_faces.append([ab, bc, ca])
		faces = next_faces
	return [verts, faces]

func _midpoint(verts: PackedVector3Array, cache: Dictionary, i: int, j: int) -> int:
	var key: int = mini(i, j) * 100000 + maxi(i, j)
	if cache.has(key):
		return cache[key]
	verts.append(((verts[i] + verts[j]) * 0.5).normalized())
	cache[key] = verts.size() - 1
	return verts.size() - 1

# --- placement helpers ----------------------------------------------------------------------------------

func _random_dir(rng: RandomNumberGenerator) -> Vector3:
	var z: float = rng.randf_range(-1.0, 1.0)
	var a: float = rng.randf() * TAU
	var r: float = sqrt(1.0 - z * z)
	return Vector3(r * cos(a), z, r * sin(a))

func _too_close(dir: Vector3, spacing: float, radius: float, taken: Array[Dictionary]) -> bool:
	for other in taken:
		var min_dist: float = maxf(spacing, other["spacing"])
		if dir.dot(other["dir"]) > cos(min_dist / radius):
			return true
	return false

func _surface_transform(dir: Vector3, radius: float, yaw: float, scale_factor: float, sink: float) -> Transform3D:
	var tangent: Vector3 = dir.cross(Vector3.RIGHT)
	if tangent.length() < 0.2:
		tangent = dir.cross(Vector3.FORWARD)
	tangent = tangent.normalized()
	var basis := Basis(tangent, dir, tangent.cross(dir)).rotated(dir, yaw)
	basis = basis.scaled_local(Vector3.ONE * scale_factor)
	return Transform3D(basis, dir * (radius + sink))

# --- landmarks ----------------------------------------------------------------------------------------

func _build_landmarks() -> void:
	_write_scene("lalibela", _fbx_landmark("lalibela", "res://assets/artifacts/lalibela.fbx",
		"res://assets/materials/artifact_lalibela.tres", 12.0, Color(0.55, 0.30, 0.22)))
	_write_scene("aksum", _fbx_landmark("aksum", "res://assets/artifacts/axum.fbx",
		"res://assets/materials/artifact_axum.tres", 12.0, Color(0.55, 0.55, 0.55)))
	_write_scene("gondar", _fbx_landmark("gondar", "res://assets/artifacts/fasiledes gondor.fbx",
		"res://assets/materials/artifact_fasiledes.tres", 14.0, Color(0.62, 0.52, 0.38)))
	_write_scene("simien", _graybox_simien())
	_write_scene("danakil", _graybox_danakil())
	_write_scene("harar", _graybox_harar())
	_write_scene("tiya", _graybox_tiya())
	_write_scene("bale", _graybox_bale())

func _write_scene(id: String, text: String) -> void:
	var file := FileAccess.open("res://scenes/landmarks/landmark_%s.tscn" % id, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("landmark_%s written" % id)

## Small helper that accumulates ext/sub resources and nodes for a landmark scene.
class SceneText:
	var ext: PackedStringArray = PackedStringArray()
	var sub: PackedStringArray = PackedStringArray()
	var nodes: PackedStringArray = PackedStringArray()
	var _ext_ids: Dictionary = {}
	var _sub_count: int = 0

	func ext_resource(type: String, path: String) -> String:
		if not _ext_ids.has(path):
			var id: String = "ext_%d" % _ext_ids.size()
			_ext_ids[path] = id
			ext.append('[ext_resource type="%s" path="%s" id="%s"]' % [type, path, id])
		return _ext_ids[path]

	func material(color: Color, emissive: bool = false) -> String:
		_sub_count += 1
		var id: String = "mat_%d" % _sub_count
		sub.append('[sub_resource type="StandardMaterial3D" id="%s"]' % id)
		sub.append('albedo_color = Color(%f, %f, %f, 1)' % [color.r, color.g, color.b])
		sub.append('roughness = 0.9')
		if emissive:
			sub.append('emission_enabled = true')
			sub.append('emission = Color(%f, %f, %f, 1)' % [color.r, color.g, color.b])
			sub.append('emission_energy_multiplier = 1.2')
		sub.append("")
		return id

	func box(size: Vector3, mat_id: String) -> String:
		_sub_count += 1
		var id: String = "box_%d" % _sub_count
		sub.append('[sub_resource type="BoxMesh" id="%s"]' % id)
		sub.append('material = SubResource("%s")' % mat_id)
		sub.append('size = Vector3(%f, %f, %f)' % [size.x, size.y, size.z])
		sub.append("")
		return id

	func cylinder(top: float, bottom: float, height: float, mat_id: String) -> String:
		_sub_count += 1
		var id: String = "cyl_%d" % _sub_count
		sub.append('[sub_resource type="CylinderMesh" id="%s"]' % id)
		sub.append('material = SubResource("%s")' % mat_id)
		sub.append('top_radius = %f' % top)
		sub.append('bottom_radius = %f' % bottom)
		sub.append('height = %f' % height)
		sub.append('radial_segments = 24')
		sub.append('rings = 1')
		sub.append("")
		return id

	func mesh_node(node_name: String, mesh_id: String, xf: Transform3D) -> void:
		nodes.append('[node name="%s" type="MeshInstance3D" parent="."]' % node_name)
		nodes.append('transform = %s' % var_to_str(xf))
		nodes.append('mesh = SubResource("%s")' % mesh_id)
		nodes.append("")

	func model_node(node_name: String, path: String, xf: Transform3D) -> void:
		var id: String = ext_resource("PackedScene", path)
		nodes.append('[node name="%s" parent="." instance=ExtResource("%s")]' % [node_name, id])
		nodes.append('transform = %s' % var_to_str(xf))
		nodes.append("")

	func build(root_name: String) -> String:
		var parts := PackedStringArray()
		parts.append("[gd_scene load_steps=%d format=3]\n" % (ext.size() + _sub_count + 1))
		parts.append("\n".join(ext))
		parts.append("")
		parts.append("\n".join(sub))
		parts.append('[node name="%s" type="Node3D"]' % root_name)
		parts.append("metadata/graybox = true")
		parts.append("")
		parts.append("\n".join(nodes))
		return "\n".join(parts)

func _plinth(s: SceneText, color: Color, radius: float) -> void:
	var m: String = s.material(color)
	var cyl: String = s.cylinder(radius, radius * 1.04, 1.8, m)
	s.mesh_node("Plinth", cyl, Transform3D(Basis.IDENTITY, Vector3(0, -0.6, 0)))

func _fbx_landmark(id: String, model: String, material_path: String, scale_factor: float, plinth_color: Color) -> String:
	var s := SceneText.new()
	_plinth(s, plinth_color, 8.0)
	var model_id: String = s.ext_resource("PackedScene", model)
	var mat_id: String = s.ext_resource("Material", material_path)
	s.nodes.append('[node name="Model" parent="." instance=ExtResource("%s")]' % model_id)
	s.nodes.append('transform = %s' % var_to_str(Transform3D(Basis.from_scale(Vector3.ONE * scale_factor), Vector3(0, 0.3, 0))))
	s.nodes.append("")
	s.nodes.append('[node name="node_0" parent="Model" index="0"]')
	s.nodes.append('material_override = ExtResource("%s")' % mat_id)
	s.nodes.append("")
	return s.build("Landmark" + id.capitalize())

func _graybox_simien() -> String:
	var s := SceneText.new()
	_plinth(s, Color(0.40, 0.44, 0.46), 9.0)
	for i in 6:
		var angle: float = float(i) / 6.0 * TAU
		var scale_factor: float = 6.0 + float(i % 3) * 2.5
		var xf := Transform3D(Basis.from_scale(Vector3.ONE * scale_factor).rotated(Vector3.UP, angle),
			Vector3(cos(angle) * 3.0, scale_factor * 0.4, sin(angle) * 3.0))
		s.model_node("Rocks%d" % i, MODEL_PATHS["rocks"], xf)
	for i in 4:
		var angle: float = float(i) / 4.0 * TAU + 0.4
		s.model_node("Tree%d" % i, MODEL_PATHS["tree_high"],
			Transform3D(Basis.from_scale(Vector3.ONE * 3.0), Vector3(cos(angle) * 6.5, 0.2, sin(angle) * 6.5)))
	return s.build("LandmarkSimien")

func _graybox_danakil() -> String:
	var s := SceneText.new()
	_plinth(s, Color(0.85, 0.72, 0.30), 9.0)
	var pool_mat: String = s.material(Color(0.95, 0.45, 0.12), true)
	var pool: String = s.cylinder(5.0, 5.0, 0.3, pool_mat)
	s.mesh_node("Pool", pool, Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)))
	var salt_mat: String = s.material(Color(0.95, 0.93, 0.82))
	var rim: String = s.cylinder(6.4, 6.4, 0.2, salt_mat)
	s.mesh_node("SaltRim", rim, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)))
	for i in 7:
		var angle: float = float(i) / 7.0 * TAU
		s.model_node("Rocks%d" % i, MODEL_PATHS["rocks"],
			Transform3D(Basis.from_scale(Vector3.ONE * 3.2).rotated(Vector3.UP, angle),
				Vector3(cos(angle) * 7.5, 1.4, sin(angle) * 7.5)))
	return s.build("LandmarkDanakil")

func _graybox_harar() -> String:
	var s := SceneText.new()
	_plinth(s, Color(0.70, 0.62, 0.46), 9.0)
	var wall_mat: String = s.material(Color(0.84, 0.74, 0.55))
	var wall: String = s.box(Vector3(14, 4.0, 1.4), wall_mat)
	s.mesh_node("Wall", wall, Transform3D(Basis.IDENTITY, Vector3(0, 2.3, 0)))
	var pillar: String = s.box(Vector3(2.2, 6.4, 2.2), wall_mat)
	s.mesh_node("PillarLeft", pillar, Transform3D(Basis.IDENTITY, Vector3(-3.2, 3.5, 0)))
	s.mesh_node("PillarRight", pillar, Transform3D(Basis.IDENTITY, Vector3(3.2, 3.5, 0)))
	var lintel: String = s.box(Vector3(8.6, 1.4, 2.0), wall_mat)
	s.mesh_node("Lintel", lintel, Transform3D(Basis.IDENTITY, Vector3(0, 5.6, 0)))
	for i in 5:
		var merlon: String = s.box(Vector3(1.4, 1.0, 1.4), wall_mat)
		s.mesh_node("Merlon%d" % i, merlon, Transform3D(Basis.IDENTITY, Vector3(-6.0 + float(i) * 3.0, 4.8, 0)))
	s.model_node("Tent", MODEL_PATHS["tent"], Transform3D(Basis.from_scale(Vector3.ONE * 3.0), Vector3(0, 0.3, -5.0)))
	return s.build("LandmarkHarar")

func _graybox_tiya() -> String:
	var s := SceneText.new()
	_plinth(s, Color(0.50, 0.46, 0.40), 9.0)
	var stone_mat: String = s.material(Color(0.58, 0.55, 0.50))
	for row in 2:
		for i in 5:
			var height: float = 3.6 + float((i + row * 2) % 3) * 0.9
			var stone: String = s.box(Vector3(0.9, height, 0.4), stone_mat)
			var x: float = -6.0 + float(i) * 3.0
			var xf := Transform3D(Basis.IDENTITY.rotated(Vector3.FORWARD, (float(i % 3) - 1.0) * 0.06),
				Vector3(x, height * 0.5 + 0.2, -2.0 + float(row) * 4.0))
			s.mesh_node("Stone_%d_%d" % [row, i], stone, xf)
	return s.build("LandmarkTiya")

func _graybox_bale() -> String:
	var s := SceneText.new()
	_plinth(s, Color(0.40, 0.55, 0.42), 9.0)
	for i in 5:
		var angle: float = float(i) / 5.0 * TAU
		s.model_node("Lobelia%d" % i, MODEL_PATHS["tree_high"],
			Transform3D(Basis.from_scale(Vector3.ONE * 3.4), Vector3(cos(angle) * 4.5, 0.2, sin(angle) * 4.5)))
	for i in 6:
		var angle: float = float(i) / 6.0 * TAU + 0.5
		s.model_node("Stones%d" % i, MODEL_PATHS["stones"],
			Transform3D(Basis.from_scale(Vector3.ONE * 3.6).rotated(Vector3.UP, angle),
				Vector3(cos(angle) * 7.0, 0.2, sin(angle) * 7.0)))
	for i in 8:
		var angle: float = float(i) / 8.0 * TAU + 0.2
		s.model_node("Plant%d" % i, MODEL_PATHS["plant"],
			Transform3D(Basis.from_scale(Vector3.ONE * 4.2), Vector3(cos(angle) * 2.2, 0.3, sin(angle) * 2.2)))
	return s.build("LandmarkBale")
