class_name GameplayCamera
extends Camera3D
## Third-person follow camera. The player cannot move it. It tracks a smoothed copy of the
## runner's local frame, so turns and planet changes blend instead of snapping, and it never
## flips because the frame always comes from the planet's own up direction.

@export var player: PlayerController
@export var follow_distance: float = 6.0
@export var follow_height: float = 3.5
@export var look_ahead: float = 8.0
@export var look_height: float = 0.8
@export var frame_follow_speed: float = 6.0
@export var flight_follow_speed: float = 2.6
@export_range(0.0, 1.0) var lateral_follow: float = 0.55
@export var flight_extra_distance: float = 4.0
@export var flight_extra_height: float = 3.0

## Screen shake strength; add to it with add_shake(), it fades on its own.
var shake: float = 0.0

var _base_fov: float = 65.0
var _fov_kick: float = 0.0
var _speed_fov: float = 0.0

var _frame_rotation := Quaternion.IDENTITY
var _flight_blend: float = 0.0
var _initialized: bool = false

func _ready() -> void:
	current = true
	_base_fov = fov

func add_shake(amount: float) -> void:
	shake = minf(1.0, shake + amount)

## A quick widening of the view that eases back (shots, pickups).
func kick_fov(degrees: float) -> void:
	_fov_kick = minf(8.0, _fov_kick + degrees)

func snap() -> void:
	shake = 0.0
	_initialized = false
	_flight_blend = 0.0
	update_follow(0.0)

func _process(delta: float) -> void:
	update_follow(delta)

func update_follow(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.route == null:
		return
	var frame: RouteFrame = player.frame
	var target := Quaternion(Basis(frame.right, frame.up, -frame.forward).orthonormalized())
	if not _initialized:
		_frame_rotation = target
		_initialized = true
	else:
		var airborne: bool = frame.is_airborne()
		var speed: float = flight_follow_speed if airborne else frame_follow_speed
		_frame_rotation = _frame_rotation.slerp(target, 1.0 - exp(-speed * delta)).normalized()
		_flight_blend = move_toward(_flight_blend, 1.0 if airborne else 0.0, delta * 0.8)
	var speed_target: float = clampf((player.current_speed() / maxf(player.run_speed, 0.1) - 1.0) * 12.0, -2.0, 9.0)
	_speed_fov = lerpf(_speed_fov, speed_target, 1.0 - exp(-3.0 * delta))
	_fov_kick = move_toward(_fov_kick, 0.0, delta * 12.0)
	fov = _base_fov + _speed_fov + _fov_kick
	var basis := Basis(_frame_rotation)
	var center: Vector3 = player.center_transform().origin
	var anchor: Vector3 = center.lerp(player.global_position, lateral_follow)
	var offset := Vector3(0.0, follow_height + flight_extra_height * _flight_blend,
			follow_distance + flight_extra_distance * _flight_blend)
	var look_target: Vector3 = anchor + basis * Vector3(0.0, look_height, -look_ahead)
	global_position = anchor + basis * offset
	look_at(look_target, basis.y)
	if shake > 0.0:
		global_position += (basis.x * randf_range(-1.0, 1.0) + basis.y * randf_range(-1.0, 1.0)) * shake * 0.35
		shake = maxf(0.0, shake - delta * 2.4)

## Dedicated ray from the camera through the cursor. Only the target, obstacle and fuel tank layers are
## tested, so the planet, the ship and scenery can never be mistaken for either. Returns the wonder
## target hit (or null), the obstacle hit (or null) and the point the laser should aim at: the hit
## point, or far along the ray on a miss.
func aim_ray(screen_pos: Vector2, max_distance: float = 400.0, miss_distance: float = 90.0) -> Dictionary:
	var origin: Vector3 = project_ray_origin(screen_pos)
	var direction: Vector3 = project_ray_normal(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_distance,
			LandmarkTarget.PICK_LAYER | Obstacle.PICK_LAYER | FuelTank.PICK_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {"target": null, "obstacle": null, "tank": null, "point": origin + direction * miss_distance}
	return {"target": hit["collider"] as LandmarkTarget, "obstacle": hit["collider"] as Obstacle,
			"tank": hit["collider"] as FuelTank, "point": hit["position"]}

func pick_target(screen_pos: Vector2, max_distance: float = 400.0) -> LandmarkTarget:
	return aim_ray(screen_pos, max_distance)["target"]
