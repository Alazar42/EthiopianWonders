class_name PlanetController
extends Node3D
## A spherical world. Terrain, atmosphere, grass and scenery are authored in the planet's scene;
## this script only exposes the sphere and clears scenery that would block the route.

@export var planet_name: String = "Planet"
@export var radius: float = 40.0
@export var gravity_strength: float = 30.0

## Scenery is hidden once the camera is farther than this from the planet's surface.
@export var detail_distance: float = 110.0

@onready var decorations: Node3D = get_node_or_null("Decorations")
@onready var scatter: Node3D = get_node_or_null("Scatter")

func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var near: bool = camera.global_position.distance_to(global_position) - radius < detail_distance
	if decorations and decorations.visible != near:
		decorations.visible = near
	if scatter and scatter.visible != near:
		scatter.visible = near

func get_center() -> Vector3:
	return global_position

func get_up(point: Vector3) -> Vector3:
	return PlanetaryGravity.up_at(point, global_position)

func get_gravity(point: Vector3) -> Vector3:
	return PlanetaryGravity.gravity_at(point, global_position, gravity_strength)

func get_surface_point(point: Vector3) -> Vector3:
	return global_position + get_up(point) * radius

## Frees scenery (trees, rocks, tents...) closer than `clearance` to any of `points`.
## Returns how many nodes were removed. Grass is a MultiMesh and is intentionally left alone:
## running through grass is fine.
func clear_decorations_near(points: PackedVector3Array, clearance: float) -> int:
	if decorations == null:
		return 0
	var limit: float = clearance * clearance
	var removed: int = 0
	for child in decorations.get_children():
		if child.is_queued_for_deletion() or not child is Node3D:
			continue
		var pos: Vector3 = (child as Node3D).global_position
		for point in points:
			if pos.distance_squared_to(point) < limit:
				child.queue_free()
				removed += 1
				break
	return removed
