class_name LandmarkTarget
extends Area3D
## Clickable marker for one wonder. Its interaction window is measured in route distance:
## it opens at `window_start` and closes at `deadline`, when the runner passes the landmark.

signal discovered(target: LandmarkTarget)
signal missed(target: LandmarkTarget)

enum State { PENDING, ACTIVE, DISCOVERED, MISSED }

## Physics layer 4 (value 8) is reserved for targets so the picking ray ignores everything else.
const PICK_LAYER: int = 8

var landmark_data: LandmarkData
var state: State = State.PENDING
var window_start: float = 0.0
var deadline: float = 0.0

@onready var animation: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	collision_mask = 0
	collision_layer = 0

func setup(data: LandmarkData, p_window_start: float, p_deadline: float) -> void:
	landmark_data = data
	window_start = p_window_start
	deadline = p_deadline
	state = State.PENDING
	collision_layer = 0

func is_active() -> bool:
	return state == State.ACTIVE

## Opens and closes the window from the runner's route progress.
func update_window(route_distance: float) -> void:
	match state:
		State.PENDING:
			if route_distance >= window_start:
				state = State.ACTIVE
				collision_layer = PICK_LAYER
		State.ACTIVE:
			if route_distance > deadline:
				_finish(State.MISSED)

## Returns true exactly once, and only while the window is open.
func attempt_interact(route_distance: float) -> bool:
	if state != State.ACTIVE:
		return false
	if route_distance < window_start or route_distance > deadline:
		return false
	_finish(State.DISCOVERED)
	return true

func disable() -> void:
	collision_layer = 0
	if state == State.ACTIVE or state == State.PENDING:
		state = State.MISSED
		visible = false

func _finish(new_state: State) -> void:
	state = new_state
	collision_layer = 0
	if is_inside_tree() and animation:
		animation.play("discovered" if new_state == State.DISCOVERED else "missed")
	if new_state == State.DISCOVERED:
		discovered.emit(self)
	else:
		missed.emit(self)
