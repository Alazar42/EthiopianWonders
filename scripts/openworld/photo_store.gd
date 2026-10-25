class_name PhotoStore
extends RefCounted
## Saves the pictures the pilot takes. They are ordinary PNG files in the game's user folder
## (on Windows: %APPDATA%\Godot\app_userdata\<project name>\photos).

const FOLDER: String = "user://photos"

## Writes `image` and returns its path, or an empty string when it could not be saved.
static func save(image: Image, subject: String, folder: String = FOLDER) -> String:
	if image == null or image.is_empty():
		return ""
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return ""
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path: String = folder.path_join("%s_%s_%d.png" % [slug(subject), stamp, Time.get_ticks_msec() % 100000])
	return path if image.save_png(path) == OK else ""

static func slug(text: String) -> String:
	var result: String = text.to_lower().strip_edges().replace(" ", "_")
	for bad in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "."]:
		result = result.replace(bad, "")
	return result if not result.is_empty() else "artifact"

static func list_photos(folder: String = FOLDER) -> PackedStringArray:
	var paths := PackedStringArray()
	if not DirAccess.dir_exists_absolute(folder):
		return paths
	for file in DirAccess.get_files_at(folder):
		if file.get_extension().to_lower() == "png":
			paths.append(folder.path_join(file))
	paths.sort()
	return paths

## Every picture, the most recently taken first.
static func list_newest(folder: String = FOLDER) -> PackedStringArray:
	var paths: Array = Array(list_photos(folder))
	paths.sort_custom(func(a: String, b: String) -> bool:
		var time_a: int = FileAccess.get_modified_time(a)
		var time_b: int = FileAccess.get_modified_time(b)
		return time_a > time_b if time_a != time_b else a > b)
	return PackedStringArray(paths)

## "axum_2026-10-25_13-00-05_13600.png" -> "Axum  -  2026-10-25 13:00".
static func describe(path: String) -> String:
	var regex := RegEx.new()
	regex.compile("^(.*)_(\\d{4}-\\d{2}-\\d{2})_(\\d{2})-(\\d{2})-\\d{2}_\\d+$")
	var found: RegExMatch = regex.search(path.get_file().get_basename())
	if found == null:
		return path.get_file().get_basename().replace("_", " ").capitalize()
	return "%s  -  %s %s:%s" % [found.get_string(1).replace("_", " ").capitalize(), found.get_string(2), found.get_string(3), found.get_string(4)]

## Opens the folder in the system's file browser.
static func open_folder(folder: String = FOLDER) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	OS.shell_open(folder_on_disk(folder))

## The folder as the operating system sees it, for telling the player where to look.
static func folder_on_disk(folder: String = FOLDER) -> String:
	return ProjectSettings.globalize_path(folder)
