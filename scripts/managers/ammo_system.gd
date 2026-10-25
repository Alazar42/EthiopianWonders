class_name AmmoSystem
extends Node
## The ship's laser ammo for the arcade run. Every shot costs one; ammo crates on the route give a
## few back. It is meant to be scarce: you cannot shoot everything, so each shot has to count.

signal changed(count: int, capacity: int)
## Emitted when the last round is spent.
signal emptied
## Emitted once each time the ammo drops to the warning level.
signal low_ammo
signal refilled(amount: int)

## Rounds at the start of a run.
@export var starting_ammo: int = 10
## The most the ship can carry.
@export var capacity: int = 12
## The warning shows at or under this many rounds.
@export var low_level: int = 3

var count: int = 10

var _warned: bool = false

func reset() -> void:
	count = mini(starting_ammo, capacity)
	_warned = false
	changed.emit(count, capacity)

func is_empty() -> bool:
	return count <= 0

func is_low() -> bool:
	return count <= low_level

func can_fire() -> bool:
	return count > 0

## Spends one round. Returns false (and spends nothing) when there is none.
func spend() -> bool:
	if count <= 0:
		return false
	count -= 1
	changed.emit(count, capacity)
	if count <= low_level and not _warned:
		_warned = true
		low_ammo.emit()
	if count <= 0:
		emptied.emit()
	return true

## Adds rounds up to the capacity and returns how many were really added.
func add(amount: int) -> int:
	var before: int = count
	count = mini(capacity, count + amount)
	if count > low_level:
		_warned = false
	changed.emit(count, capacity)
	refilled.emit(count - before)
	return count - before
