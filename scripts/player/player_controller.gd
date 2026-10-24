class_name PlayerController
extends Node3D
## Runs the route automatically. Position and orientation come from the route frame, lane offset
## and local gravity, so the runner is always upright relative to the planet it is standing on.
## The controller knows nothing about menus, popups or landmarks.

signal lane_changed(lane: int)

@export var run_speed: float = 12.0
@export var lane_width: float = 2.4
## Distance from the feet to the center of the capsule.
@export var body_height: float = 0.9
@export var gravity_strength: float = 30.0
@export var spawn_drop: float = 0.8
@export var bob_height: float = 0.07
@export var bob_rate: float = 11.0

var route: RouteGenerator
var distance: float = 0.0
var running: bool = false
var input_enabled: bool = true
var lane := LaneMovement.new()
var gravity := PlayerGravity.new()
## Centerline frame at the current distance.
var frame := RouteFrame.new()

var _run_time: float = 0.0

@onready var visuals: Node3D = $Visuals

func _ready() -> void:
	lane.lane_changed.connect(func(l: int) -> void: lane_changed.emit(l))

func begin_run(p_route: RouteGenerator) -> void:
	route = p_route
	distance = 0.0
	_run_time = 0.0
	lane.lane_width = lane_width
	lane.reset()
	gravity.reset(spawn_drop)
	running = true
	input_enabled = true
	advance(0.0)

func stop() -> void:
	running = false

func _unhandled_input(event: InputEvent) -> void:
	if not running or not input_enabled:
		return
	if event.is_action_pressed("move_left"):
		lane.shift(-1)
	elif event.is_action_pressed("move_right"):
		lane.shift(1)

## One simulation step. Driven by the game manager so tests can step it deterministically.
func advance(delta: float) -> void:
	if route == null:
		return
	if running:
		distance += run_speed * delta
		_run_time += delta
	route.sample(distance, frame)
	lane.update(delta)
	if frame.is_airborne():
		gravity.settle()
	else:
		gravity.update(delta, gravity_strength)
	global_transform = frame.lane_transform(lane.offset, body_height + gravity.height)
	if visuals:
		var bob: float = absf(sin(_run_time * bob_rate)) * bob_height if gravity.is_grounded() else 0.0
		visuals.position.y = bob
		visuals.rotation.z = lane.roll

## Frame of the lane centerline at the runner's height; the camera follows this.
func center_transform() -> Transform3D:
	return frame.lane_transform(0.0, body_height)

func get_up() -> Vector3:
	return global_basis.y

func get_forward() -> Vector3:
	return -global_basis.z
