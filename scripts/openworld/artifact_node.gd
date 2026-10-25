class_name ArtifactNode
extends Node3D
## One artifact standing on a planet, with its detector: a ring on the ground and a beam of light
## that change colour when the jet is close enough to photograph it. The detector only reads the
## jet's position, so it works the same in the game and in tests.

signal detected_changed(artifact: ArtifactNode, in_range: bool)
signal captured(artifact: ArtifactNode)

const IDLE_COLOR: Color = Color(1.0, 0.7, 0.2, 0.55)
const RANGE_COLOR: Color = Color(0.35, 1.0, 0.55, 0.8)
const DONE_COLOR: Color = Color(0.6, 0.8, 1.0, 0.12)

## The jet must be this close for the detector to trigger.
@export var detect_radius: float = 34.0
## Length of the artifact's longest side once placed.
@export var target_size: float = 14.0

var artifact_name: String = "Artifact"
var model_path: String = ""
var in_range: bool = false
var is_captured: bool = false
## Height of the scaled model.
var model_height: float = 14.0

@onready var _model: Node3D = $Model
@onready var _ring: MeshInstance3D = $Detector/Ring
@onready var _beam: MeshInstance3D = $Detector/Beam

func _ready() -> void:
	_refresh_colors()

## Loads the model at `path`. Returns false (and keeps a plain marker) when it cannot be loaded.
func setup(path: String) -> bool:
	model_path = path
	artifact_name = ArtifactLibrary.display_name(path)
	var model: Node3D = ArtifactLibrary.instantiate(path)
	if model == null:
		push_warning("Artifact model could not be loaded: %s" % path)
		return false
	_model.add_child(model)
	var material: Material = ArtifactLibrary.find_material(path)
	if material:
		_apply_material(model, material)
	model_height = ArtifactLibrary.fit(model, target_size)
	return true

## Three points down the artifact's middle (base, middle, top) used to check a picture frames all of it.
func sample_points() -> PackedVector3Array:
	var up: Vector3 = global_basis.y.normalized()
	return PackedVector3Array([
		global_position + up * 0.2,
		global_position + up * model_height * 0.5,
		global_position + up * model_height * 0.95,
	])

func focus_point() -> Vector3:
	return global_position + global_basis.y.normalized() * model_height * 0.5

## Updates the detector from the jet's position. Returns the new in-range state.
func update_detection(ship_position: Vector3) -> bool:
	var near: bool = not is_captured and ship_position.distance_to(focus_point()) <= detect_radius
	if near != in_range:
		in_range = near
		_refresh_colors()
		detected_changed.emit(self, in_range)
	return in_range

func distance_to(point: Vector3) -> float:
	return point.distance_to(focus_point())

## Called once a valid picture of this artifact has been taken.
func mark_captured() -> void:
	if is_captured:
		return
	is_captured = true
	var was_in_range: bool = in_range
	in_range = false
	_refresh_colors()
	if was_in_range:
		detected_changed.emit(self, false)
	captured.emit(self)

func _apply_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply_material(child, material)

func _refresh_colors() -> void:
	if _ring == null or _beam == null:
		return
	var color: Color = DONE_COLOR if is_captured else (RANGE_COLOR if in_range else IDLE_COLOR)
	_set_color(_ring, color)
	_set_color(_beam, color)
	_beam.visible = not is_captured

func _set_color(mesh: MeshInstance3D, color: Color) -> void:
	var material := mesh.material_override as StandardMaterial3D
	if material:
		material.albedo_color = color
