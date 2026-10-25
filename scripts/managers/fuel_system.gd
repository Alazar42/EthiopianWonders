class_name FuelSystem
extends Node
## The ship's fuel for the arcade run. It burns faster the faster the ship goes; gas tanks on the
## route refill it. This only counts fuel: the game manager decides what an empty tank means.

signal changed(fuel: float, capacity: float)
## Emitted once each time the fuel drops under the warning level.
signal low_fuel
signal ran_out
signal refueled(amount: float)

@export var capacity: float = 100.0
## Fuel burned per second at normal speed.
@export var drain_per_second: float = 2.4
## Warning level as a fraction of the capacity.
@export_range(0.05, 0.6) var low_fraction: float = 0.3

var fuel: float = 100.0

var _warned: bool = false

func reset() -> void:
	fuel = capacity
	_warned = false
	changed.emit(fuel, capacity)

func fraction() -> float:
	return fuel / capacity

func is_empty() -> bool:
	return fuel <= 0.0

func is_low() -> bool:
	return fraction() <= low_fraction

## Burns fuel for `delta` seconds; `speed_scale` is the ship's throttle (1.0 is normal speed).
func drain(delta: float, speed_scale: float = 1.0) -> void:
	if fuel <= 0.0:
		return
	fuel = maxf(0.0, fuel - drain_per_second * speed_scale * delta)
	changed.emit(fuel, capacity)
	if is_low() and not _warned:
		_warned = true
		low_fuel.emit()
	if fuel <= 0.0:
		ran_out.emit()

## Adds fuel up to the capacity and returns how much was really added.
func add(amount: float) -> float:
	var before: float = fuel
	fuel = minf(capacity, fuel + amount)
	if not is_low():
		_warned = false
	changed.emit(fuel, capacity)
	refueled.emit(fuel - before)
	return fuel - before
