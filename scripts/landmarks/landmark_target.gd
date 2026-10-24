class_name LandmarkTarget
extends Area3D

signal target_discovered(landmark: LandmarkData)
signal target_missed(landmark: LandmarkData)

@export var landmark_data: LandmarkData

var is_active: bool = true
var is_discovered: bool = false
var is_missed: bool = false

@onready var visuals: Node3D = get_node_or_null("Visuals")
@onready var prompt_label: Label3D = get_node_or_null("Visuals/PromptLabel")
@onready var omni_light: OmniLight3D = get_node_or_null("Visuals/OmniLight3D")

var _time: float = 0.0

func _ready() -> void:
	collision_layer = 8 # Layer 4 for target picking
	collision_mask = 0
	if not visuals:
		visuals = get_node_or_null("Visuals")
	update_visuals()

func setup(p_data: LandmarkData) -> void:
	landmark_data = p_data
	is_active = true
	is_discovered = false
	is_missed = false
	update_visuals()

func update_visuals() -> void:
	if not landmark_data:
		return
	if prompt_label:
		prompt_label.text = "✦ DISCOVER ✦\n" + landmark_data.name
	if omni_light:
		omni_light.light_color = landmark_data.color

func _process(delta: float) -> void:
	_time += delta
	if visuals and is_active and not is_discovered and not is_missed:
		# Floating and rotating animation
		visuals.position.y = sin(_time * 3.0) * 0.25
		visuals.rotate_y(delta * 1.5)
	elif visuals and is_discovered:
		visuals.scale = visuals.scale.move_toward(Vector3.ZERO, delta * 3.0)
	elif visuals and is_missed:
		visuals.scale = visuals.scale.move_toward(Vector3.ZERO, delta * 2.5)

func attempt_interact(player_pos: Vector3 = Vector3.ZERO) -> bool:
	if not is_active or is_discovered or is_missed:
		return false
	mark_discovered()
	return true

func mark_discovered() -> void:
	if is_discovered or is_missed:
		return
	is_discovered = true
	is_active = false
	if landmark_data:
		landmark_data.discovered = true
	
	if prompt_label:
		prompt_label.text = "✓ DISCOVERED!"
		prompt_label.modulate = Color(1.0, 0.9, 0.3)
	
	target_discovered.emit(landmark_data)
	
	if is_inside_tree() and visuals:
		var tween = create_tween()
		tween.tween_property(visuals, "scale", Vector3(1.5, 1.5, 1.5), 0.15)
		tween.tween_property(visuals, "scale", Vector3.ZERO, 0.35)
		tween.tween_callback(queue_free)

func mark_missed() -> void:
	if is_discovered or is_missed:
		return
	is_missed = true
	is_active = false
	
	if prompt_label:
		prompt_label.text = "✗ MISSED!"
		prompt_label.modulate = Color(1.0, 0.25, 0.25)
	
	target_missed.emit(landmark_data)
	
	if is_inside_tree() and visuals:
		var tween = create_tween()
		tween.tween_property(visuals, "scale", Vector3.ZERO, 0.4)
		tween.tween_callback(queue_free)
