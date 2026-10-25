class_name SpaceObject
extends Node3D
## A craft drifting between the planets: it turns slowly and bobs a little. Pure decoration; the
## name tag always faces the camera.

@export var display_name: String = ""
@export var spin_axis: Vector3 = Vector3.UP
@export var spin_speed: float = 0.3
@export var bob_height: float = 0.6
@export var bob_rate: float = 0.6

@onready var _model: Node3D = get_node_or_null("%Model")

var _time: float = 0.0

func _ready() -> void:
	_time = randf() * TAU

func _process(delta: float) -> void:
	_time += delta
	if _model == null:
		return
	_model.rotate(spin_axis.normalized(), spin_speed * delta)
	_model.position.y = sin(_time * bob_rate) * bob_height
