class_name ArtifactLibrary
extends RefCounted
## Finds the artifact models dropped into assets/artifacts. Any fbx, glb, gltf, obj or scene file
## placed there is picked up with no other change, scaled to a common size and stood on the ground.

const FOLDER: String = "res://assets/artifacts"
const MATERIAL_FOLDER: String = "res://assets/materials"
const MODEL_EXTENSIONS: PackedStringArray = ["fbx", "glb", "gltf", "obj", "tscn", "scn"]

## Resource paths of every model in `folder`. Exported games list imported files as `x.fbx.import`
## (or `.remap`), so those suffixes are stripped to get back to the source name.
static func list_models(folder: String = FOLDER) -> PackedStringArray:
	var found: Dictionary = {}
	for file in DirAccess.get_files_at(folder):
		var name: String = file
		for suffix in [".import", ".remap"]:
			if name.ends_with(suffix):
				name = name.trim_suffix(suffix)
		if name.get_extension().to_lower() in MODEL_EXTENSIONS:
			found[folder.path_join(name)] = true
	var paths := PackedStringArray(found.keys())
	paths.sort()
	return paths

## "fasiledes gondor.fbx" -> "Fasiledes Gondor".
static func display_name(path: String) -> String:
	return path.get_file().get_basename().replace("_", " ").replace("-", " ").capitalize()

## A new instance of the model, or null when it cannot be loaded.
static func instantiate(path: String) -> Node3D:
	var resource: Resource = load(path)
	if resource is PackedScene:
		return (resource as PackedScene).instantiate() as Node3D
	if resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource as Mesh
		return mesh_instance
	return null

## `assets/materials/artifact_<name>.tres` when it exists, tried with the whole file name and then
## with its first word, so "fasiledes gondor.fbx" finds artifact_fasiledes.tres.
static func find_material(path: String) -> Material:
	var stem: String = path.get_file().get_basename().to_lower().replace(" ", "_")
	for candidate in [stem, stem.get_slice("_", 0)]:
		var material_path: String = MATERIAL_FOLDER.path_join("artifact_%s.tres" % candidate)
		if ResourceLoader.exists(material_path):
			return load(material_path) as Material
	return null

## Bounding box of every mesh under `root`, in `root`'s own space (its transform is ignored).
static func local_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first: bool = true
	var pending: Array = [[root, Transform3D.IDENTITY]]
	while not pending.is_empty():
		var item: Array = pending.pop_back()
		var node: Node3D = item[0]
		var xform: Transform3D = item[1]
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var box: AABB = xform * (node as MeshInstance3D).mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		for child in node.get_children():
			if child is Node3D:
				pending.append([child, xform * (child as Node3D).transform])
	return bounds

## Scales `model` so its longest side is `target_size` and moves it so it stands on y = 0, centred.
## Returns the height of the scaled model.
static func fit(model: Node3D, target_size: float) -> float:
	var bounds: AABB = local_bounds(model)
	var longest: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest <= 0.0001:
		return target_size
	var factor: float = target_size / longest
	model.scale = Vector3.ONE * factor
	var centre: Vector3 = bounds.get_center()
	model.position = -Vector3(centre.x, bounds.position.y, centre.z) * factor
	return bounds.size.y * factor
