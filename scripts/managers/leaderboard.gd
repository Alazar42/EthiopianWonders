class_name Leaderboard
extends RefCounted
## The local high-score table: the ten best runs on this machine, saved as JSON in the user
## folder. A run only earns a place (and a name on the board) if its score beats the tenth best or
## the table still has room; everything else is forgotten.

const MAX_ENTRIES: int = 10
const NAME_LIMIT: int = 12
const DEFAULT_NAME: String = "PILOT"

var path: String
## Best first. Each entry: {"name": String, "score": int, "wonders": int, "distance": int}.
var entries: Array[Dictionary] = []
## The name used for the most recent saved run, so the game can greet the pilot.
var last_name: String = ""

func _init(p_path: String = "user://leaderboard.json") -> void:
	path = p_path
	load_from_disk()

## True when `score` would earn a place on the board.
func qualifies(score: int) -> bool:
	if score <= 0:
		return false
	return entries.size() < MAX_ENTRIES or score > int(entries[entries.size() - 1]["score"])

## The 1-based place `score` would take; ties rank below the runs already on the board.
## Returns 0 if it would not make the board.
func rank_for(score: int) -> int:
	if not qualifies(score):
		return 0
	var rank: int = 1
	for entry in entries:
		if int(entry["score"]) >= score:
			rank += 1
	return rank

## Adds a run and saves. Returns its place (1 to 10), or 0 if it did not make the board.
func add(player_name: String, score: int, wonders: int, distance: int) -> int:
	var rank: int = rank_for(score)
	if rank == 0:
		return 0
	entries.insert(rank - 1, {
		"name": clean_name(player_name), "score": score, "wonders": wonders, "distance": distance,
	})
	while entries.size() > MAX_ENTRIES:
		entries.pop_back()
	last_name = clean_name(player_name)
	save()
	return rank

## The best score on the board, or 0 when it is empty.
func best_score() -> int:
	return int(entries[0]["score"]) if not entries.is_empty() else 0

func clear() -> void:
	entries.clear()
	save()

## Trims the name, limits its length and falls back to a default when it is empty.
static func clean_name(raw: String) -> String:
	var cleaned: String = raw.strip_edges().replace("\n", " ").replace("\t", " ")
	if cleaned.length() > NAME_LIMIT:
		cleaned = cleaned.substr(0, NAME_LIMIT).strip_edges()
	return DEFAULT_NAME if cleaned.is_empty() else cleaned

## 12345 -> "12,345".
static func format_score(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			out += ","
		out += digits[i]
	return ("-" if value < 0 else "") + out

func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the leaderboard to %s" % path)
		return
	file.store_string(JSON.stringify({"version": 1, "last_name": last_name, "entries": entries}, "\t"))

func load_from_disk() -> void:
	entries.clear()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not (parsed as Dictionary).get("entries") is Array:
		return
	last_name = str((parsed as Dictionary).get("last_name", ""))
	for item in (parsed as Dictionary)["entries"]:
		if item is Dictionary and (item as Dictionary).has("score"):
			entries.append({
				"name": clean_name(str(item.get("name", ""))),
				"score": int(item["score"]),
				"wonders": int(item.get("wonders", 0)),
				"distance": int(item.get("distance", 0)),
			})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	if entries.size() > MAX_ENTRIES:
		entries.resize(MAX_ENTRIES)
