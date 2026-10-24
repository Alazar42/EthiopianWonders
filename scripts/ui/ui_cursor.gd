class_name UiCursor
extends RefCounted
## The mouse cursor: Kenney's arrow in menus and a crosshair while flying.

const ARROW: Texture2D = preload("res://assets/ui/kenney/cursors/arrow.png")
const CROSSHAIR: Texture2D = preload("res://assets/ui/kenney/cursors/crosshair.png")

static func set_arrow() -> void:
	Input.set_custom_mouse_cursor(ARROW, Input.CURSOR_ARROW, Vector2(4, 4))

static func set_crosshair() -> void:
	Input.set_custom_mouse_cursor(CROSSHAIR, Input.CURSOR_ARROW, CROSSHAIR.get_size() * 0.5)

static func clear() -> void:
	Input.set_custom_mouse_cursor(null)
