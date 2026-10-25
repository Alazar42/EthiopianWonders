class_name GameOverScreen
extends Control
## The result card pops in, then each stat fades in and counts up to its final value in turn. A
## score that makes the local top ten asks for a name; anything else is shown with what it would
## have taken to get on the board.

signal restart_requested
signal main_menu_requested
## Emitted with the place (1 to 10) a saved score took.
signal score_saved(rank: int)

const COUNT_TIME: float = 0.7

@onready var _dim: Control = %Dim
@onready var _header: Label = %Header
@onready var _card: Control = %Card
@onready var _rows: Array[Array] = [
	[%ScoreName, %ScoreLabel], [%WondersName, %WondersLabel], [%RocksName, %RocksLabel],
	[%DistanceName, %DistanceLabel], [%TimeName, %TimeLabel],
]
@onready var _name_entry: Control = %NameEntry
@onready var _rank_label: Label = %RankLabel
@onready var _name_field: LineEdit = %NameField
@onready var _save_button: Button = %SaveButton
@onready var _status_label: Label = %StatusLabel
@onready var _restart_button: Button = %RestartButton
@onready var _scores_button: Button = %ScoresButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _board_panel: LeaderboardPanel = %LeaderboardPanel

var _board: Leaderboard
var _stats: Dictionary = {}
var _saved: bool = false

func _ready() -> void:
	_restart_button.pressed.connect(func() -> void: restart_requested.emit())
	_main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	_save_button.pressed.connect(save_score)
	_name_field.text_submitted.connect(func(_text: String) -> void: save_score())
	_scores_button.pressed.connect(func() -> void: _board_panel.show_board(_board))
	_board_panel.closed.connect(func() -> void:
		UiCursor.set_arrow()
		_scores_button.grab_focus())

## `stats` comes from DiscoveryManager.stats(); `board` is the local leaderboard.
func show_game_over(stats: Dictionary, board: Leaderboard = null) -> void:
	_stats = stats
	_board = board
	_saved = false
	_header.text = "OUT OF FUEL" if stats.get("reason", "") == "fuel" else "MISSION OVER"
	visible = true
	UiCursor.set_arrow()
	var score: int = int(stats.get("score", 0))
	var finals: Array[int] = [score, stats["wonders"], stats["obstacles_destroyed"], int(stats["distance"]), int(stats["time"])]
	var formats: Array[Callable] = [
		func(v: int) -> String: return Leaderboard.format_score(v), Callable(), Callable(),
		func(v: int) -> String: return "%d m" % v,
		func(v: int) -> String: return "%02d:%02d" % [v / 60, v % 60],
	]
	_scores_button.visible = board != null
	var qualifies: bool = board != null and board.qualifies(score)
	_name_entry.visible = false
	_status_label.visible = false
	UiMotion.fade_in(_dim, 0.0, 0.4)
	_restart_button.modulate.a = 0.0
	_main_menu_button.modulate.a = 0.0
	_scores_button.modulate.a = 0.0
	for i in _rows.size():
		(_rows[i][0] as Control).modulate.a = 0.0
		(_rows[i][1] as Control).modulate.a = 0.0
		(_rows[i][1] as Label).text = "0" if formats[i].is_null() else formats[i].call(0)
	await get_tree().process_frame
	UiMotion.pop_in(_card, 0.0, 0.45)
	for i in _rows.size():
		var delay: float = 0.4 + 0.18 * float(i)
		UiMotion.fade_in(_rows[i][0] as Control, delay, 0.25)
		UiMotion.fade_in(_rows[i][1] as Control, delay, 0.25)
		UiMotion.count_up(_rows[i][1] as Label, 0, finals[i], COUNT_TIME, formats[i], delay)
	var after_rows: float = 0.4 + 0.18 * float(_rows.size()) + COUNT_TIME * 0.5
	var buttons_delay: float = after_rows + 0.2
	UiMotion.fade_in(_restart_button, buttons_delay, 0.3)
	UiMotion.fade_in(_scores_button, buttons_delay + 0.1, 0.3)
	UiMotion.fade_in(_main_menu_button, buttons_delay + 0.2, 0.3)
	if qualifies:
		_rank_label.text = "NEW HIGH SCORE  -  PLACE #%d" % board.rank_for(score)
		_name_field.text = board.last_name
		_name_field.editable = true
		_save_button.disabled = false
		UiMotion.fade_in(_name_entry, after_rows, 0.35)
		# Typing starts straight away once the entry has appeared.
		get_tree().create_timer(after_rows).timeout.connect(func() -> void:
			if visible and not _saved:
				_name_field.grab_focus())
	elif board != null and score > 0:
		_status_label.text = _missed_board_text(board, score)
		UiMotion.fade_in(_status_label, after_rows, 0.35)
		_restart_button.grab_focus()
	else:
		_restart_button.grab_focus()

## Writes the score to the leaderboard under the typed name. Returns the place it took (0 if none).
func save_score() -> int:
	if _saved or _board == null or not _name_entry.visible:
		return 0
	var rank: int = _board.add(_name_field.text, int(_stats.get("score", 0)), int(_stats.get("wonders", 0)), int(_stats.get("distance", 0)))
	_saved = true
	_name_entry.visible = false
	_status_label.text = "Saved as #%d on the leaderboard." % rank
	UiMotion.fade_in(_status_label, 0.0, 0.3)
	score_saved.emit(rank)
	_board_panel.show_board(_board, rank)
	return rank

func _missed_board_text(board: Leaderboard, score: int) -> String:
	if board.entries.size() < Leaderboard.MAX_ENTRIES:
		return "Score %s" % Leaderboard.format_score(score)
	var tenth: int = int(board.entries[board.entries.size() - 1]["score"])
	return "Not in the top 10 this time - beat %s to get a place." % Leaderboard.format_score(tenth)

func hide_screen() -> void:
	UiMotion.reset(_card)
	UiMotion.reset(_dim)
	_board_panel.visible = false
	visible = false
