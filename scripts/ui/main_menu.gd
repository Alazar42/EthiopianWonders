class_name MainMenu
extends Control
## Title screen, kept minimal: the title words pop in one after another, then the two buttons rise.

@export_file("*.tscn") var game_scene: String = "res://scenes/game/game_world.tscn"
@export var planet_spin_speed: float = 0.12

@onready var _play_button: Button = %PlayButton
@onready var _quit_button: Button = %QuitButton
@onready var _planet: Node3D = %MenuPlanet
@onready var _animation: AnimationPlayer = $AnimationPlayer
@onready var _title_items: Array[Control] = [%TitleTop, %TitleBottom]
@onready var _card: Control = %MenuCard

func _ready() -> void:
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(func() -> void: get_tree().quit())
	_quit_button.visible = not OS.has_feature("web")
	GameSound.start_music()
	UiCursor.set_arrow()
	# Containers sort over a couple of frames; animate once the buttons have their real places.
	await get_tree().process_frame
	await get_tree().process_frame
	_play_intro()
	_play_button.grab_focus()

func _process(delta: float) -> void:
	_planet.rotate_y(delta * planet_spin_speed)

func _play_intro() -> void:
	for i in _title_items.size():
		UiMotion.pop_in(_title_items[i], 0.25 + 0.14 * float(i), 0.5)
	UiMotion.slide_in(_card, Vector2(0, 90), 0.6, 0.55)

func _on_play_pressed() -> void:
	_play_button.disabled = true
	_animation.play(&"fade_out")
	await _animation.animation_finished
	get_tree().change_scene_to_file(game_scene)
