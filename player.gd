extends RigidBody3D

const MOVE_SPEED := 20.0
const SENSITIVITY := 0.003
const PLANET_RADIUS := 6.0
const PLAYER_SURFACE_OFFSET := 0.5

@onready var head: Node3D = $PlayerHead
@onready var camera: Camera3D = $PlayerHead/Camera3D

var planet_center := Vector3.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# The planet's point-gravity Area3D supplies the inward pull. Keep the body
	# free to rotate so it can settle against the local surface normal.
	lock_rotation = false
	linear_damp = 2.0
	angular_damp = 8.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		head.rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotate_x(-event.relative.y * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-80), deg_to_rad(80))
	elif event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(_delta: float) -> void:
	var up := (global_position - planet_center).normalized()
	if up.length_squared() < 0.01:
		up = Vector3.UP

	# Keep the player's center exactly one half-player-height above the planet
	# surface. The planet is centered at the origin and has a radius of 6.
	global_position = planet_center + up * (PLANET_RADIUS + PLAYER_SURFACE_OFFSET)

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
	# Set only the surface-parallel velocity. This stops the player immediately
	# when no movement key is held, while leaving inward gravity intact.
	if move_direction.length_squared() > 0.0:
		linear_velocity = move_direction * MOVE_SPEED
	else:
		linear_velocity = Vector3.ZERO
