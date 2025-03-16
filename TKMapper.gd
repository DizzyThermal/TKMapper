extends Node2D

# Parameters
var display_resolution := Vector2i(1400, 900)
var tile_page_size := 160
var object_page_size := 38

# State Variables
var map_id := 0
var map_renderer: NTK_MapRenderer = null

var cursor_renderer: NTK_CursorRenderer = null
var cursor_state := "Idle"

var cursor_tile := Sprite2D.new()
var cursor_rect := Rect2(Vector2i.ZERO, Resources.tile_size_vector)
var cursor_inner_rect := Rect2(Vector2i(0.1, 0.1), Vector2i(0.8, 0.8))
var map_regex: RegEx = RegEx.new()

var current_tile_index := 0
var current_object_index := 0
var hover_tile_index := 0
var hover_object_index := 0
var max_tile_pages := 0		# Evaluated to: tile_page_size / tile_count (in TileRender tbl)
var max_object_pages := 0	# Evaluated to: object_page_size / object_count (in SObjRenderer sobj)
var current_tile_page := 0
var current_object_page := 0
var mouse_on_tilemap := true
var menu_open := false
var over_title_bar := false
var objects_hidden := false
var is_erase_mode := false

enum MapMode {
	TILE = 0,
	OBJECT = 1,
	UNPASSABLE = 2,
}
var mode := MapMode.TILE

var camera_min_zoom := 0.5
var camera_max_zoom := 1.5

var undo_stack := []

# Map State
var map_tiles := []
var map_objects := {}
var map_unpassables := {}

# Scene Nodes
@onready var tile_map := $TileMap
@onready var objects := $Objects
@onready var unpassables := $Unpassables
@onready var target_box := $TargetBox
@onready var title_bar := $CanvasLayer/Title
@onready var tile_selection_area := $CanvasLayer/TileSelectionBackground
@onready var object_selection_area := $CanvasLayer/ObjectSelectionBackground
@onready var tile_set_container := $CanvasLayer/TileSelectionBackground/ScrollContainer/Container
@onready var object_set_container := $CanvasLayer/ObjectSelectionBackground/ScrollContainer/HBoxContainer
@onready var file_dialog := $CanvasLayer/Title/FileDialog
@onready var tile_mode_button := $CanvasLayer/Title/TileMode
@onready var object_mode_button := $CanvasLayer/Title/ObjectMode
@onready var unpassable_mode_button := $CanvasLayer/Title/UnpassableMode
@onready var undo_button := $CanvasLayer/Title/Undo
@onready var hide_objects_button := $CanvasLayer/Title/HideObjects
@onready var info_label := $CanvasLayer/Title/InfoLabel
@onready var status_label := $CanvasLayer/StatusBar/StatusLabel
@onready var next_button := $CanvasLayer/StatusBar/NextTile
@onready var prev_button := $CanvasLayer/StatusBar/PreviousTile

func _ready():
	DisplayServer.window_set_size(display_resolution)

	cursor_renderer = NTK_CursorRenderer.new()
	file_dialog.access = FileDialog.Access.ACCESS_FILESYSTEM
	file_dialog.current_dir = Resources.map_dir
	file_dialog.add_filter("*.cmp", "Map Files")

	map_regex.compile("TK(\\d+).cmp")

	# Camera Limits
	$Camera2D.limit_left = 0
	$Camera2D.limit_top = -480

	# Load Map
	map_id = Resources.start_map_id
	load_map(map_id)

	# Create Cursor Tile
	var tile_index: int = map_tiles[0][0]["ab_index"]
	var palette_index := map_renderer.tile_renderer.tbl.palette_indices[tile_index]
	cursor_tile.texture = ImageTexture.create_from_image(map_renderer.tile_renderer.render_frame(tile_index, palette_index), )
	cursor_tile.z_index = 2
	cursor_tile.centered = false
	add_child(cursor_tile)
	set_target_box_color(Color.GREEN)

	# TileSet
	var max_tile_count = map_renderer.tile_renderer.tbl.tile_count
	var max_object_count = map_renderer.sobj_renderer.sobj.object_count
	max_tile_pages = ceil(max_tile_count / tile_page_size)
	max_object_pages = ceil(max_object_count / object_page_size) 
	status_label.text = "Page " + str(current_tile_page + 1) + "/" + str(max_tile_pages + 1)
	tile_selection_area.connect("mouse_entered", func(): self.mouse_on_tilemap = false)
	tile_selection_area.connect("mouse_exited", func(): self.mouse_on_tilemap = true)
	object_selection_area.connect("mouse_entered", func(): self.mouse_on_tilemap = false)
	object_selection_area.connect("mouse_exited", func(): self.mouse_on_tilemap = true)
	change_to_tile_mode()

	# Connect Signals
	title_bar.connect("mouse_entered", func(): self.over_title_bar = true)
	title_bar.connect("mouse_exited", func(): self.over_title_bar = false)

func _process(delta):
	# Load / Save Map
	if Input.is_action_just_pressed("load-map") and not menu_open:
		_load_map()
	elif Input.is_action_just_pressed("save-map") and not menu_open:
		_save_map()

	# Toggle Insert / Erase Modes
	if Input.is_action_just_pressed("erase-mode") and not menu_open:
		is_erase_mode = true
	elif Input.is_action_just_pressed("insert-mode") and not menu_open:
		is_erase_mode = false

	# Mode Switches
	if Input.is_action_just_pressed("toggle-mode") and not menu_open:
		change_map_mode()			# M
	elif Input.is_action_just_pressed("mode-tile") and not menu_open:
		change_to_tile_mode()		# T
	elif Input.is_action_just_pressed("mode-object") and not menu_open:
		change_to_object_mode()		# O
	elif Input.is_action_just_pressed("mode-unpassable") and not menu_open:
		change_to_unpassable_mode()	# U

	# Page Switching
	if Input.is_action_just_pressed("next-page") and not menu_open:
		_next_page()
	elif Input.is_action_just_pressed("previous-page") and not menu_open:
		_prev_page()
	elif Input.is_action_just_pressed("toggle-selection-area") and not menu_open:
		_toggle_selection_area()

	# Cursor
	var grabbing_map := false
	if Input.is_key_pressed(KEY_CTRL) or Input.is_action_pressed("move-map"):
		cursor_state = "Grab"
		grabbing_map = true
		cursor_tile.visible = false
		target_box.visible = false
	elif is_erase_mode:
		set_target_box_color(Color.RED)
		cursor_tile.visible = false
		target_box.visible = true
		cursor_state = "Attack"
	elif mode == MapMode.UNPASSABLE:
		cursor_tile.visible = true
		target_box.visible = false
		cursor_state = "Idle"
	else:
		set_target_box_color(Color.GREEN)
		cursor_tile.visible = true
		target_box.visible = true
		cursor_state = "Idle"

	# Update Cursor
	if cursor_state in cursor_renderer.cursors:
		Input.set_custom_mouse_cursor(cursor_renderer.cursors[cursor_state].get_frame_texture(cursor_renderer.cursors[cursor_state].current_frame), Input.CURSOR_ARROW, Vector2(0, 0))

	# Toggle Objects
	if Input.is_action_just_pressed("toggle-objects") \
			and not menu_open:
		_toggle_hide_objects()

	# Undo Tile
	if Input.is_action_just_pressed("undo") \
			and not menu_open:
		undo()

	var mouse_position := get_global_mouse_position()
	var mouse_coordinate := Vector2i(get_global_mouse_position()) / Resources.tile_size_vector
	var snapped_mouse_position := (Vector2i(get_global_mouse_position()) - (Resources.tile_size_vector / 2)).snapped(Resources.tile_size_vector)
	# Change Tile on Left Mouse Button (LMB) - Default Mode
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and \
			not Input.is_action_pressed("move-map") and \
			not is_erase_mode and \
			mouse_on_tilemap and \
			not menu_open and \
			not over_title_bar:
		if mouse_coordinate.x >= 0 and mouse_coordinate.y >= 0 and not over_title_bar and mouse_on_tilemap:
			if mode == MapMode.TILE:
				if current_tile_index not in map_renderer.ntk_tileset_source.tile_atlas_position_by_tile_index:
					map_renderer.add_tile_to_tile_set_source(self, mouse_coordinate, current_tile_index)

				var previous_tile_index = map_tiles[mouse_coordinate.y][mouse_coordinate.x]["ab_index"]
				if previous_tile_index != current_tile_index:
					undo_stack.insert(0, {
						"mouse_coordinate": mouse_coordinate,
						"previous_index": previous_tile_index,
						"new_index": current_tile_index,
						"type": MapMode.TILE,
					})
					undo_button.disabled = false
				tile_map.set_cell(0, mouse_coordinate, current_tile_index, Vector2i(0, 0))
				undo_button.disabled = false
				map_tiles[mouse_coordinate.y][mouse_coordinate.x]["ab_index"] = current_tile_index
			elif mode == MapMode.OBJECT:
				var previous_object_index = map_tiles[mouse_coordinate.y][mouse_coordinate.x]["sobj_index"]
				if previous_object_index != current_object_index:
					undo_stack.insert(0, {
						"mouse_coordinate": mouse_coordinate,
						"previous_index": previous_object_index,
						"new_index": current_object_index,
						"type": MapMode.OBJECT,
					})
					undo_button.disabled = false
				if mouse_coordinate in map_objects and \
						map_objects[mouse_coordinate] != null:
					map_objects[mouse_coordinate].queue_free()
					map_objects[mouse_coordinate] = null
				map_tiles[mouse_coordinate.y][mouse_coordinate.x]["sobj_index"] = current_object_index
				map_renderer.create_object(self, current_object_index, mouse_coordinate)
				map_objects[mouse_coordinate] = objects.get_child(objects.get_child_count() - 1)
			elif mode == MapMode.UNPASSABLE:
				var unpassable = map_tiles[mouse_coordinate.y][mouse_coordinate.x]["unpassable"]
				if not unpassable:
					undo_stack.insert(0, {
						"mouse_coordinate": mouse_coordinate,
						"visible": true,
						"type": MapMode.UNPASSABLE,
					})
					undo_button.disabled = false
				if mouse_coordinate in map_unpassables and \
						map_unpassables[mouse_coordinate] != null:
					map_unpassables[mouse_coordinate].queue_free()
					map_unpassables[mouse_coordinate] = null
				map_tiles[mouse_coordinate.y][mouse_coordinate.x]["unpassable"] = true
				var unpassable_sprite := Sprite2D.new()
				unpassable_sprite.texture = load("res://Images/placeholder-red.svg")
				unpassable_sprite.centered = false
				unpassable_sprite.position = mouse_coordinate * Resources.tile_size_vector
				unpassables.add_child(unpassable_sprite)
				map_unpassables[mouse_coordinate] = unpassable_sprite
	# Erase Tile on Left Mouse Button (LMB) - Eraser Mode
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and \
			not Input.is_action_pressed("move-map") and \
			is_erase_mode and \
			not menu_open and \
			not over_title_bar and \
			mouse_coordinate.x >= 0 and \
			mouse_coordinate.y >= 0:
			if mode == MapMode.TILE:
				var previous_tile_index = map_tiles[mouse_coordinate.y][mouse_coordinate.x]["ab_index"]
				if previous_tile_index != -1:
					undo_stack.insert(0, {
						"mouse_coordinate": mouse_coordinate,
						"previous_index": previous_tile_index,
						"new_index": -1,
						"type": MapMode.TILE,
					})
					undo_button.disabled = false
				tile_map.set_cell(0, mouse_coordinate)
				map_tiles[mouse_coordinate.y][mouse_coordinate.x]["ab_index"] = -1
			elif mode == MapMode.OBJECT:
				if mouse_coordinate in map_objects and \
						map_objects[mouse_coordinate] != null:
					map_objects[mouse_coordinate].queue_free()
					map_objects[mouse_coordinate] = null
					undo_stack.insert(0, {
						"mouse_coordinate": mouse_coordinate,
						"previous_index": map_tiles[mouse_coordinate.y][mouse_coordinate.x]["sobj_index"],
						"new_index": -1,
						"type": MapMode.OBJECT,
					})
					undo_button.disabled = false
				map_tiles[mouse_coordinate.y][mouse_coordinate.x]["sobj_index"] = -1
			elif mode == MapMode.UNPASSABLE:
				if mouse_coordinate in map_unpassables and \
						map_unpassables[mouse_coordinate] != null:
					map_unpassables[mouse_coordinate].queue_free()
					map_unpassables[mouse_coordinate] = null
					undo_stack.insert(0, {
						"mouse_coordinate": mouse_coordinate,
						"visible": false,
						"type": MapMode.UNPASSABLE,
					})
					undo_button.disabled = false
				map_tiles[mouse_coordinate.y][mouse_coordinate.x]["unpassable"] = false
	# Copy Tile on Right Mouse Button (RMB) - Default Mode
	if Input.is_action_just_pressed("copy-tile") and \
			cursor_state == "Idle" and \
			not menu_open and \
			not over_title_bar:
		var cursor_tile_coord := get_global_mouse_position()
		cursor_tile_coord.x = floor(cursor_tile_coord.x / Resources.tile_size)
		cursor_tile_coord.y = floor(cursor_tile_coord.y / Resources.tile_size)
		if cursor_tile_coord.x >= 0 and cursor_tile_coord.y >= 0:
			var index: int = map_tiles[cursor_tile_coord.y][cursor_tile_coord.x]["ab_index"]
			if mode == MapMode.OBJECT:
				index = map_tiles[cursor_tile_coord.y][cursor_tile_coord.x]["sobj_index"]
			update_cursor_preview(index)
			# Seek to Page
			if mode == MapMode.TILE:
				var previous_tile_page = current_tile_page
				current_tile_page = current_tile_index / tile_page_size
				if previous_tile_page != current_tile_page:
					load_tileset(current_tile_page * tile_page_size)
			elif mode == MapMode.OBJECT:
				var previous_object_page = current_object_page
				current_object_page = current_object_index / object_page_size
				if previous_object_page != current_object_page:
					load_objectset(current_object_page * object_page_size)

	# Tile Preview
	if mouse_coordinate.x >= 0 and \
			mouse_coordinate.y >= 0 and \
			mouse_position.y >= 4 and \
			mouse_on_tilemap and \
			not grabbing_map and \
			not menu_open and \
			not over_title_bar:
		var adjusted_height := Vector2i(0, 0)
		if mode == MapMode.OBJECT:
			var object_height: int = map_renderer.sobj_renderer.sobj.objects[current_object_index].height
			adjusted_height.y = Resources.tile_size * (object_height - 1)
		cursor_tile.position = snapped_mouse_position - adjusted_height
		target_box.position = snapped_mouse_position
		if not is_erase_mode:
			cursor_tile.visible = true
		if mode != MapMode.UNPASSABLE:
			target_box.visible = true
	else:
		cursor_tile.visible = false
		target_box.visible = false
	
	if Input.is_action_just_pressed("zoom-in") and \
			not Input.is_key_pressed(KEY_CTRL) and \
			mouse_on_tilemap and \
			not menu_open:
		if $Camera2D.zoom.x <= camera_max_zoom:
			$Camera2D.zoom.x *= 1.5
		if $Camera2D.zoom.y <= camera_max_zoom:
			$Camera2D.zoom.y *= 1.5
	if Input.is_action_just_pressed("zoom-out") and \
			not Input.is_key_pressed(KEY_CTRL) and \
			mouse_on_tilemap and \
			not menu_open:
		if $Camera2D.zoom.x >= camera_min_zoom:
			$Camera2D.zoom.x /= 1.5
		if $Camera2D.zoom.y >= camera_min_zoom:
			$Camera2D.zoom.y /= 1.5

	if mouse_on_tilemap and not over_title_bar and not menu_open:
		var info_tile_index = tile_map.get_cell_source_id(0, mouse_coordinate)
		info_label.text = "(" + str(mouse_coordinate.x) + ", " + str(mouse_coordinate.y) + ")"
	elif not mouse_on_tilemap and not over_title_bar and not menu_open:
		if mode == MapMode.TILE:
			info_label.text = "Tile Index: " + str(self.hover_tile_index)
		elif mode == MapMode.OBJECT:
			info_label.text = "Object Index: " + str(self.hover_object_index)

func _input(event):
	if event is InputEventMouseButton:
		if not mouse_on_tilemap:
			if mode == MapMode.TILE:
				update_cursor_preview(self.hover_tile_index)
			elif mode == MapMode.OBJECT:
				update_cursor_preview(self.hover_object_index)

func set_target_box_color(color: Color) -> void:
	$TargetBox/Top.color = color
	$TargetBox/Right.color = color
	$TargetBox/Bottom.color = color
	$TargetBox/Left.color = color

func load_map(map_id) -> void:
	if map_renderer == null:
		map_renderer = NTK_MapRenderer.new()

	clear_map()
	map_renderer.render_map(self, map_id, true)
	map_tiles.clear()
	for y in range(256):
		map_tiles.append([])
		for x in range(256):
			map_tiles[y].append({
				"ab_index": 0,
				"sobj_index": -1,
				"unpassable": false,
			})
	map_tiles = map_renderer.get_map_tile_indices(map_id, map_tiles)
	if current_tile_index == 0:
		current_tile_index = map_tiles[0][0]["ab_index"]
	# Add Objects to map_objects dictionary (by coordinate Vector2i)
	for object in objects.get_children():
		var object_coordinate := Vector2i(object.position) / Resources.tile_size_vector
		object_coordinate.y -= 1
		map_objects[object_coordinate] = object
	# Load Unpassable Tiles in
	for i in range(len(map_renderer.cmp.tiles)):
		var tile := map_renderer.cmp.tiles[i]
		var x := i % map_renderer.cmp.width
		var y := i / map_renderer.cmp.width
		if tile.unpassable_tile:
			map_tiles[y][x]["unpassable"] = true
			var unpassable_sprite := Sprite2D.new()
			unpassable_sprite.texture = load("res://Images/placeholder-red.svg")
			unpassable_sprite.centered = false
			unpassable_sprite.position = Vector2i(x, y) * Resources.tile_size_vector
			unpassables.add_child(unpassable_sprite)
			map_unpassables[Vector2i(x, y)] = unpassable_sprite
	undo_stack.clear()
	undo_button.disabled = true
	
	$Camera2D.position = Vector2(-1000, 400)
	change_to_tile_mode()

func update_cursor_preview(index: int) -> void:
	if index >= 0:
		if mode == MapMode.TILE:
			current_tile_index = index
			var palette_index := map_renderer.tile_renderer.tbl.palette_indices[current_tile_index]
			cursor_tile.texture = ImageTexture.create_from_image(map_renderer.tile_renderer.render_frame(current_tile_index, palette_index))
		elif mode == MapMode.OBJECT:
			current_object_index = index
			cursor_tile.texture = map_renderer.sobj_renderer.render_object(current_object_index)
		elif mode == MapMode.UNPASSABLE:
			cursor_tile.texture = load("res://Images/placeholder-red.svg")

func clear_container(container: Container) -> void:
	for item in container.get_children():
		if item != null:
			item.queue_free()
			item = null

func load_tileset(start_tile: int=0, tile_count: int=tile_page_size) -> void:
	tile_selection_area.visible = true
	object_selection_area.visible = false
	next_button.visible = true
	prev_button.visible = true
	clear_container(tile_set_container)
	start_tile = max(1, start_tile) # Skip tile[0] (blank)
	var end_tile = min(start_tile + tile_count + 1, map_renderer.tile_renderer.tbl.tile_count)
	for i in range(max(1, start_tile), end_tile):
		var tile := TextureRect.new()
		var palette_index := map_renderer.tile_renderer.tbl.palette_indices[i]
		tile.texture = ImageTexture.create_from_image(map_renderer.tile_renderer.render_frame(i, palette_index))
		tile.connect("mouse_entered", func(): self.hover_tile_index = i)
		tile_set_container.add_child(tile)
	status_label.text = "Tile Page " + str(current_tile_page + 1) + "/" + str(max_tile_pages + 1)

func load_objectset(start_object: int=0, object_count: int=object_page_size) -> void:
	object_selection_area.visible = true
	tile_selection_area.visible = false
	next_button.visible = true
	prev_button.visible = true
	clear_container(object_set_container)
	var end_object = min(start_object + object_count + 1, map_renderer.sobj_renderer.sobj.object_count)
	for i in range(start_object, end_object - 1):
		var object_texture := TextureRect.new()
		var palette_index := map_renderer.tile_renderer.tbl.palette_indices[i]
		object_texture.texture = map_renderer.sobj_renderer.render_object(i)
		object_texture.connect("mouse_entered", func(): self.hover_object_index = i)
		object_texture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		object_texture.anchor_bottom = 1
		object_texture.size_flags_vertical = Control.SIZE_SHRINK_END
		object_texture.grow_vertical = Control.GROW_DIRECTION_BEGIN
		object_set_container.add_child(object_texture)
	status_label.text = "Object Page " + str(current_object_page + 1) + "/" + str(max_object_pages + 1)

func update_file_dialog_path() -> void:
	var map_file_name := ("TK%06d.cmp" % map_id)
	if FileAccess.file_exists(Resources.map_dir + "/" + map_file_name):
		file_dialog.access = FileDialog.Access.ACCESS_FILESYSTEM
		file_dialog.current_dir = Resources.map_dir
	elif FileAccess.file_exists(Resources.local_map_dir + "/" + map_file_name):
		file_dialog.access = FileDialog.Access.ACCESS_RESOURCES
		file_dialog.current_dir = Resources.local_map_dir

func _load_map():
	# Select Map to Load
	update_file_dialog_path()
	file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE
	menu_open = true
	file_dialog.popup_centered_ratio(0.6)

func _on_load_map_pressed():
	_load_map()

func _save_map():
	# Select Map to Save
	update_file_dialog_path()
	file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_SAVE_FILE
	menu_open = true
	file_dialog.popup_centered_ratio(0.6)

func _on_save_map_pressed():
	_save_map()

func clear_map() -> void:
	for object in objects.get_children():
		if object != null:
			object.queue_free()
			object = null
	for unpassable in unpassables.get_children():
		if unpassable != null:
			unpassable.queue_free()
			unpassable = null
	map_renderer.cmp = null

func _on_file_dialog_file_selected(path):
	if file_dialog.file_mode == FileDialog.FileMode.FILE_MODE_OPEN_FILE:
		# Load Map from Path
		var result = map_regex.search(path)
		if result:
			load_map(int(result.get_string(1)))
	elif file_dialog.file_mode == FileDialog.FileMode.FILE_MODE_SAVE_FILE:
		# Save - Update Cmp
		var max_width := 0
		var max_height := 0
		var row_counter := 0
		for row in map_tiles:
			var empty_row := true
			var tile_counter := 0
			for tile in row:
				var empty_tile := true
				if tile["ab_index"] > 0 or \
						tile["sobj_index"] >= 0 or \
						tile["unpassable"]:
					empty_row = false
					empty_tile = false
				tile_counter += 1
				if not empty_tile and tile_counter > max_width:
					max_width = tile_counter
			row_counter += 1
			if not empty_row and row_counter > max_height:
				max_height = row_counter

		map_renderer.cmp.update_map(max_width, max_height, map_tiles)
		map_renderer.cmp.save_to_file(path)

	menu_open = false

func _on_file_dialog_canceled():
	menu_open = false

func change_map_mode() -> void:
	# Cycle Modes (Icon is the NEXT mode, does that make sense?)
	if mode == MapMode.TILE:
		change_to_object_mode()
	elif mode == MapMode.OBJECT:
		change_to_unpassable_mode()
	elif mode == MapMode.UNPASSABLE:
		change_to_tile_mode()

func _on_mode_pressed():
	change_map_mode()

func _toggle_hide_objects():
	objects_hidden = not objects_hidden
	objects.visible = not objects_hidden
	if objects_hidden:
		hide_objects_button.texture_normal = load("res://Images/eye-crossed.svg")
		hide_objects_button.texture_pressed = load("res://Images/eye-crossed.svg")
		hide_objects_button.texture_hover = load("res://Images/eye-crossed-dark.svg")
		hide_objects_button.texture_disabled = load("res://Images/eye-crossed-dark.svg")
	else:
		hide_objects_button.texture_normal = load("res://Images/eye.svg")
		hide_objects_button.texture_pressed = load("res://Images/eye.svg")
		hide_objects_button.texture_hover = load("res://Images/eye-dark.svg")
		hide_objects_button.texture_disabled = load("res://Images/eye-crossed-dark.svg")

func _on_hide_objects_pressed():
	_toggle_hide_objects()

func _next_page() -> void:
	if mode == MapMode.TILE:
		var previous_tile_page = current_tile_page
		current_tile_page = min(max_tile_pages, current_tile_page + 1)
		if previous_tile_page != current_tile_page:
			load_tileset(current_tile_page * tile_page_size)
	elif mode == MapMode.OBJECT:
		var previous_object_page = current_object_page
		current_object_page = min(max_object_pages, current_object_page + 1)
		if previous_object_page != current_object_page:
			load_objectset(current_object_page * object_page_size)

func _on_next_tile_pressed():
	_next_page()

func _prev_page() -> void:
	if mode == MapMode.TILE:
		var previous_tile_page = current_tile_page
		current_tile_page = max(0, current_tile_page - 1)
		if previous_tile_page != current_tile_page:
			load_tileset(current_tile_page * tile_page_size)
	elif mode == MapMode.OBJECT:
		var previous_object_page = current_object_page
		current_object_page = max(0, current_object_page - 1)
		if previous_object_page != current_object_page:
			load_objectset(current_object_page * object_page_size)

func _on_previous_tile_pressed():
	_prev_page()

func undo() -> void:
	if undo_stack:
		var undo_info = undo_stack.pop_at(0)
		var mouse_coordinate = undo_info["mouse_coordinate"]
		if undo_info["type"] == MapMode.TILE:
			tile_map.set_cell(0, undo_info["mouse_coordinate"], undo_info["previous_index"], Vector2i(0, 0))
			map_tiles[mouse_coordinate.y][mouse_coordinate.x]["ab_index"] = undo_info["previous_index"]
		elif undo_info["type"] == MapMode.OBJECT:
			if mouse_coordinate in map_objects and \
					map_objects[mouse_coordinate] != null:
				map_objects[mouse_coordinate].queue_free()
				map_objects[mouse_coordinate] = null
			map_tiles[mouse_coordinate.y][mouse_coordinate.x]["sobj_index"] = undo_info["previous_index"]
			if undo_info["previous_index"] >= 0:
				map_renderer.create_object(self, undo_info["previous_index"], mouse_coordinate)
				map_objects[mouse_coordinate] = objects.get_child(objects.get_child_count() - 1)
		elif undo_info["type"] == MapMode.UNPASSABLE:
			if mouse_coordinate in map_unpassables and \
					map_unpassables[mouse_coordinate] != null:
				map_unpassables[mouse_coordinate].queue_free()
				map_unpassables[mouse_coordinate] = null
			if not undo_info["visible"]:
				var unpassable_sprite := Sprite2D.new()
				unpassable_sprite.texture = load("res://Images/placeholder-red.svg")
				unpassable_sprite.centered = false
				unpassable_sprite.position = mouse_coordinate * Resources.tile_size_vector
				unpassables.add_child(unpassable_sprite)
				map_unpassables[mouse_coordinate] = unpassable_sprite
				map_tiles[mouse_coordinate.y][mouse_coordinate.x]["unpassable"] = true
			else:
				if mouse_coordinate in map_unpassables and \
					map_unpassables[mouse_coordinate] != null:
					map_unpassables[mouse_coordinate].queue_free()
					map_unpassables[mouse_coordinate] = null
				map_tiles[mouse_coordinate.y][mouse_coordinate.x]["unpassable"] = false

	if not undo_stack:
		undo_stack.clear()
		undo_button.disabled = true
	else:
		undo_button.disabled = false

func _on_undo_pressed():
	undo()

func change_to_tile_mode() -> void:
	mode = MapMode.TILE
	tile_mode_button.texture_normal = load("res://Images/contrast-bright.svg")
	object_mode_button.texture_normal = load("res://Images/extension-dark.svg")
	unpassable_mode_button.texture_normal = load("res://Images/placeholder-dark.svg")
	unpassables.visible = false
	load_tileset()
	update_cursor_preview(current_tile_index)

func _on_tile_mode_pressed():
	change_to_tile_mode()

func change_to_object_mode() -> void:
	mode = MapMode.OBJECT
	tile_mode_button.texture_normal = load("res://Images/contrast-dark.svg")
	object_mode_button.texture_normal = load("res://Images/extension-bright.svg")
	unpassable_mode_button.texture_normal = load("res://Images/placeholder-dark.svg")
	unpassables.visible = false
	load_objectset()
	update_cursor_preview(current_object_index)

func _on_object_mode_pressed():
	change_to_object_mode()

func change_to_unpassable_mode() -> void:
	mode = MapMode.UNPASSABLE
	tile_mode_button.texture_normal = load("res://Images/contrast-dark.svg")
	object_mode_button.texture_normal = load("res://Images/extension-dark.svg")
	unpassable_mode_button.texture_normal = load("res://Images/placeholder-bright.svg")
	tile_selection_area.visible = false
	object_selection_area.visible = false
	status_label.text = ""
	next_button.visible = false
	prev_button.visible = false
	unpassables.visible = true
	update_cursor_preview(0)

func _on_unpassable_mode_pressed():
	change_to_unpassable_mode()

func _toggle_selection_area() -> void:
	if mode == MapMode.TILE:
		tile_selection_area.visible = not tile_selection_area.visible
	elif mode == MapMode.OBJECT:
		object_selection_area.visible = not object_selection_area.visible
	elif mode == MapMode.UNPASSABLE:
		unpassables.visible = not unpassables.visible

func _on_hide_panel_pressed():
	_toggle_selection_area()
