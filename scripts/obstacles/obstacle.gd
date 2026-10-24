class_name Obstacle
extends Area3D
## A rock in the ship's path. Flying into it costs half a heart; a laser shot destroys it first.
## Collision is decided in route terms (distance along the route and lane offset), so it is exact
## and testable. The Area3D only exists so the picking ray can find the rock.

signal destroyed(obstacle: Obstacle, by_laser: bool)

enum State { ACTIVE, DESTROYED }

## Physics layer 5 (value 16) is reserved for obstacles.
const PICK_LAYER: int = 16

## Half extents of the hit box, in lane space.
@export var half_width: float = 1.0
@export var half_depth: float = 0.9

var state: State = State.ACTIVE
var route_distance: float = 0.0
## Sideways distance from the route centerline (lane index * lane width).
var lane_offset: float = 0.0

@onready var _animation: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	collision_mask = 0
	collision_layer = PICK_LAYER

func setup(distance: float, offset: float) -> void:
	route_distance = distance
	lane_offset = offset

func is_active() -> bool:
	return state == State.ACTIVE

## True when a ship at this route distance and lane offset overlaps the rock.
func overlaps(distance: float, offset: float, ship_half_width: float, ship_half_depth: float) -> bool:
	return state == State.ACTIVE \
		and absf(route_distance - distance) < half_depth + ship_half_depth \
		and absf(lane_offset - offset) < half_width + ship_half_width

func destroy(by_laser: bool = false) -> void:
	if state != State.ACTIVE:
		return
	state = State.DESTROYED
	collision_layer = 0
	if is_inside_tree() and _animation:
		_animation.play("shatter")
	destroyed.emit(self, by_laser)
