class_name GameSound
extends RefCounted
## Static front door to the GameAudio autoload. Game scripts call these instead of naming the
## autoload, so they compile and run even where the autoload is not registered yet (tests, tools),
## and sounds are silently skipped when it is missing.

const MUSIC_BUS: StringName = &"Music"
const EFFECTS_BUS: StringName = &"Effects"

static func _audio() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameAudio")

static func play(sound: StringName, pitch: float = 1.0) -> void:
	var audio: Node = _audio()
	if audio:
		audio.play(sound, pitch)

static func start_music() -> void:
	var audio: Node = _audio()
	if audio:
		audio.start_music()

static func set_engine(running: bool) -> void:
	var audio: Node = _audio()
	if audio:
		audio.set_engine(running)

static func set_bus_volume(bus: StringName, linear: float) -> void:
	var audio: Node = _audio()
	if audio:
		audio.set_bus_volume(bus, linear)

static func get_bus_volume(bus: StringName) -> float:
	var audio: Node = _audio()
	return audio.get_bus_volume(bus) if audio else 1.0
