class_name LeaderboardRow
extends HBoxContainer
## One line of the leaderboard: place, name and score. An empty place shows dashes.

const HIGHLIGHT: Color = Color(0.85, 0.12, 0.1)

@onready var _rank: Label = %RankLabel
@onready var _name: Label = %NameLabel
@onready var _score: Label = %ScoreLabel

## `entry` is empty for an unclaimed place.
func set_entry(rank: int, entry: Dictionary, highlight: bool = false) -> void:
	_rank.text = "%d." % rank
	if entry.is_empty():
		_name.text = "---"
		_score.text = ""
		for label in [_rank, _name, _score]:
			(label as Label).add_theme_color_override("font_color", Color(0.28, 0.17, 0.08, 0.4))
		return
	_name.text = str(entry["name"])
	_score.text = Leaderboard.format_score(int(entry["score"]))
	for label in [_rank, _name, _score]:
		(label as Label).add_theme_color_override("font_color", HIGHLIGHT if highlight else Color(0.28, 0.17, 0.08))
