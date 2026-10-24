class_name DiscoveryManager
extends Node

signal wonder_discovered(landmark: LandmarkData, total_count: int)
signal wonder_missed(landmark: LandmarkData, remaining_hearts: int)
signal hearts_changed(current: int, max_hearts: int)
signal game_over_reached(total_discovered: int, distance_m: float, time_sec: float)

@export var max_hearts: int = 3
var current_hearts: int = 3
var discovered_wonders: Array[LandmarkData] = []
var run_distance: float = 0.0
var elapsed_time: float = 0.0
var is_active: bool = true

func _ready() -> void:
	reset_run()

func reset_run() -> void:
	current_hearts = max_hearts
	discovered_wonders.clear()
	run_distance = 0.0
	elapsed_time = 0.0
	is_active = true
	LandmarkCatalog.reset_all_discoveries()
	hearts_changed.emit(current_hearts, max_hearts)

func update_stats(delta: float, distance_m: float) -> void:
	if is_active:
		elapsed_time += delta
		run_distance = distance_m

func register_discovery(landmark: LandmarkData) -> void:
	if not is_active:
		return
	if not discovered_wonders.has(landmark):
		discovered_wonders.append(landmark)
	wonder_discovered.emit(landmark, discovered_wonders.size())

func register_miss(landmark: LandmarkData) -> void:
	if not is_active:
		return
	current_hearts = maxi(0, current_hearts - 1)
	hearts_changed.emit(current_hearts, max_hearts)
	wonder_missed.emit(landmark, current_hearts)
	
	if current_hearts <= 0:
		is_active = false
		game_over_reached.emit(discovered_wonders.size(), run_distance, elapsed_time)
