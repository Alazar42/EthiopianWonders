class_name PlayerController
extends CharacterBody3D

signal distance_updated(distance_m: float)
signal lane_changed(new_lane: int)
signal planet_arrived(planet: SphericalPlanet)

@export var run_speed: float = 14.0
@export var is_running: bool = true
@export var current_planet: SphericalPlanet
@export var lane_width: float = 2.4

var current_lane: int = 0
var target_lane: int = 0
var lane_offset: float = 0.0
var forward_dir: Vector3 = Vector3.FORWARD
var distance_travelled: float = 0.0

# Planetary transition state
var is_transitioning: bool = false
var transition_time: float = 0.0
var transition_duration: float = 3.2
var launch_start_pos: Vector3 = Vector3.ZERO
var launch_start_up: Vector3 = Vector3.UP
var launch_end_pos: Vector3 = Vector3.ZERO
var launch_end_up: Vector3 = Vector3.UP
var launch_dest_planet: SphericalPlanet = null

@onready var visuals: Node3D = $Visuals
var _run_time: float = 0.0

func _ready() -> void:
	if current_planet:
		_snap_to_planet(current_planet)

func _snap_to_planet(planet: SphericalPlanet) -> void:
	current_planet = planet
	var center = planet.global_position
	var cur_up = (global_position - center).normalized()
	if cur_up.length_squared() < 0.001:
		cur_up = Vector3.UP
	global_position = center + cur_up * (planet.radius + 0.9)
	
	# Compute tangent forward orthogonal to cur_up
	var proj_fwd = forward_dir - cur_up * forward_dir.dot(cur_up)
	if proj_fwd.length_squared() < 0.01:
		var fallback = Vector3.UP if abs(cur_up.dot(Vector3.UP)) < 0.8 else Vector3.RIGHT
		proj_fwd = (fallback - cur_up * fallback.dot(cur_up)).normalized()
	else:
		proj_fwd = proj_fwd.normalized()
	forward_dir = proj_fwd
	
	var right = forward_dir.cross(cur_up).normalized()
	if right.length_squared() < 0.01:
		right = Vector3.RIGHT
	global_basis = Basis(right, cur_up, -forward_dir).orthonormalized()

func _unhandled_input(event: InputEvent) -> void:
	if not is_running or is_transitioning:
		return
	
	if event.is_action_pressed("move_left"):
		shift_lane(-1)
	elif event.is_action_pressed("move_right"):
		shift_lane(1)

func shift_lane(direction: int) -> void:
	var next_lane = clampi(target_lane + direction, -1, 1)
	if next_lane != target_lane:
		target_lane = next_lane
		current_lane = target_lane
		lane_changed.emit(current_lane)

func _physics_process(delta: float) -> void:
	if not is_running:
		return
	
	_run_time += delta
	
	if is_transitioning:
		_process_planet_transition(delta)
	else:
		_process_planet_run(delta)

func _process_planet_run(delta: float) -> void:
	if not current_planet or not is_instance_valid(current_planet):
		return
	
	var center = current_planet.global_position
	var rad = current_planet.radius
	
	# 1. Advance distance along surface
	var arc_step = run_speed * delta
	distance_travelled += arc_step
	distance_updated.emit(distance_travelled)
	
	# Current surface normal and right tangent
	var up_normal = (global_position - center).normalized()
	var proj = forward_dir - up_normal * forward_dir.dot(up_normal)
	if proj.length_squared() < 0.01:
		var fallback = Vector3.UP if abs(up_normal.dot(Vector3.UP)) < 0.8 else Vector3.RIGHT
		proj = (fallback - up_normal * fallback.dot(up_normal))
	var fwd_tangent = proj.normalized()
	var right_tangent = fwd_tangent.cross(up_normal).normalized()
	if right_tangent.length_squared() < 0.01:
		right_tangent = Vector3.RIGHT
	
	# 2. Advance forward along the sphere circumference
	var angle = arc_step / rad
	var new_normal = up_normal.rotated(-right_tangent, angle).normalized()
	fwd_tangent = fwd_tangent.rotated(-right_tangent, angle).normalized()
	fwd_tangent = (fwd_tangent - new_normal * fwd_tangent.dot(new_normal)).normalized()
	right_tangent = fwd_tangent.cross(new_normal).normalized()
	if right_tangent.length_squared() < 0.01:
		right_tangent = Vector3.RIGHT
	forward_dir = fwd_tangent
	
	# 3. Smooth lane switching
	var target_offset = float(target_lane) * lane_width
	lane_offset = move_toward(lane_offset, target_offset, delta * 12.0)
	
	# 4. Position on sphere surface with lane offset
	var center_surface = center + new_normal * rad
	var lane_surface = center_surface + right_tangent * lane_offset
	var final_up = (lane_surface - center).normalized()
	global_position = center + final_up * (rad + 0.9)
	
	# 5. Perfect orthonormal orientation (Feet pointing at center, head pointing out)
	var final_fwd = (forward_dir - final_up * forward_dir.dot(final_up)).normalized()
	var final_right = final_fwd.cross(final_up).normalized()
	global_basis = Basis(final_right, final_up, -final_fwd).orthonormalized()
	
	# 6. Visual running bob
	if visuals:
		visuals.position.y = abs(sin(_run_time * 12.0)) * 0.12

## Launch cinematic flight to another spherical planet
func launch_to_planet(destination: SphericalPlanet, duration: float = 3.2) -> void:
	if not destination or is_transitioning:
		return
	
	is_transitioning = true
	transition_time = 0.0
	transition_duration = duration
	launch_dest_planet = destination
	launch_start_pos = global_position
	launch_start_up = (global_position - current_planet.global_position).normalized()
	
	# Calculate landing point on the destination planet facing the origin planet
	var dir_to_dest = (destination.global_position - current_planet.global_position).normalized()
	# The landing normal points OUTWARD from destination planet toward origin planet
	launch_end_up = -dir_to_dest
	launch_end_pos = destination.global_position + launch_end_up * (destination.radius + 0.9)

func _process_planet_transition(delta: float) -> void:
	transition_time += delta
	var t = clampf(transition_time / transition_duration, 0.0, 1.0)
	var ease_t = smoothstep(0.0, 1.0, t)
	
	# Elevated Bezier arch through space between planets
	var span_dir = (launch_end_pos - launch_start_pos).normalized()
	var mid_elev = (launch_start_up + launch_end_up).normalized() * 25.0
	var mid_pos = (launch_start_pos + launch_end_pos) * 0.5 + mid_elev
	
	var omt = 1.0 - ease_t
	global_position = omt * omt * launch_start_pos + 2.0 * omt * ease_t * mid_pos + ease_t * ease_t * launch_end_pos
	
	# CRITICAL: UP DIRECTION SLERPS OUTWARD (FEET INWARD, HEAD OUTWARD, NEVER UPSIDE DOWN)
	var cur_up = launch_start_up.slerp(launch_end_up, ease_t).normalized()
	var cur_fwd = (span_dir - cur_up * span_dir.dot(cur_up)).normalized()
	var cur_right = cur_fwd.cross(cur_up).normalized()
	global_basis = Basis(cur_right, cur_up, -cur_fwd).orthonormalized()
	
	if t >= 1.0:
		is_transitioning = false
		current_planet = launch_dest_planet
		_snap_to_planet(current_planet)
		planet_arrived.emit(current_planet)

func reset_player(planet: SphericalPlanet) -> void:
	distance_travelled = 0.0
	_run_time = 0.0
	is_running = true
	is_transitioning = false
	current_lane = 0
	target_lane = 0
	lane_offset = 0.0
	forward_dir = Vector3.FORWARD
	if planet:
		_snap_to_planet(planet)
