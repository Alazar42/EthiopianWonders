class_name GameplayCamera
extends Camera3D

@export var target_node: Node3D
@export var follow_distance: float = 6.5
@export var follow_height: float = 4.2
@export var look_ahead_distance: float = 4.0
@export var follow_speed: float = 8.0
@export var rotation_speed: float = 7.0

var _is_initialized: bool = false

func _ready() -> void:
	current = true

func _physics_process(delta: float) -> void:
	if not target_node or not is_instance_valid(target_node):
		return
	
	var target_pos = target_node.global_position
	var target_up = target_node.global_basis.y
	var target_fwd = -target_node.global_basis.z
	
	# Desired camera position behind and above the target
	var desired_pos = target_pos - target_fwd * follow_distance + target_up * follow_height
	var look_target = target_pos + target_fwd * look_ahead_distance + target_up * 1.0
	
	if not _is_initialized:
		global_position = desired_pos
		look_at(look_target, target_up)
		_is_initialized = true
		return
	
	# Smooth position tracking
	global_position = global_position.lerp(desired_pos, delta * follow_speed)
	
	# Smooth orientation tracking without mouse orbit
	var look_dir = (look_target - global_position).normalized()
	if look_dir.length_squared() > 0.001 and target_up.length_squared() > 0.001:
		var target_right = look_dir.cross(target_up)
		if target_right.length_squared() > 0.001:
			target_right = target_right.normalized()
			var real_up = target_right.cross(look_dir).normalized()
			var desired_basis = Basis(target_right, real_up, -look_dir).orthonormalized()
			global_basis = global_basis.orthonormalized().slerp(desired_basis, delta * rotation_speed).orthonormalized()

## Dedicated raycast for picking in-world landmark targets with mouse
func pick_landmark_target(screen_pos: Vector2) -> LandmarkTarget:
	var from = project_ray_origin(screen_pos)
	var to = from + project_ray_normal(screen_pos) * 200.0
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 8 # Layer 4 (Landmark Target only)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result = space_state.intersect_ray(query)
	if result and result.has("collider"):
		var col = result["collider"]
		if col is LandmarkTarget:
			return col as LandmarkTarget
	return null

func reset_camera() -> void:
	_is_initialized = false
