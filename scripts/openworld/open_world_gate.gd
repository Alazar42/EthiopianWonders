class_name OpenWorldGate
extends Node3D
## The ring that teleports the jet to the next world. It stays dim and shut until the planet's
## picture challenge is complete. The ring stands upright and faces along local -Z.

## Radius of the opening the jet has to fly through.
@export var opening_radius: float = 6.5
## Height of the ring's middle above the gate's base.
@export var ring_height: float = 4.8
## Looks of the ring while the gate is shut, and of the beam above it when shut and when open.
@export var locked_ring_material: Material
@export var locked_beam_color: Color = Color(0.5, 0.55, 0.65, 0.25)
@export var open_beam_color: Color = Color(0.4, 0.85, 1.0, 0.65)

var unlocked: bool = false

var _previous_side: float = 0.0
var _has_previous: bool = false

@onready var _ring: MeshInstance3D = $Transition/Gate
@onready var _beam: MeshInstance3D = $Beam

func _ready() -> void:
	set_unlocked(false)

func set_unlocked(open: bool) -> void:
	unlocked = open
	if _ring:
		_ring.material_override = null if open else locked_ring_material
	if _beam and _beam.material_override is StandardMaterial3D:
		(_beam.material_override as StandardMaterial3D).albedo_color = open_beam_color if open else locked_beam_color

func ring_center() -> Vector3:
	return global_position + global_basis.y.normalized() * ring_height

## The direction the ring faces; the jet crosses the opening along it.
func axis() -> Vector3:
	return -global_basis.z.normalized()

## True on the step the jet moves through the opening (from either side). Call every step with the
## jet's position.
func crossed_by(ship_position: Vector3) -> bool:
	var offset: Vector3 = ship_position - ring_center()
	var side: float = offset.dot(axis())
	var through: bool = false
	if _has_previous and signf(side) != signf(_previous_side) and side != _previous_side:
		var lateral: Vector3 = offset - axis() * side
		through = lateral.length() <= opening_radius
	_previous_side = side
	_has_previous = true
	return through

func distance_to(point: Vector3) -> float:
	return point.distance_to(ring_center())
