class_name LeaderboardPanel
extends Control
## The top-ten table as an overlay card. Opened from the main menu and from the game-over card.

signal closed

@export var row_scene: PackedScene

@onready var _dim: Control = %Dim
@onready var _card: Control = %Card
@onready var _rows: VBoxContainer = %Rows
@onready var _hint: Label = %Hint
@onready var _close_button: Button = %CloseButton

func _ready() -> void:
	_close_button.pressed.connect(close)

func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()

## Shows the table. `highlight_rank` (1 to 10) marks the run that was just saved.
func show_board(board: Leaderboard, highlight_rank: int = 0) -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for i in Leaderboard.MAX_ENTRIES:
		var row := row_scene.instantiate() as LeaderboardRow
		_rows.add_child(row)
		var entry: Dictionary = board.entries[i] if i < board.entries.size() else {}
		row.set_entry(i + 1, entry, i + 1 == highlight_rank)
	_hint.text = "Scores are kept on this device only." if not board.entries.is_empty() \
		else "No scores yet - fly a mission to claim the first place!"
	visible = true
	UiCursor.set_arrow()
	UiMotion.fade_in(_dim, 0.0, 0.25)
	await get_tree().process_frame
	UiMotion.pop_in(_card, 0.0, 0.4)
	for i in _rows.get_child_count():
		UiMotion.fade_in(_rows.get_child(i) as Control, 0.2 + 0.04 * float(i), 0.25)
	_close_button.grab_focus()

func close() -> void:
	if not visible:
		return
	UiMotion.reset(_card)
	UiMotion.reset(_dim)
	visible = false
	closed.emit()
