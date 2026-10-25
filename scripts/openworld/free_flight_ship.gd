class_name FreeFlightShip
extends Node3D
## The open-world jet. It hovers over a planet and goes wherever it points: the mouse (or A and D)
## turns it sideways, W and S drive forward and back, Space brakes. Its place is a direction from
## the planet's centre, so it is always upright and can circle the world forever.

@export var max_speed: float = 18.0
@export var reverse_speed: float = 8.0
@export var acceleration: float = 14.0
## Slowing down when no key is held.
@export var drag: float = 5.0
@export var brake: float = 34.0
@export var hover_height: float = 5.0
## Turning speed of A and D, in radians per second.
@export var key_turn_rate: float = 1.8
@export var bob_height: float = 0.1
@export var bob_rate: float = 2.4
@export var max_roll: float = 0.4

var center: Vector3 = Vector3.ZERO
var radius: float = 40.0
## Signed speed along the heading; negative when reversing.
var speed: float = 0.0
## Unit vector from the planet's centre to the ship.
var direction: Vector3 = Vector3.UP
## Unit heading, always along the ground.
var heading: Vector3 = Vector3.FORWARD
var input_enabled: bool = true

var _time: float = 0.0
var _turn: float = 0.0

@onready var visuals: Node3D = $Visuals

## Puts the ship above `surface_direction` of a planet, pointing along `heading_hint`, at rest.
func place_on(p_center: Vector3, p_radius: float, surface_direction: Vector3, heading_hint: Vector3) -> void:
	center = p_center
	radius = p_radius
	direction = surface_direction.normalized()
	heading = -PlanetaryGravity.surface_basis(direction, heading_hint).z
	speed = 0.0
	_turn = 0.0
	_apply_transform()

## Turns the ship; positive is to the left.
func rotate_heading(radians: float) -> void:
	heading = heading.rotated(direction, radians).normalized()
	_turn = radians
	_apply_transform()

func altitude_radius() -> float:
	return radius + hover_height

## One simulation step. `throttle` is -1 to 1, `steer` is -1 (left) to 1 (right).
func advance(delta: float, throttle: float, braking: bool, steer: float) -> void:
	_time += delta
	if not input_enabled:
		throttle = 0.0
		steer = 0.0
		braking = true
	if steer != 0.0:
		rotate_heading(-steer * key_turn_rate * delta)
	if braking:
		speed = move_toward(speed, 0.0, brake * delta)
	elif throttle > 0.0:
		speed = move_toward(speed, max_speed * throttle, acceleration * delta)
	elif throttle < 0.0:
		speed = move_toward(speed, reverse_speed * throttle, acceleration * delta)
	else:
		speed = move_toward(speed, 0.0, drag * delta)
	if not is_zero_approx(speed):
		var angle: float = speed * delta / altitude_radius()
		var axis: Vector3 = direction.cross(heading).normalized()
		var spin := Quaternion(axis, angle)
		direction = (spin * direction).normalized()
		heading = spin * heading
		heading = (heading - direction * heading.dot(direction)).normalized()
	_apply_transform()
	if visuals:
		var roll: float = clampf(_turn / maxf(delta, 0.0001) * 0.12, -max_roll, max_roll)
		visuals.position.y = sin(_time * bob_rate) * bob_height
		visuals.rotation.z = lerpf(visuals.rotation.z, roll, 1.0 - exp(-6.0 * delta))
	_turn = 0.0

## Shows or hides the jet (it is hidden while the camera sits in its nose).
func set_visuals_visible(shown: bool) -> void:
	if visuals:
		visuals.visible = shown

func get_forward() -> Vector3:
	return heading

func get_up() -> Vector3:
	return direction

func _apply_transform() -> void:
	var basis: Basis = PlanetaryGravity.surface_basis(direction, heading)
	global_transform = Transform3D(basis, center + direction * altitude_radius())
