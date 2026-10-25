class_name AmmoCrate
extends FuelTank
## A crate of laser rounds floating beside the route. It works exactly like a gas tank (shoot it
## to claim it, fly past and it is gone); `amount` is the number of rounds it holds.

func _init() -> void:
	amount = 4.0
