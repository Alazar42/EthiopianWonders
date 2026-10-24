extends RigidBody3D

const MOVE_SPEED := 20.0
const SENSITIVITY := 0.003
const PLANET_RADIUS := 8.4
const PLAYER_SURFACE_OFFSET := 0.5
const JUMP_SPEED := 7.0
const PLANET_GRAVITY := 18.0
const CAMERA_SMOOTH_SPEED := 10.0

@onready var head: Node3D = $PlayerHead
@onready var camera: Camera3D = $PlayerHead/Camera3D

var planet_center := Vector3.ZERO
var pending_mouse_turn := 0.0
var jump_height := 0.0
var jump_velocity := 0.0
var target_camera_pitch := 0.0
var camera_local_offset := Vector3.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# The planet's point-gravity Area3D supplies the inward pull. Keep the body
	# free to rotate so it can settle against the local surface normal.
	lock_rotation = false
	linear_damp = 2.0
	angular_damp = 8.0
	camera_local_offset = camera.position
	var initial_camera_transform := camera.global_transform
	camera.set_as_top_level(true)
	camera.global_transform = initial_camera_transform

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		pending_mouse_turn -= event.relative.x * SENSITIVITY
		target_camera_pitch = clamp(
			target_camera_pitch - event.relative.y * SENSITIVITY,
			deg_to_rad(-40),
			deg_to_rad(10)
		)
	elif event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	var target_position := head.global_transform * camera_local_offset
	var target_basis := head.global_transform.basis * Basis(Vector3.RIGHT, target_camera_pitch)
	var target_transform := Transform3D(target_basis, target_position)
	camera.global_transform = camera.global_transform.interpolate_with(
		target_transform,
		1.0 - exp(-CAMERA_SMOOTH_SPEED * delta)
	)

func _physics_process(delta: float) -> void:
	var up := (global_position - planet_center).normalized()
	if up.length_squared() < 0.01:
		up = Vector3.UP
	if not is_zero_approx(pending_mouse_turn):
		global_transform.basis = (
			Basis(up, pending_mouse_turn) * global_transform.basis
		).orthonormalized()
		pending_mouse_turn = 0.0

	if Input.is_action_just_pressed("ui_accept") and is_zero_approx(jump_height):
		jump_velocity = JUMP_SPEED
	jump_velocity -= PLANET_GRAVITY * delta
	jump_height = maxf(0.0, jump_height + jump_velocity * delta)
	if is_zero_approx(jump_height):
		jump_velocity = 0.0

	# Constrain the player to the sphere, allowing only the scripted jump arc
	# above its surface. Gravity brings the jump back to height zero.
	global_position = planet_center + up * (
		PLANET_RADIUS + PLAYER_SURFACE_OFFSET + jump_height
	)

	# Keep the player's local up aligned with the planet's surface normal.
	# Movement follows the body orientation, so turning the camera does not
	# change the direction the player travels.
	var forward := -global_transform.basis.z
	forward = forward.slide(up).normalized()
	if forward.length_squared() < 0.01:
		forward = up.cross(Vector3.RIGHT).normalized()
		if forward.length_squared() < 0.01:
			forward = up.cross(Vector3.FORWARD).normalized()
	var right := forward.cross(up).normalized()
	var target_basis := Basis(right, up, -forward).orthonormalized()
	global_transform.basis = global_transform.basis.slerp(target_basis, 0.2).orthonormalized()

	var input := Vector2.ZERO
	input.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
	input.x -= float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	input.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	input.y -= float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	input = input.limit_length(1.0)
	var move_direction := (right * input.x + forward * -input.y).normalized()
	# Set tangential movement directly, stopping drift when the keys are released.
	if move_direction.length_squared() > 0.0:
		linear_velocity = move_direction * MOVE_SPEED
	else:
		linear_velocity = Vector3.ZERO
