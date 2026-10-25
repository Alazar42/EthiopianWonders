class_name OpenWorldCamera
extends Camera3D
## Two views of the open-world jet. The chase view follows from behind. The photo view sits in the
## jet's nose and swings to the artifact, like the camera in GTA San Andreas: the mouse looks around
## and zooming narrows the field of view.

enum Mode { CHASE, PHOTO }

@export var ship: FreeFlightShip
@export_group("Chase")
@export var follow_distance: float = 8.5
@export var follow_height: float = 3.6
@export var look_ahead: float = 9.0
@export var look_height: float = 0.8
@export var follow_speed: float = 7.0
@export var chase_fov: float = 65.0
## Extra field of view while dashing, for a sense of speed.
@export var dash_fov_boost: float = 12.0
## The camera pulls back a little while the jet flies between worlds.
@export var transit_extra_distance: float = 4.0
@export var transit_extra_height: float = 3.0
@export var transit_follow_speed: float = 2.6
@export_group("Photo")
## Where the lens sits, relative to the jet.
@export var lens_offset: Vector3 = Vector3(0.0, 0.5, -1.4)
@export var start_fov: float = 55.0
@export var min_fov: float = 8.0
@export var max_fov: float = 75.0
@export var max_yaw: float = 1.5
@export var max_pitch: float = 0.9
## Seconds the view takes to swing between the two cameras.
@export var blend_time: float = 0.45

var mode: Mode = Mode.CHASE
var photo_yaw: float = 0.0
var photo_pitch: float = 0.0
var photo_fov: float = 55.0
## 0 in the chase view, 1 once the photo camera is fully in place.
var blend: float = 0.0
## Set by the game while the jet flies between worlds.
var in_transit: bool = false

var _transit_blend: float = 0.0
var _dash_blend: float = 0.0
var _rotation := Quaternion.IDENTITY
var _initialized: bool = false

func _ready() -> void:
	current = true
	photo_fov = start_fov

func snap() -> void:
	_initialized = false
	blend = 1.0 if mode == Mode.PHOTO else 0.0
	update_follow(0.0)

func _process(delta: float) -> void:
	update_follow(delta)

func update_follow(delta: float) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	var ship_basis: Basis = ship.global_basis.orthonormalized()
	var target := Quaternion(ship_basis)
	if not _initialized:
		_rotation = target
		_initialized = true
	else:
		var speed: float = transit_follow_speed if in_transit else follow_speed
		_rotation = _rotation.slerp(target, 1.0 - exp(-speed * delta)).normalized()
	_transit_blend = move_toward(_transit_blend, 1.0 if in_transit else 0.0, delta * 0.8)
	_dash_blend = move_toward(_dash_blend, 1.0 if ship.dashing else 0.0, delta * 4.0)
	blend = move_toward(blend, 1.0 if mode == Mode.PHOTO else 0.0, delta / maxf(blend_time, 0.01))
	var chase_basis := Basis(_rotation)
	var chase_origin: Vector3 = ship.global_position + chase_basis * Vector3(0.0, follow_height + transit_extra_height * _transit_blend,
			follow_distance + transit_extra_distance * _transit_blend)
	var chase_look: Vector3 = ship.global_position + chase_basis * Vector3(0.0, look_height, -look_ahead)
	var chase_pose := Transform3D(chase_basis, chase_origin).looking_at(chase_look, chase_basis.y)
	if blend <= 0.0:
		global_transform = chase_pose
		fov = chase_fov + dash_fov_boost * _dash_blend
		return
	var photo_basis: Basis = ship_basis * Basis(Vector3.UP, photo_yaw) * Basis(Vector3.RIGHT, photo_pitch)
	var photo_pose := Transform3D(photo_basis, ship.global_position + ship_basis * lens_offset)
	var t: float = smoothstep(0.0, 1.0, blend)
	global_transform = Transform3D(
			Basis(chase_pose.basis.get_rotation_quaternion().slerp(photo_pose.basis.get_rotation_quaternion(), t)),
			chase_pose.origin.lerp(photo_pose.origin, t))
	fov = lerpf(chase_fov + dash_fov_boost * _dash_blend, photo_fov, t)

func is_photo_ready() -> bool:
	return mode == Mode.PHOTO and blend >= 0.95

## Switches to the photo view, optionally already turned toward `world_point`.
func enter_photo(world_point: Variant = null) -> void:
	mode = Mode.PHOTO
	photo_fov = start_fov
	photo_yaw = 0.0
	photo_pitch = 0.0
	if world_point is Vector3:
		look_toward(world_point as Vector3)

func exit_photo() -> void:
	mode = Mode.CHASE

## Turns the photo view toward a point in the world.
func look_toward(world_point: Vector3) -> void:
	if ship == null:
		return
	var ship_basis: Basis = ship.global_basis.orthonormalized()
	var lens: Vector3 = ship.global_position + ship_basis * lens_offset
	var local: Vector3 = (ship_basis.inverse() * (world_point - lens)).normalized()
	photo_yaw = clampf(atan2(-local.x, -local.z), -max_yaw, max_yaw)
	photo_pitch = clampf(asin(clampf(local.y, -1.0, 1.0)), -max_pitch, max_pitch)

## Mouse movement in the photo view. Aiming gets finer as the zoom grows.
func look(relative: Vector2, sensitivity: float) -> void:
	var scale: float = photo_fov / start_fov
	photo_yaw = clampf(photo_yaw - relative.x * sensitivity * scale, -max_yaw, max_yaw)
	photo_pitch = clampf(photo_pitch - relative.y * sensitivity * scale, -max_pitch, max_pitch)

## Positive `amount` zooms in, negative zooms out.
func zoom(amount: float) -> void:
	photo_fov = clampf(photo_fov * exp(-amount), min_fov, max_fov)

## How magnified the photo view is compared with its starting view.
func zoom_factor() -> float:
	return start_fov / photo_fov

## True when `point` is in front of the lens and inside the screen, shrunk by `margin` (0 to 0.5)
## of the screen size on every side.
func point_in_frame(point: Vector3, margin: float = 0.0) -> bool:
	if is_position_behind(point):
		return false
	var size: Vector2 = get_viewport().get_visible_rect().size
	var inner := Rect2(size * margin, size * (1.0 - 2.0 * margin))
	return inner.has_point(unproject_position(point))
