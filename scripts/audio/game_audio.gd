extends Node
## Autoload (scenes/audio/game_audio.tscn). Every sound is an AudioStreamPlayer child, played by
## name. Buttons anywhere in the game get hover and click sounds automatically.

const EFFECTS_BUS: StringName = &"Effects"
const MUSIC_BUS: StringName = &"Music"

## Random pitch spread so repeated sounds do not feel mechanical.
@export_range(0.0, 0.2) var pitch_variation: float = 0.05

@onready var _music: AudioStreamPlayer = $music
@onready var _engine: AudioStreamPlayer = $engine

func _ready() -> void:
	_loop(_music.stream)
	_loop(_engine.stream)
	get_tree().node_added.connect(_on_node_added)

func play(sound: StringName, pitch: float = 1.0) -> void:
	var player := get_node_or_null(NodePath(String(sound))) as AudioStreamPlayer
	if player == null:
		return
	player.pitch_scale = pitch * (1.0 + randf_range(-pitch_variation, pitch_variation))
	player.play()

func start_music() -> void:
	if not _music.playing:
		_music.play()

func set_engine(running: bool) -> void:
	if running and not _engine.playing:
		_engine.play()
	elif not running and _engine.playing:
		_engine.stop()

## Linear volume from 0 to 1 for the Music or Effects bus.
func set_bus_volume(bus: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.001)

func get_bus_volume(bus: StringName) -> float:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))

func _loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		var bytes_per_frame: int = (2 if wav.stereo else 1) * (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1)
		wav.loop_end = wav.data.size() / bytes_per_frame

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		button.mouse_entered.connect(func() -> void: play(&"ui_hover"))
		button.pressed.connect(func() -> void: play(&"ui_click"))
