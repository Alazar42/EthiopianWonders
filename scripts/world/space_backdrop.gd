class_name SpaceBackdrop
extends Node3D
## Distant planets and drifting dust that travel with the camera. Because they never get closer,
## the universe always seems to continue beyond the next world.

func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position
