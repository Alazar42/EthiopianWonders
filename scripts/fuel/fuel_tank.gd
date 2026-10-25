class_name FuelTank
extends Area3D
## A gas tank floating beside the route. Shooting it refuels the ship; if the ship flies past it, it
## is gone. Its place is measured in route distance and lane offset, like a rock, and the Area3D only
## exists so the picking ray can find it.

signal collected(tank: FuelTank)
signal missed(tank: FuelTank)

enum State { ACTIVE, COLLECTED, MISSED }

## Physics layer 6 (value 32) is reserved for fuel tanks.
const PICK_LAYER: int = 32

## Fuel this tank gives.
@export var amount: float = 38.0
## The tank is lost once the ship is this far past it.
@export var miss_margin: float = 3.0

var state: State = State.ACTIVE
var route_distance: float = 0.0
var lane_offset: float = 0.0

@onready var _animation: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	collision_mask = 0
	collision_layer = PICK_LAYER

func setup(distance: float, offset: float) -> void:
	route_distance = distance
	lane_offset = offset
	state = State.ACTIVE
	collision_layer = PICK_LAYER

func is_active() -> bool:
	return state == State.ACTIVE

## The ship has flown past: the tank is lost.
func update_window(ship_distance: float) -> void:
	if state == State.ACTIVE and ship_distance > route_distance + miss_margin:
		_finish(State.MISSED)

## A laser hit it. Returns true exactly once.
func collect() -> bool:
	if state != State.ACTIVE:
		return false
	_finish(State.COLLECTED)
	return true

func disable() -> void:
	collision_layer = 0
	if state == State.ACTIVE:
		state = State.MISSED
		visible = false

func _finish(new_state: State) -> void:
	state = new_state
	collision_layer = 0
	if is_inside_tree() and _animation:
		_animation.play("collected" if new_state == State.COLLECTED else "missed")
	if new_state == State.COLLECTED:
		collected.emit(self)
	else:
		missed.emit(self)
