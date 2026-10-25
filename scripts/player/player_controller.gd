class_name PlayerController
extends Node3D
## Flies along the route. The pilot steers freely sideways across a wide band and can throttle up
## or brake; position and orientation come from the route frame, the sideways offset and local
## gravity, so the ship is always upright relative to the planet it is flying over.
## The controller knows nothing about menus, popups or landmarks.

@export var run_speed: float = 12.0
## Throttle range as a multiple of `run_speed`.
@export var min_speed_scale: float = 0.65
@export var max_speed_scale: float = 1.4
## Width of one "lane" unit, used to size obstacle spacing and the steering band.
@export var lane_width: float = 2.4
@export var steer_band: float = 7.0
## Distance from the ground to the middle of the ship (it hovers).
@export var body_height: float = 1.0
@export var gravity_strength: float = 30.0
@export var spawn_drop: float = 0.8
@export var bob_height: float = 0.08
@export var bob_rate: float = 3.0
@export_group("Crashing")
## Half extents of the ship's hit box in lane space.
@export var hit_half_width: float = 0.55
@export var hit_half_depth: float = 0.6
## Seconds the ship cannot be hurt again (it blinks) after hitting a rock.
@export var invulnerability_seconds: float = 1.2
@export_group("Lasers")
@export var laser_scene: PackedScene
@export var impact_scene: PackedScene
## Older bolts are removed once this many are in flight.
@export var max_bolts: int = 12

var route: RouteGenerator
var distance: float = 0.0
var running: bool = false
var input_enabled: bool = true
var lane := LaneMovement.new()
var gravity := PlayerGravity.new()
## Centerline frame at the current distance.
var frame := RouteFrame.new()

var _run_time: float = 0.0

var invulnerable: float = 0.0
## Current throttle as a multiple of `run_speed`.
var speed_scale: float = 1.0
var _kick: float = 0.0
var _next_cannon: int = 0

@onready var visuals: Node3D = $Visuals
@onready var _cannons: Array[Node] = $Visuals/Cannons.get_children()

func _ready() -> void:
	lane.max_offset = steer_band

func begin_run(p_route: RouteGenerator) -> void:
	route = p_route
	distance = 0.0
	_run_time = 0.0
	lane.max_offset = steer_band
	lane.reset()
	speed_scale = 1.0
	invulnerable = 0.0
	_kick = 0.0
	gravity.reset(spawn_drop)
	running = true
	input_enabled = true
	advance(0.0)

func stop() -> void:
	running = false

## Forward speed along the route right now.
func current_speed() -> float:
	return run_speed * speed_scale

## One simulation step. Driven by the game manager so tests can step it deterministically.
func advance(delta: float) -> void:
	if route == null:
		return
	if running:
		var pilot: bool = input_enabled and is_inside_tree() and not get_tree().paused
		lane.steer = Input.get_axis("move_left", "move_right") if pilot else 0.0
		var throttle: float = Input.get_axis("move_back", "move_forward") if pilot else 0.0
		var target_scale: float = lerpf(1.0, max_speed_scale, throttle) if throttle > 0.0 else lerpf(1.0, min_speed_scale, -throttle)
		speed_scale = move_toward(speed_scale, target_scale, 2.2 * delta)
		distance += current_speed() * delta
		_run_time += delta
	route.sample(distance, frame)
	lane.update(delta)
	if frame.is_airborne():
		gravity.settle()
	else:
		gravity.update(delta, gravity_strength)
	global_transform = frame.lane_transform(lane.offset, body_height + gravity.height)
	if visuals:
		invulnerable = maxf(0.0, invulnerable - delta)
		_kick = maxf(0.0, _kick - delta * 2.2)
		visuals.position.y = sin(_run_time * bob_rate) * bob_height
		# A crash shakes the ship; afterwards it blinks while it cannot be hurt.
		visuals.rotation.x = sin(_run_time * 40.0) * 0.35 * _kick
		visuals.rotation.z = lane.roll + sin(_run_time * 33.0) * 0.5 * _kick
		visuals.visible = invulnerable <= 0.0 or int(invulnerable * 14.0) % 2 == 0

## Frame of the lane centerline at the runner's height; the camera follows this.
func center_transform() -> Transform3D:
	return frame.lane_transform(0.0, body_height)

func get_up() -> Vector3:
	return global_basis.y

func get_forward() -> Vector3:
	return -global_basis.z

## The ship hit a rock: shake it and start the invulnerability window.
func kick() -> void:
	_kick = 1.0
	invulnerable = invulnerability_seconds

func is_invulnerable() -> bool:
	return invulnerable > 0.0

## Fires one laser bolt from alternating wing cannons toward `aim_point` (world space).
## Purely visual: wonders are discovered by the game manager when the shot is aimed.
func fire_laser(aim_point: Vector3) -> LaserBolt:
	if laser_scene == null or _cannons.is_empty():
		return null
	var live: Array[Node] = get_tree().get_nodes_in_group("laser_bolts").filter(
		func(bolt: Node) -> bool: return not bolt.is_queued_for_deletion())
	if live.size() >= max_bolts:
		live[0].queue_free()
	var cannon := _cannons[_next_cannon] as Node3D
	_next_cannon = (_next_cannon + 1) % _cannons.size()
	var bolt := laser_scene.instantiate() as LaserBolt
	get_parent().add_child(bolt)
	bolt.hit.connect(_on_bolt_hit)
	bolt.fire(cannon.global_position, aim_point, get_up())
	GameSound.play(&"laser")
	return bolt

func _on_bolt_hit(point: Vector3) -> void:
	if impact_scene == null or not is_inside_tree():
		return
	GameSound.play(&"laser_hit")
	var flash := impact_scene.instantiate() as Node3D
	get_parent().add_child(flash)
	flash.global_position = point
