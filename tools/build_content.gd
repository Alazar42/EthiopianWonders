extends SceneTree
## Offline content generator. Run from the project folder with:
##   godot --path . --rendering-driver opengl3 --script res://tools/build_content.gd
## (not --headless: the dummy renderer discards MultiMesh instance data)
##
## It writes everything the game loads that is too tedious to place by hand:
##   assets/meshes/        terrain, props, landmark models, grass and scatter MultiMeshes
##   scenes/planets/       one authored scene per world (terrain, atmosphere, scenery, clouds)
##   scenes/landmarks/     one scenery scene per wonder
##   scenes/game/space_backdrop.tscn   the far-away planets and dust that make space feel endless
## The output is plain .tscn / .res data: open it in the editor and move things around.
## Re-running overwrites hand edits to those files. Nothing here runs during gameplay.

const PropMeshes = preload("res://tools/prop_meshes.gd")
const LandmarkMeshes = preload("res://tools/landmark_meshes.gd")
const LandmarkMeshesExtra = preload("res://tools/landmark_meshes_extra.gd")
const SpaceMeshes = preload("res://tools/space_meshes.gd")

const KENNEY: String = "res://assets/kenney_mini-forest_1.0/Models/GLB format/"
const TERRAIN_MATERIAL: String = "res://assets/materials/terrain.tres"

## Every kind of scenery. "model" = Kenney scene; "builder" = procedural mesh from PropMeshes.
## scale = uniform range; scale_xz / scale_y = separate ranges (mountains). clearance = radius
## (world units) the route keeps clear around the object. multi = dense MultiMesh, not nodes.
const PROPS: Dictionary = {
	"tree": {"model": "tree.glb", "scale": Vector2(2.0, 3.0), "spacing": 3.4, "clearance": 1.8},
	"tree_high": {"model": "tree-high.glb", "scale": Vector2(2.0, 3.0), "spacing": 3.4, "clearance": 1.8},
	"rocks": {"model": "rocks-high.glb", "lift": 0.4, "scale": Vector2(1.8, 4.5), "spacing": 3.2, "clearance": 2.6},
	"stones": {"model": "stones.glb", "scale": Vector2(2.0, 3.4), "spacing": 2.2, "multi": true},
	"plant": {"model": "plant.glb", "lift": 0.02, "scale": Vector2(2.4, 4.0), "spacing": 1.8, "multi": true},
	"tent": {"model": "tent.glb", "scale": Vector2(3.0, 3.6), "spacing": 7.0, "clearance": 3.6},
	"acacia": {"builder": "acacia", "scale": Vector2(1.3, 2.0), "spacing": 6.0, "clearance": 4.0},
	"eucalyptus": {"builder": "eucalyptus", "scale": Vector2(1.2, 1.8), "spacing": 3.0, "clearance": 1.4},
	"tukul": {"builder": "tukul", "scale": Vector2(1.3, 1.8), "spacing": 5.0, "clearance": 3.6, "cluster": 3},
	"amba": {"builder": "amba", "scale_xz": Vector2(6.0, 11.0), "scale_y": Vector2(7.0, 15.0), "spacing": 18.0, "clearance": 9.0},
	"columns": {"builder": "basalt_columns", "scale": Vector2(2.0, 3.6), "spacing": 6.0, "clearance": 5.5},
	"volcano": {"builder": "volcano", "scale_xz": Vector2(7.0, 11.0), "scale_y": Vector2(6.0, 10.0), "spacing": 22.0, "clearance": 9.0},
	"lobelia": {"builder": "lobelia", "scale": Vector2(1.6, 2.4), "spacing": 2.6, "clearance": 1.3},
	"lobelia_spike": {"builder": "lobelia_spike", "scale": Vector2(1.4, 2.2), "spacing": 3.0, "clearance": 1.0},
	"helichrysum": {"builder": "helichrysum", "scale": Vector2(1.2, 2.0), "spacing": 1.6, "multi": true},
	"flower": {"builder": "meskel_flower", "scale": Vector2(1.5, 2.4), "spacing": 0.9, "multi": true},
	"steam": {"builder": "steam", "scale": Vector2(1.2, 1.8), "spacing": 12.0, "clearance": 3.0},
}

## The five worlds. Colours are sRGB. `mood` tints the sky and fog while you travel there.
const BIOMES: Dictionary = {
	"highland": {
		"title": "Highland Farmland", "radius": 40.0, "seed": 11,
		"palette": [Color(0.30, 0.58, 0.24), Color(0.40, 0.68, 0.28), Color(0.50, 0.74, 0.30)],
		"patch": [Color(0.74, 0.62, 0.34), Color(0.62, 0.50, 0.28)], "patch_threshold": 0.38,
		"fields": {"colors": [Color(0.86, 0.74, 0.30), Color(0.66, 0.78, 0.32), Color(0.58, 0.40, 0.26)], "scale": 4.5, "probability": 0.34},
		"atmosphere": Color(0.55, 0.82, 1.0), "grass": 2800, "clouds": 10,
		"mood": {"ambient": Color(0.62, 0.70, 0.82), "fog": Color(0.72, 0.84, 0.96)},
		"counts": {"eucalyptus": 70, "tukul": 7, "tree_high": 30, "tree": 10, "rocks": 20, "stones": 120, "plant": 220, "amba": 5, "flower": 1500},
	},
	"rift": {
		"title": "Rift Valley Lakes", "radius": 44.0, "seed": 23,
		"palette": [Color(0.70, 0.48, 0.32), Color(0.78, 0.56, 0.36), Color(0.64, 0.44, 0.32)],
		"patch": [Color(0.52, 0.56, 0.30), Color(0.46, 0.30, 0.24)], "patch_threshold": 0.32,
		"lake": {"color": Color(0.30, 0.62, 0.52), "shore": Color(0.86, 0.74, 0.52), "threshold": 0.42, "scale": 1.7},
		"atmosphere": Color(1.0, 0.72, 0.5), "grass": 1300, "clouds": 8,
		"mood": {"ambient": Color(0.72, 0.68, 0.66), "fog": Color(0.90, 0.80, 0.68)},
		"counts": {"acacia": 60, "tree": 6, "rocks": 40, "stones": 170, "plant": 100, "tukul": 6, "amba": 3},
	},
	"simien": {
		"title": "Simien Escarpment", "radius": 38.0, "seed": 37,
		"palette": [Color(0.62, 0.52, 0.38), Color(0.70, 0.60, 0.44), Color(0.54, 0.46, 0.34)],
		"patch": [Color(0.46, 0.54, 0.30), Color(0.34, 0.33, 0.34)], "patch_threshold": 0.22,
		"atmosphere": Color(0.7, 0.85, 1.0), "grass": 900, "clouds": 14,
		"mood": {"ambient": Color(0.60, 0.70, 0.88), "fog": Color(0.78, 0.86, 0.96)},
		"counts": {"columns": 14, "amba": 7, "lobelia": 30, "tree_high": 10, "rocks": 80, "stones": 180, "plant": 70},
	},
	"danakil": {
		"title": "Danakil Salt and Fire", "radius": 42.0, "seed": 41,
		"palette": [Color(0.84, 0.68, 0.34), Color(0.76, 0.52, 0.28), Color(0.90, 0.78, 0.46)],
		"patch": [Color(0.24, 0.22, 0.22), Color(0.32, 0.28, 0.26), Color(0.95, 0.93, 0.86)], "patch_threshold": 0.15,
		"pools": {"colors": [Color(0.55, 0.80, 0.15, 0.4), Color(0.96, 0.52, 0.10, 0.35), Color(0.98, 0.88, 0.20, 0.4), Color(0.25, 0.72, 0.55, 0.4)],
			"rim": Color(0.95, 0.93, 0.84), "threshold": 0.60},
		"atmosphere": Color(1.0, 0.65, 0.4), "grass": 400, "clouds": 5,
		"mood": {"ambient": Color(0.74, 0.66, 0.62), "fog": Color(0.92, 0.72, 0.56)},
		"counts": {"volcano": 3, "steam": 4, "columns": 16, "rocks": 70, "stones": 160, "plant": 20, "tent": 4},
	},
	"bale": {
		"title": "Bale Afro-alpine Moor", "radius": 41.0, "seed": 53,
		"palette": [Color(0.50, 0.52, 0.38), Color(0.58, 0.60, 0.46), Color(0.42, 0.46, 0.34)],
		"patch": [Color(0.74, 0.78, 0.76), Color(0.64, 0.68, 0.66)], "patch_threshold": 0.10,
		"lake": {"color": Color(0.36, 0.52, 0.58), "shore": Color(0.62, 0.66, 0.60), "threshold": 0.58, "scale": 1.8},
		"atmosphere": Color(0.75, 0.88, 0.95), "grass": 1700, "clouds": 12,
		"mood": {"ambient": Color(0.62, 0.74, 0.80), "fog": Color(0.80, 0.90, 0.95)},
		"counts": {"lobelia": 90, "lobelia_spike": 50, "helichrysum": 260, "rocks": 50, "stones": 150, "plant": 70, "amba": 2},
	},
}

const TUFT_HEIGHT: float = 0.95
const CLOUD_VARIANTS: int = 3

# --- entry point ------------------------------------------------------------------------------------

func _init() -> void:
	for dir in ["res://assets/meshes/props", "res://assets/meshes/landmarks", "res://scenes/planets",
			"res://scenes/landmarks", "res://scenes/game", "res://assets/meshes/space", "res://scenes/space"]:
		DirAccess.make_dir_recursive_absolute(dir)
	_save_prop_meshes()
	_save_landmark_meshes()
	for biome_id in BIOMES:
		_build_planet(biome_id, BIOMES[biome_id])
	_build_backdrop()
	_build_landmarks()
	_build_space_objects()
	print("build_content: done")
	quit()

func _prop_mesh_path(prop_id: String) -> String:
	return "res://assets/meshes/props/%s.res" % prop_id

func _save_prop_meshes() -> void:
	for prop_id in PROPS:
		var cfg: Dictionary = PROPS[prop_id]
		if cfg.has("builder"):
			ResourceSaver.save(_build_prop(cfg["builder"]), _prop_mesh_path(prop_id))
	ResourceSaver.save(_grass_tuft_mesh(), "res://assets/meshes/props/grass_tuft.res")
	ResourceSaver.save(PropMeshes.spaceship(), "res://assets/meshes/props/spaceship.res")
	ResourceSaver.save(PropMeshes.obstacle_boulder(), "res://assets/meshes/props/obstacle_boulder.res")
	ResourceSaver.save(PropMeshes.obstacle_stones(), "res://assets/meshes/props/obstacle_stones.res")
	ResourceSaver.save(PropMeshes.obstacle_spire(), "res://assets/meshes/props/obstacle_spire.res")
	for variant in CLOUD_VARIANTS:
		ResourceSaver.save(PropMeshes.cloud(variant), "res://assets/meshes/props/cloud_%d.res" % variant)

func _build_prop(builder: String) -> ArrayMesh:
	match builder:
		"acacia": return PropMeshes.acacia()
		"eucalyptus": return PropMeshes.eucalyptus()
		"tukul": return PropMeshes.tukul()
		"amba": return PropMeshes.amba()
		"basalt_columns": return PropMeshes.basalt_columns()
		"volcano": return PropMeshes.volcano()
		"lobelia": return PropMeshes.lobelia()
		"lobelia_spike": return PropMeshes.lobelia_spike()
		"helichrysum": return PropMeshes.helichrysum()
		"meskel_flower": return PropMeshes.meskel_flower()
		"steam": return PropMeshes.steam()
	push_error("unknown prop builder " + builder)
	return null

const LANDMARK_MESHES: Array = [
	"aksum_stele", "fasil_castle", "fasilides_bath", "yeha_temple", "church_small", "ura_kidane",
	"abuna_yemata", "konso_village", "blue_nile_falls", "harar_gate", "tiya_stelae", "simien_crag", "danakil_salt",
	"adwa_monument", "lake_tana", "sof_omar", "wenchi_crater", "entoto_observatory", "lucy_hadar", "dorze_huts",
]

func _save_landmark_meshes() -> void:
	for mesh_id in LANDMARK_MESHES:
		var mesh: ArrayMesh = _landmark_mesh(mesh_id)
		ResourceSaver.save(mesh, "res://assets/meshes/landmarks/%s.res" % mesh_id)

func _landmark_mesh(mesh_id: String) -> ArrayMesh:
	match mesh_id:
		"aksum_stele": return LandmarkMeshes.aksum_stele()
		"fasil_castle": return LandmarkMeshes.fasil_castle()
		"fasilides_bath": return LandmarkMeshes.fasilides_bath()
		"yeha_temple": return LandmarkMeshes.yeha_temple()
		"church_small": return LandmarkMeshes.church_small()
		"ura_kidane": return LandmarkMeshes.ura_kidane()
		"abuna_yemata": return LandmarkMeshes.abuna_yemata()
		"konso_village": return LandmarkMeshes.konso_village()
		"blue_nile_falls": return LandmarkMeshes.blue_nile_falls()
		"harar_gate": return LandmarkMeshes.harar_gate()
		"tiya_stelae": return LandmarkMeshes.tiya_stelae()
		"simien_crag": return LandmarkMeshes.simien_crag()
		"danakil_salt": return LandmarkMeshes.danakil_salt()
		"adwa_monument": return LandmarkMeshesExtra.adwa_monument()
		"lake_tana": return LandmarkMeshesExtra.lake_tana()
		"sof_omar": return LandmarkMeshesExtra.sof_omar()
		"wenchi_crater": return LandmarkMeshesExtra.wenchi_crater()
		"entoto_observatory": return LandmarkMeshesExtra.entoto_observatory()
		"lucy_hadar": return LandmarkMeshesExtra.lucy_hadar()
		"dorze_huts": return LandmarkMeshesExtra.dorze_huts()
	push_error("unknown landmark mesh " + mesh_id)
	return null

# --- terrain colouring ---------------------------------------------------------------------------------

## Decides, for any point on a unit sphere, what the ground is: land, lake, shore or acid pool.
## Shared by the terrain mesh and by scenery placement so trees never stand in lakes.
class TerrainField:
	var cfg: Dictionary
	var base := FastNoiseLite.new()
	var patch := FastNoiseLite.new()
	var lake := FastNoiseLite.new()
	var pool := FastNoiseLite.new()

	func _init(p_cfg: Dictionary) -> void:
		cfg = p_cfg
		var seed_value: int = cfg["seed"]
		for noise in [base, patch, lake, pool]:
			noise.frequency = 1.0
		base.seed = seed_value
		patch.seed = seed_value + 100
		lake.seed = seed_value + 200
		pool.seed = seed_value + 300

	static func hash3(v: Vector3) -> float:
		var h: float = sin(v.dot(Vector3(12.9898, 78.233, 37.719))) * 43758.5453
		return h - floorf(h)

	func sample(d: Vector3) -> Dictionary:
		var palette: Array = cfg["palette"]
		var n1: float = clampf(base.get_noise_3d(d.x * 2.4, d.y * 2.4, d.z * 2.4) * 0.5 + 0.5, 0.0, 0.999)
		var scaled: float = n1 * float(palette.size() - 1)
		var lo: int = int(scaled)
		var color: Color = (palette[lo] as Color).lerp(palette[mini(lo + 1, palette.size() - 1)], scaled - float(lo))
		var kind: String = "land"
		var patches: Array = cfg["patch"]
		var n2: float = patch.get_noise_3d(d.x * 1.8, d.y * 1.8, d.z * 1.8)
		var threshold: float = cfg["patch_threshold"]
		if n2 > threshold:
			var strength: float = smoothstep(threshold, threshold + 0.18, n2)
			color = color.lerp(patches[int(n1 * 5.0) % patches.size()], strength)
		if cfg.has("fields"):
			# Patchwork farmland: whole grid cells switch to a crop or tilled-soil colour.
			var fields: Dictionary = cfg["fields"]
			var cell: Vector3 = (d * float(fields["scale"])).floor()
			var h: float = hash3(cell)
			if h < float(fields["probability"]):
				var crops: Array = fields["colors"]
				var crop: Color = crops[int(h * 1000.0) % crops.size()]
				var tint: float = 0.92 + hash3(cell + Vector3.ONE) * 0.16
				color = Color(crop.r * tint, crop.g * tint, crop.b * tint)
		if cfg.has("lake"):
			var lake_cfg: Dictionary = cfg["lake"]
			var s: float = float(lake_cfg["scale"])
			var n3: float = lake.get_noise_3d(d.x * s, d.y * s, d.z * s)
			var level: float = lake_cfg["threshold"]
			if n3 > level:
				color = Color(lake_cfg["color"].r, lake_cfg["color"].g, lake_cfg["color"].b, 0.9)
				kind = "water"
			elif n3 > level - 0.06:
				color = lake_cfg["shore"]
				kind = "shore"
		if cfg.has("pools"):
			var pool_cfg: Dictionary = cfg["pools"]
			var n4: float = pool.get_noise_3d(d.x * 2.0, d.y * 2.0, d.z * 2.0)
			var level: float = pool_cfg["threshold"]
			if n4 > level:
				var colors: Array = pool_cfg["colors"]
				color = colors[int(hash3((d * 3.0).floor()) * 1000.0) % colors.size()]
				kind = "pool"
			elif n4 > level - 0.05:
				color = pool_cfg["rim"]
				kind = "shore"
		return {"color": color, "kind": kind}

func _terrain_mesh(cfg: Dictionary, field: TerrainField, rng: RandomNumberGenerator) -> ArrayMesh:
	var ico: Array = PropMeshes.icosphere(4)
	var verts: PackedVector3Array = ico[0]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in ico[1]:
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
		var color: Color = field.sample(outward)["color"]
		var shade: float = rng.randf_range(0.96, 1.04)
		color = Color(color.r * shade, color.g * shade, color.b * shade, color.a)
		for v in [a, b, c]:
			st.set_color(color)
			st.set_normal(outward)
			st.add_vertex(v)
	return st.commit()

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

# --- planets ----------------------------------------------------------------------------------------

func _build_planet(biome_id: String, cfg: Dictionary) -> void:
	var radius: float = cfg["radius"]
	var rng := RandomNumberGenerator.new()
	rng.seed = cfg["seed"]
	var field := TerrainField.new(cfg)
	ResourceSaver.save(_terrain_mesh(cfg, field, rng), "res://assets/meshes/terrain_%s.res" % biome_id)

	var taken: Array[Dictionary] = []
	var placements: Array[Dictionary] = []
	var counts: Dictionary = cfg["counts"]
	# Large things first so they claim their space before small props fill in around them.
	var order: Array = counts.keys()
	order.sort_custom(func(a: String, b: String) -> bool: return _prop_weight(a) > _prop_weight(b))
	for prop_id in order:
		_place_prop(prop_id, counts[prop_id], radius, rng, field, taken, placements)

	var multimeshes: Dictionary = {}
	multimeshes["grass"] = _grass_multimesh(cfg["grass"], radius, rng, field)
	for prop_id in counts:
		var prop: Dictionary = PROPS[prop_id]
		if not prop.get("multi", false):
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var found: Array = _scatter_source(prop_id)
		mm.mesh = found[0]
		var instances: Array[Dictionary] = []
		for p in placements:
			if p["prop"] == prop_id:
				instances.append(p)
		mm.instance_count = instances.size()
		for i in instances.size():
			var p: Dictionary = instances[i]
			mm.set_instance_transform(i, _placement_transform(p, radius, prop) * (found[1] as Transform3D))
		multimeshes[prop_id] = mm
	for key in multimeshes:
		ResourceSaver.save(multimeshes[key], "res://assets/meshes/%s_%s.res" % [key, biome_id])

	var node_placements: Array[Dictionary] = []
	for p in placements:
		if not PROPS[p["prop"]].get("multi", false):
			node_placements.append(p)
	var text: String = _planet_scene_text(biome_id, cfg, node_placements, multimeshes.keys(), rng)
	var file := FileAccess.open("res://scenes/planets/planet_%s.tscn" % biome_id, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("planet_%s: %d scenery nodes, multimeshes %s" % [biome_id, node_placements.size(), str(multimeshes.keys())])

func _prop_weight(prop_id: String) -> float:
	var prop: Dictionary = PROPS[prop_id]
	return float(prop.get("spacing", 1.0)) + (100.0 if not prop.get("multi", false) else 0.0)

func _place_prop(prop_id: String, wanted: int, radius: float, rng: RandomNumberGenerator,
		field: TerrainField, taken: Array[Dictionary], placements: Array[Dictionary]) -> void:
	var prop: Dictionary = PROPS[prop_id]
	var spacing: float = prop["spacing"]
	var clearance: float = prop.get("clearance", 0.0)
	var cluster: int = prop.get("cluster", 1)
	var placed: int = 0
	var tries: int = 0
	while placed < wanted and tries < wanted * 60:
		tries += 1
		var dir: Vector3 = _random_dir(rng)
		var group: int = 1
		var positions: Array[Vector3] = [dir]
		if cluster > 1:
			# Villages: neighbours a short walk from the first hut.
			group = cluster
			for k in cluster - 1:
				var offset := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
				positions.append((dir + offset * rng.randf_range(6.0, 9.0) / radius).normalized())
		var ok: bool = true
		for candidate in positions:
			if not _valid_spot(candidate, radius, clearance, spacing, field, taken):
				ok = false
				break
		if not ok:
			continue
		for candidate in positions:
			taken.append({"dir": candidate, "spacing": spacing})
			placements.append(_make_placement(prop_id, prop, candidate, rng))
			placed += 1

func _valid_spot(dir: Vector3, radius: float, clearance: float, spacing: float,
		field: TerrainField, taken: Array[Dictionary]) -> bool:
	var pos: Vector3 = dir * radius
	# Keep the tutorial runway at the start of the first planet clear.
	if absf(pos.x) < 9.0 + clearance and pos.z < 6.0 + clearance:
		return false
	var kind: String = field.sample(dir)["kind"]
	if kind == "water" or kind == "pool":
		return false
	return not _too_close(dir, spacing, radius, taken)

func _make_placement(prop_id: String, prop: Dictionary, dir: Vector3, rng: RandomNumberGenerator) -> Dictionary:
	var scale_vec: Vector3
	var clearance: float = prop.get("clearance", 0.0)
	if prop.has("scale_xz"):
		var xz: float = rng.randf_range(prop["scale_xz"].x, prop["scale_xz"].y)
		var y: float = rng.randf_range(prop["scale_y"].x, prop["scale_y"].y)
		scale_vec = Vector3(xz, y, xz)
		clearance = maxf(clearance, xz)
	else:
		var s: float = rng.randf_range(prop["scale"].x, prop["scale"].y)
		scale_vec = Vector3.ONE * s
		var mid: float = (prop["scale"].x + prop["scale"].y) * 0.5
		clearance = clearance * s / mid
	return {"prop": prop_id, "dir": dir, "scale": scale_vec, "yaw": rng.randf() * TAU, "clearance": clearance}

func _placement_transform(p: Dictionary, radius: float, prop: Dictionary) -> Transform3D:
	var lift: float = float(prop.get("lift", 0.0)) * (p["scale"] as Vector3).y
	return _surface_transform(p["dir"], radius, p["yaw"], p["scale"], -lift)

## Mesh and transform used to build a MultiMesh for a scatter prop.
func _scatter_source(prop_id: String) -> Array:
	var prop: Dictionary = PROPS[prop_id]
	if prop.has("builder"):
		return [load(_prop_mesh_path(prop_id)), Transform3D.IDENTITY]
	return _model_mesh(prop["model"])

func _grass_multimesh(count: int, radius: float, rng: RandomNumberGenerator, field: TerrainField) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = load("res://assets/meshes/props/grass_tuft.res")
	mm.instance_count = count
	for i in count:
		var dir: Vector3 = _random_dir(rng)
		var guard: int = 0
		while field.sample(dir)["kind"] in ["water", "pool"] and guard < 20:
			dir = _random_dir(rng)
			guard += 1
		mm.set_instance_transform(i, _surface_transform(dir, radius, rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.8, 1.3), 0.0))
	return mm

## First mesh found in a model scene, plus that mesh node's transform inside the scene.
func _model_mesh(model_file: String) -> Array:
	var inst: Node = (load(KENNEY + model_file) as PackedScene).instantiate()
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

func _planet_scene_text(biome_id: String, cfg: Dictionary, placements: Array[Dictionary],
		multimesh_keys: Array, rng: RandomNumberGenerator) -> String:
	var radius: float = cfg["radius"]
	var atmo: Color = cfg["atmosphere"]
	var mood: Dictionary = cfg["mood"]
	var out := PackedStringArray()
	var model_ids: Array[String] = []
	var mesh_ids: Array[String] = []
	for p in placements:
		var prop: Dictionary = PROPS[p["prop"]]
		if prop.has("model") and not model_ids.has(p["prop"]):
			model_ids.append(p["prop"])
		elif prop.has("builder") and not mesh_ids.has(p["prop"]):
			mesh_ids.append(p["prop"])
	out.append("[gd_scene load_steps=%d format=3]\n" % (model_ids.size() + mesh_ids.size() + multimesh_keys.size() + 14))
	out.append('[ext_resource type="Script" path="res://scripts/planets/planet_controller.gd" id="1_script"]')
	out.append('[ext_resource type="ArrayMesh" path="res://assets/meshes/terrain_%s.res" id="2_terrain"]' % biome_id)
	out.append('[ext_resource type="Material" path="%s" id="3_terrain_mat"]' % TERRAIN_MATERIAL)
	out.append('[ext_resource type="Shader" path="res://assets/shaders/atmosphere.gdshader" id="4_atmo_shader"]')
	out.append('[ext_resource type="Material" path="res://assets/materials/grass_%s.tres" id="6_grass_mat"]' % biome_id)
	for key in multimesh_keys:
		out.append('[ext_resource type="MultiMesh" path="res://assets/meshes/%s_%s.res" id="mm_%s"]' % [key, biome_id, key])
	for prop_id in model_ids:
		out.append('[ext_resource type="PackedScene" path="%s%s" id="m_%s"]' % [KENNEY, PROPS[prop_id]["model"], prop_id])
	for prop_id in mesh_ids:
		out.append('[ext_resource type="ArrayMesh" path="%s" id="p_%s"]' % [_prop_mesh_path(prop_id), prop_id])
	for variant in CLOUD_VARIANTS:
		out.append('[ext_resource type="ArrayMesh" path="res://assets/meshes/props/cloud_%d.res" id="cloud_%d"]' % [variant, variant])
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
	out.append('[sub_resource type="Animation" id="Animation_drift"]')
	out.append('resource_name = "drift"')
	out.append('length = 420.0')
	out.append('loop_mode = 1')
	out.append('tracks/0/type = "value"')
	out.append('tracks/0/imported = false')
	out.append('tracks/0/enabled = true')
	out.append('tracks/0/path = NodePath("Clouds/Spin:rotation")')
	out.append('tracks/0/interp = 1')
	out.append('tracks/0/loop_wrap = true')
	out.append('tracks/0/keys = {')
	out.append('"times": PackedFloat32Array(0, 420),')
	out.append('"transitions": PackedFloat32Array(1, 1),')
	out.append('"update": 0,')
	out.append('"values": [Vector3(0, 0, 0), Vector3(0, 6.28319, 0)]')
	out.append('}')
	out.append("")
	out.append('[sub_resource type="AnimationLibrary" id="AnimationLibrary_drift"]')
	out.append('_data = {')
	out.append('&"drift": SubResource("Animation_drift")')
	out.append('}')
	out.append("")
	out.append('[node name="Planet%s" type="Node3D"]' % biome_id.capitalize())
	out.append('script = ExtResource("1_script")')
	out.append('planet_name = "%s"' % cfg["title"])
	out.append('radius = %s' % str(radius))
	out.append('ambient_color = Color(%f, %f, %f, 1)' % [mood["ambient"].r, mood["ambient"].g, mood["ambient"].b])
	out.append('fog_color = Color(%f, %f, %f, 1)' % [mood["fog"].r, mood["fog"].g, mood["fog"].b])
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
		out.append('[node name="%s" type="MultiMeshInstance3D" parent="Scatter"]' % key.capitalize().replace("_", ""))
		if key == "grass":
			out.append('material_override = ExtResource("6_grass_mat")')
			out.append('cast_shadow = 0')
		elif PROPS.has(key) and PROPS[key].has("builder"):
			out.append('material_override = ExtResource("3_terrain_mat")')
			out.append('cast_shadow = 0')
		out.append('multimesh = ExtResource("mm_%s")' % key)
		out.append("")
	out.append('[node name="Decorations" type="Node3D" parent="."]')
	out.append("")
	var counters: Dictionary = {}
	for p in placements:
		var prop_id: String = p["prop"]
		var prop: Dictionary = PROPS[prop_id]
		counters[prop_id] = int(counters.get(prop_id, 0)) + 1
		var node_name: String = "%s_%03d" % [prop_id.capitalize().replace(" ", ""), counters[prop_id]]
		var xf: Transform3D = _placement_transform(p, radius, prop)
		if prop.has("model"):
			out.append('[node name="%s" parent="Decorations" instance=ExtResource("m_%s")]' % [node_name, prop_id])
			out.append('transform = %s' % var_to_str(xf))
		else:
			out.append('[node name="%s" type="MeshInstance3D" parent="Decorations"]' % node_name)
			out.append('transform = %s' % var_to_str(xf))
			out.append('material_override = ExtResource("3_terrain_mat")')
			out.append('mesh = ExtResource("p_%s")' % prop_id)
		out.append('metadata/clearance = %s' % str(snappedf(p["clearance"], 0.1)))
		out.append("")
	# Drifting clouds, tilted so each world's sky has its own orbit.
	var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.5, 0.5)).rotated(Vector3.BACK, rng.randf_range(-0.4, 0.4))
	out.append('[node name="Clouds" type="Node3D" parent="."]')
	out.append('transform = %s' % var_to_str(Transform3D(tilt, Vector3.ZERO)))
	out.append("")
	out.append('[node name="Spin" type="Node3D" parent="Clouds"]')
	out.append("")
	for i in int(cfg["clouds"]):
		var dir: Vector3 = _random_dir(rng)
		var height: float = rng.randf_range(26.0, 42.0)
		var xf := _surface_transform(dir, radius + height, rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.7, 1.3), 0.0)
		out.append('[node name="Cloud_%02d" type="MeshInstance3D" parent="Clouds/Spin"]' % (i + 1))
		out.append('transform = %s' % var_to_str(xf))
		out.append('cast_shadow = 0')
		out.append('material_override = ExtResource("3_terrain_mat")')
		out.append('mesh = ExtResource("cloud_%d")' % (i % CLOUD_VARIANTS))
		out.append("")
	out.append('[node name="CloudPlayer" type="AnimationPlayer" parent="."]')
	out.append('libraries = {')
	out.append('&"": SubResource("AnimationLibrary_drift")')
	out.append('}')
	out.append('autoplay = "drift"')
	out.append("")
	return "\n".join(out)

# --- space backdrop --------------------------------------------------------------------------------

## Far-away planets, a ringed giant, moons and drifting dust. The scene follows the camera
## (scripts/world/space_backdrop.gd), so there is always more universe beyond the next world.
func _build_backdrop() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var out := PackedStringArray()
	var biome_ids: Array = BIOMES.keys()
	out.append("[gd_scene load_steps=30 format=3]\n")
	out.append('[ext_resource type="Script" path="res://scripts/world/space_backdrop.gd" id="1_script"]')
	out.append('[ext_resource type="Material" path="%s" id="2_mat"]' % TERRAIN_MATERIAL)
	out.append('[ext_resource type="Shader" path="res://assets/shaders/atmosphere.gdshader" id="3_atmo"]')
	for biome_id in biome_ids:
		out.append('[ext_resource type="ArrayMesh" path="res://assets/meshes/terrain_%s.res" id="t_%s"]' % [biome_id, biome_id])
	out.append("")
	for biome_id in biome_ids:
		var atmo: Color = BIOMES[biome_id]["atmosphere"]
		out.append('[sub_resource type="ShaderMaterial" id="Atmo_%s"]' % biome_id)
		out.append('render_priority = 1')
		out.append('shader = ExtResource("3_atmo")')
		out.append('shader_parameter/glow_color = Color(%f, %f, %f, 1)' % [atmo.r, atmo.g, atmo.b])
		out.append('shader_parameter/rim_power = 2.6')
		out.append('shader_parameter/strength = 0.6')
		out.append("")
	out.append('[sub_resource type="SphereMesh" id="SphereMesh_atmo"]')
	out.append('radius = 1.0')
	out.append('height = 2.0')
	out.append('radial_segments = 24')
	out.append('rings = 12')
	out.append("")
	out.append('[sub_resource type="StandardMaterial3D" id="Ring_mat"]')
	out.append('albedo_color = Color(0.78, 0.66, 0.48, 1)')
	out.append('roughness = 1.0')
	out.append("")
	out.append('[sub_resource type="TorusMesh" id="Ring_mesh"]')
	out.append('material = SubResource("Ring_mat")')
	out.append('inner_radius = 1.35')
	out.append('outer_radius = 1.95')
	out.append('rings = 40')
	out.append('ring_segments = 6')
	out.append("")
	out.append('[sub_resource type="StandardMaterial3D" id="Dust_mat"]')
	out.append('shading_mode = 0')
	out.append('albedo_color = Color(0.85, 0.92, 1, 0.55)')
	out.append('transparency = 1')
	out.append("")
	out.append('[sub_resource type="SphereMesh" id="Dust_mesh"]')
	out.append('material = SubResource("Dust_mat")')
	out.append('radius = 0.07')
	out.append('height = 0.14')
	out.append('radial_segments = 4')
	out.append('rings = 2')
	out.append("")
	out.append('[node name="SpaceBackdrop" type="Node3D"]')
	out.append('process_priority = 100')
	out.append('script = ExtResource("1_script")')
	out.append("")
	var directions: Array[Vector3] = []
	var index: int = 0
	var guard: int = 0
	while index < 18 and guard < 500:
		guard += 1
		var dir: Vector3 = _random_dir(rng)
		var spaced: bool = true
		for other in directions:
			if dir.dot(other) > 0.93:
				spaced = false
				break
		if not spaced:
			continue
		directions.append(dir)
		var biome_id: String = biome_ids[index % biome_ids.size()]
		var distance: float = rng.randf_range(2600.0, 4600.0)
		var size: float = rng.randf_range(160.0, 520.0)
		var basis := Basis(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf() * TAU)
		var origin: Vector3 = dir * distance
		out.append('[node name="World_%02d" type="Node3D" parent="."]' % (index + 1))
		out.append('transform = %s' % var_to_str(Transform3D(basis, origin)))
		out.append("")
		out.append('[node name="Terrain" type="MeshInstance3D" parent="World_%02d"]' % (index + 1))
		out.append('transform = %s' % var_to_str(Transform3D(Basis.from_scale(Vector3.ONE * size), Vector3.ZERO)))
		out.append('cast_shadow = 0')
		out.append('material_override = ExtResource("2_mat")')
		out.append('mesh = ExtResource("t_%s")' % biome_id)
		out.append("")
		out.append('[node name="Atmosphere" type="MeshInstance3D" parent="World_%02d"]' % (index + 1))
		out.append('transform = %s' % var_to_str(Transform3D(Basis.from_scale(Vector3.ONE * size * 1.06), Vector3.ZERO)))
		out.append('cast_shadow = 0')
		out.append('material_override = SubResource("Atmo_%s")' % biome_id)
		out.append('mesh = SubResource("SphereMesh_atmo")')
		out.append("")
		if index % 6 == 2:
			var ring_basis := Basis(Vector3.RIGHT, rng.randf_range(-0.6, 0.6)).rotated(Vector3.BACK, rng.randf_range(-0.5, 0.5))
			ring_basis = ring_basis.scaled_local(Vector3(size, size * 0.03, size))
			out.append('[node name="Ring" type="MeshInstance3D" parent="World_%02d"]' % (index + 1))
			out.append('transform = %s' % var_to_str(Transform3D(ring_basis, Vector3.ZERO)))
			out.append('cast_shadow = 0')
			out.append('mesh = SubResource("Ring_mesh")')
			out.append("")
		if index % 4 == 1:
			var moon_offset: Vector3 = Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 0.4), rng.randf_range(-1, 1)).normalized() * size * 1.9
			out.append('[node name="Moon" type="MeshInstance3D" parent="World_%02d"]' % (index + 1))
			out.append('transform = %s' % var_to_str(Transform3D(Basis.from_scale(Vector3.ONE * size * 0.22), moon_offset)))
			out.append('cast_shadow = 0')
			out.append('material_override = ExtResource("2_mat")')
			out.append('mesh = ExtResource("t_%s")' % biome_ids[(index + 2) % biome_ids.size()])
			out.append("")
		index += 1
	out.append('[node name="Dust" type="CPUParticles3D" parent="."]')
	out.append('amount = 160')
	out.append('lifetime = 10.0')
	out.append('preprocess = 10.0')
	out.append('local_coords = false')
	out.append('draw_order = 0')
	out.append('mesh = SubResource("Dust_mesh")')
	out.append('emission_shape = 3')
	out.append('emission_box_extents = Vector3(55, 30, 55)')
	out.append('spread = 180.0')
	out.append('gravity = Vector3(0, 0, 0)')
	out.append('initial_velocity_min = 0.2')
	out.append('initial_velocity_max = 1.1')
	out.append('scale_amount_min = 0.5')
	out.append('scale_amount_max = 1.6')
	out.append("")
	var file := FileAccess.open("res://scenes/game/space_backdrop.tscn", FileAccess.WRITE)
	file.store_string("\n".join(out))
	file.close()
	print("space_backdrop: %d far worlds" % index)

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

func _surface_transform(dir: Vector3, radius: float, yaw: float, scale_vec: Vector3, sink: float) -> Transform3D:
	var tangent: Vector3 = dir.cross(Vector3.RIGHT)
	if tangent.length() < 0.2:
		tangent = dir.cross(Vector3.FORWARD)
	tangent = tangent.normalized()
	var basis := Basis(tangent, dir, tangent.cross(dir)).rotated(dir, yaw)
	basis = basis.scaled_local(scale_vec)
	return Transform3D(basis, dir * (radius + sink))

# --- landmarks ----------------------------------------------------------------------------------------

func _build_landmarks() -> void:
	# The three supplied FBX models keep their own look.
	_write_scene("lalibela", _fbx_landmark("lalibela", "res://assets/artifacts/lalibela.fbx",
		"res://assets/materials/artifact_lalibela.tres", 12.0, Color(0.55, 0.30, 0.22)))
	_write_scene("aksum", _fbx_landmark("aksum", "res://assets/artifacts/axum.fbx",
		"res://assets/materials/artifact_axum.tres", 12.0, Color(0.55, 0.55, 0.55)))
	_write_scene("gondar", _fbx_landmark("gondar", "res://assets/artifacts/fasiledes gondor.fbx",
		"res://assets/materials/artifact_fasiledes.tres", 14.0, Color(0.62, 0.52, 0.38)))
	# Everything else is built in the game's own low-poly style from photographs of the real places.
	_write_scene("yeha", _mesh_landmark("yeha", [["yeha_temple", Vector3.ZERO, 1.0]], Color(0.66, 0.54, 0.36), 8.5, []))
	_write_scene("debre_damo", _mesh_landmark("debre_damo", [], Color(0.70, 0.52, 0.36), 11.0, [
		["prop:amba", Vector3.ZERO, Vector3(9.0, 13.0, 9.0)],
		["landmark:church_small", Vector3(0, 12.9, 0), Vector3(1.4, 1.4, 1.4)],
		["prop:eucalyptus", Vector3(6.5, 0.3, 4.0), Vector3(1.4, 1.4, 1.4)],
		["prop:eucalyptus", Vector3(-6.0, 0.3, 5.5), Vector3(1.2, 1.2, 1.2)],
	]))
	_write_scene("ura_kidane", _mesh_landmark("ura_kidane", [["ura_kidane", Vector3.ZERO, 1.0]], Color(0.42, 0.50, 0.28), 8.0, [
		["prop:eucalyptus", Vector3(-6.4, 0.2, 2.0), Vector3(1.5, 1.5, 1.5)],
		["prop:eucalyptus", Vector3(6.6, 0.2, 1.0), Vector3(1.3, 1.3, 1.3)],
		["prop:eucalyptus", Vector3(5.0, 0.2, -5.4), Vector3(1.6, 1.6, 1.6)],
		["prop:acacia", Vector3(-5.8, 0.2, -4.6), Vector3(1.3, 1.3, 1.3)],
	]))
	_write_scene("abuna_yemata", _mesh_landmark("abuna_yemata", [["abuna_yemata", Vector3.ZERO, 1.0]], Color(0.78, 0.56, 0.40), 9.0, []))
	_write_scene("fasilides_bath", _mesh_landmark("fasilides_bath", [["fasilides_bath", Vector3.ZERO, 1.0]], Color(0.56, 0.60, 0.34), 8.0, [
		["prop:acacia", Vector3(-6.8, 0.2, 4.6), Vector3(1.4, 1.4, 1.4)],
		["prop:acacia", Vector3(6.8, 0.2, 4.2), Vector3(1.2, 1.2, 1.2)],
	]))
	_write_scene("konso", _mesh_landmark("konso", [["konso_village", Vector3.ZERO, 1.0]], Color(0.50, 0.60, 0.28), 0.0, []))
	_write_scene("blue_nile_falls", _mesh_landmark("blue_nile_falls", [["blue_nile_falls", Vector3.ZERO, 1.0]], Color(0.30, 0.50, 0.28), 0.0, []))
	_write_scene("harar", _mesh_landmark("harar", [["harar_gate", Vector3.ZERO, 1.0]], Color(0.70, 0.60, 0.42), 0.0, []))
	_write_scene("tiya", _mesh_landmark("tiya", [["tiya_stelae", Vector3.ZERO, 1.0]], Color(0.50, 0.46, 0.40), 0.0, []))
	_write_scene("simien", _mesh_landmark("simien", [["simien_crag", Vector3.ZERO, 1.0]], Color(0.50, 0.44, 0.32), 9.0, [
		["prop:lobelia", Vector3(-3.0, 0.3, 6.5), Vector3(2.0, 2.0, 2.0)],
		["prop:lobelia", Vector3(3.5, 0.3, 7.0), Vector3(1.7, 1.7, 1.7)],
	]))
	_write_scene("danakil", _mesh_landmark("danakil", [["danakil_salt", Vector3.ZERO, 1.0]], Color(0.85, 0.72, 0.30), 0.0, [
		["prop:steam", Vector3(-3.5, 0.3, 1.5), Vector3(1.0, 1.2, 1.0)],
		["prop:steam", Vector3(2.2, 0.3, 2.8), Vector3(0.8, 1.0, 0.8)],
	]))
	var bale_parts: Array = []
	for i in 5:
		var angle: float = TAU * float(i) / 5.0 + 0.3
		bale_parts.append(["prop:lobelia", Vector3(cos(angle) * 4.6, 0.3, sin(angle) * 4.6), Vector3.ONE * (2.0 + 0.2 * float(i % 3))])
	for i in 3:
		var angle: float = TAU * float(i) / 3.0 + 1.1
		bale_parts.append(["prop:lobelia_spike", Vector3(cos(angle) * 2.0, 0.3, sin(angle) * 2.0), Vector3.ONE * 1.8])
	for i in 10:
		var angle: float = TAU * float(i) / 10.0
		bale_parts.append(["prop:helichrysum", Vector3(cos(angle) * 7.2, 0.2, sin(angle) * 7.2), Vector3.ONE * 1.6])
	_write_scene("bale", _mesh_landmark("bale", [], Color(0.48, 0.52, 0.38), 9.5, bale_parts))

	_write_scene("adwa", _mesh_landmark("adwa", [["adwa_monument", Vector3.ZERO, 1.0]], Color(0.56, 0.52, 0.40), 0.0, []))
	_write_scene("lake_tana", _mesh_landmark("lake_tana", [["lake_tana", Vector3.ZERO, 1.0]], Color(0.30, 0.50, 0.50), 0.0, []))
	_write_scene("sof_omar", _mesh_landmark("sof_omar", [["sof_omar", Vector3.ZERO, 1.0]], Color(0.50, 0.44, 0.36), 0.0, []))
	_write_scene("wenchi", _mesh_landmark("wenchi", [["wenchi_crater", Vector3.ZERO, 1.0]], Color(0.36, 0.50, 0.28), 0.0, []))
	_write_scene("entoto", _mesh_landmark("entoto", [["entoto_observatory", Vector3.ZERO, 1.0]], Color(0.54, 0.58, 0.44), 0.0, [
		["prop:eucalyptus", Vector3(-7.4, 0.3, -1.0), Vector3(1.6, 1.6, 1.6)],
		["prop:eucalyptus", Vector3(7.8, 0.3, -3.2), Vector3(1.4, 1.4, 1.4)],
	]))
	_write_scene("lucy", _mesh_landmark("lucy", [["lucy_hadar", Vector3.ZERO, 1.0]], Color(0.80, 0.66, 0.46), 0.0, []))
	_write_scene("dorze", _mesh_landmark("dorze", [["dorze_huts", Vector3.ZERO, 1.0]], Color(0.52, 0.62, 0.32), 0.0, [
		["prop:eucalyptus", Vector3(8.6, 0.3, -1.0), Vector3(1.5, 1.5, 1.5)],
	]))

# --- space objects ------------------------------------------------------------------------------------

## Ethiopian spacecraft that drift between the planets: [id, mesh builder, label, spin axis, spin rate, label height].
const SPACE_OBJECTS: Array = [
	["nss12", "nss12_station", "NSS-12", Vector3(1, 0, 0), 0.22, 7.5],
	["etrss1", "etrss1_satellite", "ETRSS-1", Vector3(0, 1, 0), 0.35, 4.2],
	["selam_relay", "selam_relay", "SELAM RELAY", Vector3(0, 1, 0), 0.5, 7.0],
]

func _space_mesh(mesh_id: String) -> ArrayMesh:
	match mesh_id:
		"nss12_station": return SpaceMeshes.nss12_station()
		"etrss1_satellite": return SpaceMeshes.etrss1_satellite()
		"selam_relay": return SpaceMeshes.selam_relay()
	push_error("unknown space mesh " + mesh_id)
	return null

func _build_space_objects() -> void:
	for entry in SPACE_OBJECTS:
		var mesh_path: String = "res://assets/meshes/space/%s.res" % entry[1]
		ResourceSaver.save(_space_mesh(entry[1]), mesh_path)
		var axis: Vector3 = entry[3]
		var lines: PackedStringArray = [
			"[gd_scene load_steps=4 format=3]", "",
			'[ext_resource type="Script" path="res://scripts/world/space_object.gd" id="1_script"]',
			'[ext_resource type="ArrayMesh" path="%s" id="2_mesh"]' % mesh_path,
			'[ext_resource type="Material" path="%s" id="3_mat"]' % TERRAIN_MATERIAL, "",
			'[node name="%s" type="Node3D"]' % String(entry[0]).capitalize().replace(" ", ""),
			'script = ExtResource("1_script")',
			'display_name = "%s"' % entry[2],
			'spin_axis = Vector3(%s, %s, %s)' % [axis.x, axis.y, axis.z],
			'spin_speed = %s' % entry[4], "",
			'[node name="Model" type="MeshInstance3D" parent="."]',
			'unique_name_in_owner = true',
			'material_override = ExtResource("3_mat")',
			'mesh = ExtResource("2_mesh")', "",
			'[node name="Tag" type="Label3D" parent="."]',
			'unique_name_in_owner = true',
			'transform = %s' % var_to_str(Transform3D(Basis.IDENTITY, Vector3(0, entry[5], 0))),
			'pixel_size = 0.014',
			'billboard = 1',
			'no_depth_test = true',
			'fixed_size = false',
			'modulate = Color(1, 0.95, 0.75, 1)',
			'outline_modulate = Color(0.05, 0.05, 0.1, 1)',
			'text = "%s"' % entry[2],
			'font_size = 56',
			'outline_size = 18', "",
		]
		var file := FileAccess.open("res://scenes/space/space_%s.tscn" % entry[0], FileAccess.WRITE)
		file.store_string("\n".join(lines))
		file.close()
		print("space_%s written" % entry[0])

func _write_scene(id: String, text: String) -> void:
	var file := FileAccess.open("res://scenes/landmarks/landmark_%s.tscn" % id, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("landmark_%s written" % id)

## Accumulates ext/sub resources and nodes for a landmark scene.
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

	func plinth(color: Color, radius: float) -> void:
		_sub_count += 1
		var mat: String = "mat_%d" % _sub_count
		sub.append('[sub_resource type="StandardMaterial3D" id="%s"]' % mat)
		sub.append('albedo_color = Color(%f, %f, %f, 1)' % [color.r, color.g, color.b])
		sub.append('roughness = 0.95')
		sub.append("")
		_sub_count += 1
		var mesh: String = "cyl_%d" % _sub_count
		sub.append('[sub_resource type="CylinderMesh" id="%s"]' % mesh)
		sub.append('material = SubResource("%s")' % mat)
		sub.append('top_radius = %f' % radius)
		sub.append('bottom_radius = %f' % (radius * 1.04))
		sub.append('height = 1.8')
		sub.append('radial_segments = 24')
		sub.append('rings = 1')
		sub.append("")
		nodes.append('[node name="Plinth" type="MeshInstance3D" parent="."]')
		nodes.append('transform = %s' % var_to_str(Transform3D(Basis.IDENTITY, Vector3(0, -0.6, 0))))
		nodes.append('mesh = SubResource("%s")' % mesh)
		nodes.append("")

	func mesh_node(node_name: String, mesh_path: String, material_path: String, xf: Transform3D) -> void:
		var mesh_id: String = ext_resource("ArrayMesh", mesh_path)
		var mat_id: String = ext_resource("Material", material_path)
		nodes.append('[node name="%s" type="MeshInstance3D" parent="."]' % node_name)
		nodes.append('transform = %s' % var_to_str(xf))
		nodes.append('material_override = ExtResource("%s")' % mat_id)
		nodes.append('mesh = ExtResource("%s")' % mesh_id)
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

func _fbx_landmark(id: String, model: String, material_path: String, scale_factor: float, plinth_color: Color) -> String:
	var s := SceneText.new()
	s.plinth(plinth_color, 8.0)
	var model_id: String = s.ext_resource("PackedScene", model)
	var mat_id: String = s.ext_resource("Material", material_path)
	s.nodes.append('[node name="Model" parent="." instance=ExtResource("%s")]' % model_id)
	s.nodes.append('transform = %s' % var_to_str(Transform3D(Basis.from_scale(Vector3.ONE * scale_factor), Vector3(0, 0.3, 0))))
	s.nodes.append("")
	s.nodes.append('[node name="node_0" parent="Model" index="0"]')
	s.nodes.append('material_override = ExtResource("%s")' % mat_id)
	s.nodes.append("")
	return s.build("Landmark" + id.capitalize())

## A landmark scene: optional plinth, main landmark meshes, then extra parts.
## Part ids are "landmark:<mesh>" (assets/meshes/landmarks) or "prop:<id>" (assets/meshes/props).
func _mesh_landmark(id: String, mains: Array, plinth_color: Color, plinth_radius: float, parts: Array) -> String:
	var s := SceneText.new()
	if plinth_radius > 0.0:
		s.plinth(plinth_color, plinth_radius)
	for main in mains:
		var xf := Transform3D(Basis.from_scale(Vector3.ONE * float(main[2])), main[1])
		s.mesh_node(("Model_" + main[0]).capitalize().replace(" ", ""), "res://assets/meshes/landmarks/%s.res" % main[0], TERRAIN_MATERIAL, xf)
	var counter: int = 0
	for part in parts:
		counter += 1
		var kind: String = (part[0] as String).get_slice(":", 0)
		var name: String = (part[0] as String).get_slice(":", 1)
		var path: String = "res://assets/meshes/props/%s.res" % name if kind == "prop" else "res://assets/meshes/landmarks/%s.res" % name
		var xf := Transform3D(Basis.from_scale(part[2]), part[1])
		s.mesh_node("%s_%02d" % [name.capitalize().replace(" ", ""), counter], path, TERRAIN_MATERIAL, xf)
	return s.build("Landmark" + id.capitalize())
