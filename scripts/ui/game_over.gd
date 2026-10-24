class_name GameOverScreen
extends Control
## The result card pops in, then each stat fades in and counts up to its final value in turn.

signal restart_requested
signal main_menu_requested

const COUNT_TIME: float = 0.7

@onready var _dim: Control = %Dim
@onready var _card: Control = %Card
@onready var _rows: Array[Array] = [
	[%WondersName, %WondersLabel], [%RocksName, %RocksLabel],
	[%DistanceName, %DistanceLabel], [%TimeName, %TimeLabel],
]
@onready var _restart_button: Button = %RestartButton
@onready var _main_menu_button: Button = %MainMenuButton

func _ready() -> void:
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())

## `stats` comes from DiscoveryManager.stats().
func show_game_over(stats: Dictionary) -> void:
	visible = true
	UiCursor.set_arrow()
	var finals: Array[int] = [stats["wonders"], stats["obstacles_destroyed"], int(stats["distance"]), int(stats["time"])]
	var formats: Array[Callable] = [
		Callable(), Callable(),
		func(v: int) -> String: return "%d m" % v,
		func(v: int) -> String: return "%02d:%02d" % [v / 60, v % 60],
	]
	UiMotion.fade_in(_dim, 0.0, 0.4)
	_restart_button.modulate.a = 0.0
	_main_menu_button.modulate.a = 0.0
	for row in _rows:
		(row[0] as Control).modulate.a = 0.0
		(row[1] as Control).modulate.a = 0.0
		(row[1] as Label).text = "0" if formats[_rows.find(row)].is_null() else formats[_rows.find(row)].call(0)
	await get_tree().process_frame
	UiMotion.pop_in(_card, 0.0, 0.45)
	for i in _rows.size():
		var delay: float = 0.4 + 0.18 * float(i)
		UiMotion.fade_in(_rows[i][0] as Control, delay, 0.25)
		UiMotion.fade_in(_rows[i][1] as Control, delay, 0.25)
		UiMotion.count_up(_rows[i][1] as Label, 0, finals[i], COUNT_TIME, formats[i], delay)
	var buttons_delay: float = 0.4 + 0.18 * float(_rows.size()) + 0.2
	UiMotion.fade_in(_restart_button, buttons_delay, 0.3)
	UiMotion.fade_in(_main_menu_button, buttons_delay + 0.1, 0.3)
	_restart_button.grab_focus()

func hide_screen() -> void:
	UiMotion.reset(_card)
	UiMotion.reset(_dim)
	visible = false
