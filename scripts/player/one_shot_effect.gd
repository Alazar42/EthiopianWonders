class_name OneShotEffect
extends Node3D
## A short effect whose AnimationPlayer plays once and then removes the whole scene.

@onready var _animation: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_animation.animation_finished.connect(func(_name: StringName) -> void: queue_free())
