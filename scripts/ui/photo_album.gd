class_name PhotoAlbum
extends Control
## The album of pictures taken in open world: a grid of thumbnails, and a viewer for one picture
## at a time with next, previous and delete. Opened from the main menu and from the pause menu.

signal closed

const THUMB_SIZE: Vector2i = Vector2i(176, 99)

## Where the pictures live.
@export var folder: String = PhotoStore.FOLDER

@onready var _dim: Control = %Dim
@onready var _card: Control = %Card
@onready var _grid_scroll: ScrollContainer = %GridScroll
@onready var _grid: GridContainer = %Grid
@onready var _viewer: Control = %Viewer
@onready var _picture: TextureRect = %Picture
@onready var _caption: Label = %Caption
@onready var _empty_label: Label = %EmptyLabel
@onready var _hint: Label = %Hint
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _delete_button: Button = %DeleteButton
@onready var _grid_button: Button = %GridButton
@onready var _folder_button: Button = %FolderButton
@onready var _close_button: Button = %CloseButton

var photos: PackedStringArray = PackedStringArray()
## Index of the picture being viewed, or -1 while the grid is showing.
var index: int = -1

func _ready() -> void:
	_prev_button.pressed.connect(func() -> void: step(-1))
	_next_button.pressed.connect(func() -> void: step(1))
	_delete_button.pressed.connect(delete_current)
	_grid_button.pressed.connect(show_grid)
	_folder_button.pressed.connect(func() -> void: PhotoStore.open_folder(folder))
	_close_button.pressed.connect(close)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause_game") or event.is_action_pressed("ui_cancel"):
		# Escape backs out of a picture first, then out of the album.
		if index >= 0:
			show_grid()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif index >= 0 and event.is_action_pressed("ui_left"):
		step(-1)
		get_viewport().set_input_as_handled()
	elif index >= 0 and event.is_action_pressed("ui_right"):
		step(1)
		get_viewport().set_input_as_handled()

## Opens the album on its grid, newest pictures first.
func show_album() -> void:
	reload()
	visible = true
	UiCursor.set_arrow()
	UiMotion.fade_in(_dim, 0.0, 0.25)
	await get_tree().process_frame
	UiMotion.pop_in(_card, 0.0, 0.4)
	_close_button.grab_focus()

func close() -> void:
	if not visible:
		return
	UiMotion.reset(_card)
	UiMotion.reset(_dim)
	visible = false
	closed.emit()

## Reads the folder again and shows the grid.
func reload() -> void:
	photos = PhotoStore.list_newest(folder)
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for i in photos.size():
		_grid.add_child(_make_thumbnail(i))
	_empty_label.visible = photos.is_empty()
	_hint.text = "%d picture%s   |   %s" % [photos.size(), "" if photos.size() == 1 else "s", PhotoStore.folder_on_disk(folder)]
	show_grid()

func show_grid() -> void:
	index = -1
	_viewer.visible = false
	_grid_scroll.visible = not photos.is_empty()
	_empty_label.visible = photos.is_empty()

## Shows picture number `i` large.
func open_photo(i: int) -> void:
	if photos.is_empty():
		return
	index = posmod(i, photos.size())
	var image := Image.load_from_file(photos[index])
	_picture.texture = ImageTexture.create_from_image(image) if image != null else null
	_caption.text = "%s   (%d of %d)" % [PhotoStore.describe(photos[index]), index + 1, photos.size()]
	_grid_scroll.visible = false
	_empty_label.visible = false
	_viewer.visible = true
	_prev_button.disabled = photos.size() < 2
	_next_button.disabled = photos.size() < 2
	_next_button.grab_focus()

## Moves to the next (+1) or previous (-1) picture, wrapping around.
func step(direction: int) -> void:
	if index >= 0:
		open_photo(index + direction)

## Deletes the picture on screen and returns to the grid.
func delete_current() -> void:
	if index < 0 or index >= photos.size():
		return
	DirAccess.remove_absolute(photos[index])
	reload()

func _make_thumbnail(i: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(THUMB_SIZE.x + 12, THUMB_SIZE.y + 12)
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.tooltip_text = PhotoStore.describe(photos[i])
	var image := Image.load_from_file(photos[i])
	if image != null:
		image.resize(THUMB_SIZE.x, THUMB_SIZE.y, Image.INTERPOLATE_BILINEAR)
		button.icon = ImageTexture.create_from_image(image)
	button.pressed.connect(open_photo.bind(i))
	return button
