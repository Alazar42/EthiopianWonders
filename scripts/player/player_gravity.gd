class_name PlayerGravity
extends RefCounted
## Vertical motion along the local up axis. The route supplies the direction (away from the
## planet center), this class supplies the falling toward the surface.

var height: float = 0.0
var velocity: float = 0.0

func reset(drop_height: float = 0.0) -> void:
	height = drop_height
	velocity = 0.0

func update(delta: float, strength: float) -> void:
	velocity -= strength * delta
	height += velocity * delta
	if height <= 0.0:
		height = 0.0
		velocity = 0.0

func is_grounded() -> bool:
	return height <= 0.001

## Used while airborne between planets: the authored flight path decides the position.
func settle() -> void:
	height = 0.0
	velocity = 0.0
