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

## The folder as the operating system sees it, for telling the player where to look.
static func folder_on_disk(folder: String = FOLDER) -> String:
	return ProjectSettings.globalize_path(folder)
