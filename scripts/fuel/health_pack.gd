class_name HealthPack
extends FuelTank
## A floating health pack. Shooting it restores every heart. It works like a gas tank or an ammo
## crate (shoot it to claim it, fly past and it is gone) but is much rarer.

func _init() -> void:
	amount = 6.0
