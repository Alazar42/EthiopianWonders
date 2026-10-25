class_name DiscoveryManager
extends Node
## Run-scoped bookkeeping: health, discovered wonders and run statistics.
## Health is counted in half hearts: a missed wonder costs a whole heart, an obstacle half a heart.

signal wonder_discovered(landmark: LandmarkData, total_count: int)
signal wonder_missed(landmark: LandmarkData, remaining_hearts: float)
signal obstacle_hit(remaining_hearts: float)
signal obstacle_destroyed(total_count: int)
## Emitted with the current and maximum health in half hearts.
signal hearts_changed(current_halves: int, max_halves: int)
signal game_over_reached(stats: Dictionary)

const HALVES_PER_HEART: int = 2
const MISS_COST: int = 2
const OBSTACLE_COST: int = 1

## Points: a wonder is worth the most, then reaching a new planet; every metre and every rock
## blasted adds a little.
const POINTS_PER_WONDER: int = 500
const POINTS_PER_PLANET: int = 150
const POINTS_PER_ROCK: int = 25
const POINTS_PER_METRE: int = 1
const POINTS_PER_TANK: int = 20

@export var max_hearts: int = 3

var health_halves: int = 6
var discovered_wonders: Array[LandmarkData] = []
var missed_count: int = 0
var obstacles_hit: int = 0
var obstacles_destroyed: int = 0
var planets_reached: int = 0
var tanks_collected: int = 0
## Why the run ended: "hearts" or "fuel".
var end_reason: String = "hearts"
var run_distance: float = 0.0
var elapsed_time: float = 0.0
var is_active: bool = false

## Hearts left, in whole and half hearts (2.5 means two and a half).
var current_hearts: float:
	get:
		return float(health_halves) / float(HALVES_PER_HEART)

func max_halves() -> int:
	return max_hearts * HALVES_PER_HEART

func reset_run() -> void:
	health_halves = max_halves()
	discovered_wonders.clear()
	missed_count = 0
	obstacles_hit = 0
	obstacles_destroyed = 0
	planets_reached = 0
	tanks_collected = 0
	end_reason = "hearts"
	run_distance = 0.0
	elapsed_time = 0.0
	is_active = true
	LandmarkCatalog.reset_all_discoveries()
	hearts_changed.emit(health_halves, max_halves())

func update_stats(delta: float, distance_m: float) -> void:
	if is_active:
		elapsed_time += delta
		run_distance = distance_m

## Returns false for a duplicate, so one wonder can never be awarded twice.
func register_discovery(landmark: LandmarkData) -> bool:
	if not is_active or landmark == null or discovered_wonders.has(landmark):
		return false
	landmark.discovered = true
	discovered_wonders.append(landmark)
	wonder_discovered.emit(landmark, discovered_wonders.size())
	return true

func register_miss(landmark: LandmarkData) -> void:
	if not is_active:
		return
	missed_count += 1
	_lose(MISS_COST)
	wonder_missed.emit(landmark, current_hearts)
	_check_game_over()

## The ship crashed into an obstacle.
func register_obstacle_hit() -> void:
	if not is_active:
		return
	obstacles_hit += 1
	_lose(OBSTACLE_COST)
	obstacle_hit.emit(current_hearts)
	_check_game_over()

func register_planet_arrival() -> void:
	if is_active:
		planets_reached += 1

## The run's score so far.
func score() -> int:
	return discovered_wonders.size() * POINTS_PER_WONDER + planets_reached * POINTS_PER_PLANET \
		+ obstacles_destroyed * POINTS_PER_ROCK + tanks_collected * POINTS_PER_TANK + int(run_distance) * POINTS_PER_METRE

## A gas tank was shot.
func register_tank() -> void:
	if is_active:
		tanks_collected += 1

## The ship ran dry and came to a stop: the run ends.
func register_out_of_fuel() -> void:
	if not is_active:
		return
	is_active = false
	end_reason = "fuel"
	game_over_reached.emit(stats())

func register_obstacle_destroyed() -> void:
	if not is_active:
		return
	obstacles_destroyed += 1
	obstacle_destroyed.emit(obstacles_destroyed)

func stats() -> Dictionary:
	return {
		"wonders": discovered_wonders.size(),
		"obstacles_destroyed": obstacles_destroyed,
		"obstacles_hit": obstacles_hit,
		"planets": planets_reached,
		"tanks": tanks_collected,
		"reason": end_reason,
		"score": score(),
		"distance": run_distance,
		"time": elapsed_time,
	}

func _lose(halves: int) -> void:
	health_halves = maxi(0, health_halves - halves)
	hearts_changed.emit(health_halves, max_halves())

func _check_game_over() -> void:
	if health_halves <= 0 and is_active:
		is_active = false
		game_over_reached.emit(stats())
