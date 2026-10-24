class_name SphericalPlanet
extends Node3D

@export var planet_name: String = "Lalibela Highlands"
@export var radius: float = 40.0
@export var next_planet: SphericalPlanet
@export var landmark_scene: PackedScene

@onready var visual_sphere: MeshInstance3D = get_node_or_null("VisualSphere")
@onready var collision_shape: CollisionShape3D = get_node_or_null("StaticBody3D/CollisionShape3D")
@onready var decor_container: Node3D = get_node_or_null("Decorations")
@onready var landmark_mount: Node3D = get_node_or_null("LandmarkMount")
@onready var launch_pad: Node3D = get_node_or_null("LaunchPad")

var active_target: LandmarkTarget = null
var active_landmark_data: LandmarkData = null

func _ready() -> void:
	_init_landmark()

func _init_landmark() -> void:
	if landmark_scene and landmark_mount:
		var lm_inst = landmark_scene.instantiate()
		landmark_mount.add_child(lm_inst)
		active_target = lm_inst.get_node_or_null("LandmarkTarget") as LandmarkTarget
		if not active_target:
			for child in lm_inst.get_children():
				if child is LandmarkTarget:
					active_target = child
					break

func get_up(point: Vector3) -> Vector3:
	var diff = point - global_position
	if diff.length_squared() < 0.001:
		return Vector3.UP
	return diff.normalized()

func get_gravity(point: Vector3) -> Vector3:
	return -get_up(point) * 24.0

func get_surface_point(point: Vector3) -> Vector3:
	return global_position + get_up(point) * radius

func get_distance_to_surface(point: Vector3) -> float:
	return (point - global_position).length() - radius
