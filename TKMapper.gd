extends Node2D

# State Variables
var cursor_renderer: NTK_CursorRenderer = null
var cursor_state := "Idle"

var cursor_tile := Sprite2D.new()
var cursor_rect := Rect2(Vector2i.ZERO, Resources.tile_size_vector)
var cursor_inner_rect := Rect2(Vector2i(0.1, 0.1), Vector2i(0.8, 0.8))
var map_regex: RegEx = RegEx.new()
var start_copy_position: Vector2i = Vector2i(-1, -1)
var start_paste_position: Vector2i = Vector2i(-1, -1)
var start_selection_position: int = -1
var previous_target_box_size: Vector2i = Resources.tile_size_vector

var max_tile_count := 0
var max_object_count := 0
var current_tile_index := 0
var current_object_index := 0
var hover_tile_index := 0
var hover_object_index := 0
var current_tile_page := 0
var current_object_page := 0

enum MapMode {
	TILE = 0,
	OBJECT = 1,
	UNPASSABLE = 2,
}
var mode := MapMode.TILE

var camera_min_zoom := 0.5
var camera_max_zoom := 4.0

var undo_stack := []

# Map State
var map_tiles := []
var map_copy_tiles := []
var map_objects := {}
var map_unpassables := {}

# Selection Area
var thread_ids: Array[int] = []

# Scene Nodes
@onready var camera: Camera2D = $Camera2D
@onready var tile_map := $TileMap
@onready var objects := $Objects
@onready var unpassables := $Unpassables
@onready var cursor_preview := $CursorPreview
@onready var cursor_tile_map := $CursorPreview/TileMap
@onready var cursor_objects := $CursorPreview/Objects
@onready var cursor_unpassables := $CursorPreview/Unpassables
@onready var target_box: Panel = $TargetBox
@onready var map_limits_box: Panel = $MapLimitsBox
@onready var map_bounds_box: Panel = $MapBoundsBox
@onready var tool_tip_label: Label = $CanvasLayer/ToolTipLabel
@onready var title_bar := $CanvasLayer/Title
@onready var tile_selection_area := $CanvasLayer/TileSelectionBackground
@onready var object_selection_area := $CanvasLayer/ObjectSelectionBackground
@onready var tile_set_container := $CanvasLayer/TileSelectionBackground/ScrollContainer/Container
@onready var object_set_container := $CanvasLayer/ObjectSelectionBackground/ScrollContainer/HBoxContainer
@onready var file_dialog := $CanvasLayer/Title/FileDialog
@onready var title_label := $CanvasLayer/Title/TitleLabel 
@onready var load_map_button := $CanvasLayer/Title/LoadMap
@onready var save_map_button := $CanvasLayer/Title/SaveMap
@onready var tile_mode_button := $CanvasLayer/Title/TileMode
@onready var object_mode_button := $CanvasLayer/Title/ObjectMode
@onready var unpassable_mode_button := $CanvasLayer/Title/UnpassableMode
@onready var hide_objects_button := $CanvasLayer/Title/HideObjects
@onready var undo_button := $CanvasLayer/Title/Undo
@onready var settings_button := $CanvasLayer/Title/Settings
@onready var status_bar := $CanvasLayer/StatusBar
@onready var page_info_label := $CanvasLayer/StatusBar/PageInfoLabel
@onready var status_label := $CanvasLayer/StatusBar/StatusLabel
@onready var prev_button := $CanvasLayer/StatusBar/PreviousTile
@onready var goto_page_button := $CanvasLayer/StatusBar/GoToPage
@onready var next_button := $CanvasLayer/StatusBar/NextTile
@onready var hide_panel_button := $CanvasLayer/StatusBar/HidePanel
@onready var settings_menu := $CanvasLayer/SettingsMenu
@onready var data_dir_line_edit := $CanvasLayer/SettingsMenu/VBoxContainer/DataDirectoryContainer/LineEdit
@onready var tile_page_size_spinbox := $CanvasLayer/SettingsMenu/VBoxContainer/TilePageSizeContainer/SpinBox
@onready var object_page_size_spinbox := $CanvasLayer/SettingsMenu/VBoxContainer/ObjectPageSizeContainer/SpinBox
@onready var tile_cache_size_spinbox := $CanvasLayer/SettingsMenu/VBoxContainer/TileCacheSizeContainer/SpinBox
@onready var object_cache_size_spinbox := $CanvasLayer/SettingsMenu/VBoxContainer/ObjectCacheSizeContainer/SpinBox
@onready var goto_page := $CanvasLayer/GoToPageMenu
@onready var goto_page_spinbox := $CanvasLayer/GoToPageMenu/VBoxContainer/PageNumberContainer/SpinBox

var initialized: bool = false

func initialize() -> void:
	# Settings Panel
	settings_menu.set_parent(self)
	goto_page.set_parent(self)

	cursor_renderer = NTK_CursorRenderer.new()
	file_dialog.access = FileDialog.Access.ACCESS_FILESYSTEM
	var last_map_path_parts: PackedStringArray = Database.get_config_item_value("last_map_path").split("/")
	var last_map_dir: String = "/".join(last_map_path_parts.slice(0, len(last_map_path_parts) - 1))
	file_dialog.current_dir = last_map_dir
	file_dialog.add_filter("*.cmp", "Map Files")

	map_regex.compile("TK(\\d+).cmp")

	# Camera Limits
	camera.limit_left = 0
	camera.limit_top = -480

	# Load Map
	load_map(Database.get_config_item_value("last_map_path"))

	# Create Cursor Tile
	cursor_tile_map.tile_set = tile_map.tile_set
	current_tile_index = map_tiles[0][0]["ab_index"]
	var palette_index := Renderers.map_renderer.tile_renderer.tbl.palette_indices[current_tile_index]
	var tile_image: Image = Renderers.map_renderer.tile_renderer.render_frame(current_tile_index, palette_index)
	if tile_image.get_width() > 0 \
			and tile_image.get_height() > 0:
		map_copy_tiles.append([])
		map_copy_tiles[0].append({
			"ab_index": current_tile_index,
			"sobj_index": -1,
			"unpassable": false,
		})
		cursor_tile_map.set_cell(0, Vector2i(0, 0), current_tile_index, Vector2i(0, 0))
		
	cursor_tile.z_index = 2
	cursor_tile.centered = false
	add_child(cursor_tile)
	add_child(cursor_tile_map)
	set_target_box_color(Color.GREEN)

	# TileSet
	max_tile_count = Renderers.map_renderer.tile_renderer.tbl.tile_count
	max_object_count = Renderers.map_renderer.sobj_renderer.sobj.object_count
	var max_tile_pages: int = ceil(max_tile_count / int(tile_page_size_spinbox.value))
	current_tile_page = current_tile_index / int(tile_page_size_spinbox.value)
	page_info_label.text = "Page " + str(current_tile_page + 1) + "/" + str(max_tile_pages + 1)
	change_to_tile_mode(current_tile_page)

	# Connect Signals
	## Viewport
	get_viewport().connect("mouse_entered", func(): MapperState.over_window = true)
	get_viewport().connect("mouse_exited", func(): MapperState.over_window = false)

	## Title Bar
	title_bar.connect("mouse_entered", func(): 
		MapperState.over_title_bar = true
		MapperState.over_title_label = true
	)
	title_bar.connect("mouse_exited", func(): 
		MapperState.over_title_bar = false
		MapperState.over_title_label = false
	)
	
	title_label.connect("mouse_entered", func(): MapperState.over_title_label = true)
	title_label.connect("mouse_exited", func(): MapperState.over_title_label = false)

	load_map_button.connect("mouse_entered", func(): 
		MapperState.over_button = true
		update_tool_tip("Load Map (L)", load_map_button.global_position + Vector2(10, 42))
	)
	load_map_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)

	save_map_button.connect("mouse_entered", func():
		MapperState.over_button = true
		update_tool_tip("Save Map (S)", save_map_button.global_position + Vector2(-24, 42))
	)
	save_map_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)

	tile_mode_button.connect("mouse_entered", func():
		MapperState.over_button = true
		update_tool_tip("Tile Mode (T)", tile_mode_button.global_position + Vector2(-32, 42))
	)
	tile_mode_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)

	object_mode_button.connect("mouse_entered", func():
		MapperState.over_button = true
		update_tool_tip("Object Mode (O)", object_mode_button.global_position + Vector2(-42, 42))
	)
	object_mode_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)

	unpassable_mode_button.connect("mouse_entered", func():
		MapperState.over_button = true
		update_tool_tip("Unpassable Mode (P)", unpassable_mode_button.global_position + Vector2(-64, 42))
	)
	unpassable_mode_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)

	hide_objects_button.connect("mouse_entered", func():
		MapperState.over_button = true
		update_tool_tip("Hide Objects (H)", hide_objects_button.global_position + Vector2(-38, 42))
	)
	hide_objects_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)

	undo_button.connect("mouse_entered", func():
		MapperState.over_button = true
		update_tool_tip("Undo (U)", undo_button.global_position + Vector2(-16, 42))
	)
	undo_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)
	
	settings_button.connect("mouse_entered", func():
		MapperState.over_button = true
		update_tool_tip("Settings", settings_button.global_position + Vector2(-36, 42))
	)
	settings_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)

	## Selection Area
	tile_selection_area.connect("mouse_entered", func(): MapperState.over_selection_area = true)
	tile_selection_area.connect("mouse_exited", func(): MapperState.over_selection_area = false)

	object_selection_area.connect("mouse_entered", func(): MapperState.over_selection_area = true)
	object_selection_area.connect("mouse_exited", func(): MapperState.over_selection_area = false)

	## Status Bar
	status_bar.connect("mouse_entered", func(): MapperState.over_status_bar = true)
	status_bar.connect("mouse_exited", func(): MapperState.over_status_bar = false)

	page_info_label.connect("mouse_entered", func(): MapperState.over_status_bar = true)
	page_info_label.connect("mouse_exited", func(): MapperState.over_status_bar = false)

	prev_button.connect("mouse_entered", func():
		MapperState.over_button = true
		update_tool_tip("Previous Page (←)", prev_button.global_position + Vector2(-48, -30))
	)
	prev_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)

	goto_page_button.connect("mouse_entered", func():
		MapperState.over_button = true
		update_tool_tip("Goto Page (G)", goto_page_button.global_position + Vector2(-50, -30))
	)
	goto_page_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)

	next_button.connect("mouse_entered", func():
		MapperState.over_button = true
		update_tool_tip("Next Page (→)", next_button.global_position + Vector2(-56, -30))
	)
	next_button.connect("mouse_exited", func():
		MapperState.over_button = false
		update_tool_tip("")
	)

	hide_panel_button.connect("mouse_entered", func():
		MapperState.over_button = true
		MapperState.over_toggle_selection_area_button = true
		var verb := "Hide" if tile_selection_area.visible or object_selection_area.visible else "Show"
		var selection_area := "Tile Panel" if mode == MapMode.TILE else "Object Panel"
		var shortcut := "(↓)" if verb == "Hide" else "(↑)"
		update_tool_tip(
			"%s %s %s" % [verb, selection_area, shortcut],
			next_button.global_position + Vector2(-92, -30)
		)
	)
	hide_panel_button.connect("mouse_exited", func():
		MapperState.over_button = false
		MapperState.over_toggle_selection_area_button = false
		update_tool_tip("")
	)

	# Settings Panel
	data_dir_line_edit.text = Database.get_config_item_value("data_dir")
	tile_page_size_spinbox.value = int(Database.get_config_item_value("tile_page_size"))
	object_page_size_spinbox.value = int(Database.get_config_item_value("object_page_size"))
	tile_cache_size_spinbox.value = int(Database.get_config_item_value("tile_cache_size"))
	object_cache_size_spinbox.value = int(Database.get_config_item_value("object_cache_size"))

	initialized = true

func _process(delta):
	# Initialize the Mapper
	if not Database.database_initialized:
		return
	if not Database.config_key_exists("data_dir"):
		print_rich("\n  [b][color=red][ERROR][/color]: Unable to find a valid data directory![/b]\n")
		for data_dir in Database.default_data_dirs:
			print_rich("    [b][color=red]Does Not Exist[/color][/b]: [b]%s[/b]" % data_dir)
		print("\n")
		get_tree().quit()
		return
	if not initialized:
		initialize()

	# Load / Save Map
	if Input.is_action_just_pressed("load-map") and \
			not MapperState.menu_open:
		_load_map()					# L
	elif Input.is_action_just_pressed("save-map") and \
			not MapperState.menu_open:
		_save_map()					# S

	# Mode Switches
	if Input.is_action_just_pressed("toggle-mode") and \
			not MapperState.menu_open:
		change_map_mode()							# M
	elif Input.is_action_just_pressed("mode-tile") and \
			not MapperState.menu_open:
		change_to_tile_mode(current_tile_page)		# T
	elif Input.is_action_just_pressed("mode-object") and \
			not MapperState.menu_open:
		change_to_object_mode(current_object_page)	# O
	elif Input.is_action_just_pressed("mode-unpassable") and \
			not MapperState.menu_open:
		change_to_unpassable_mode()					# P

	# Toggle Objects
	if Input.is_action_just_pressed("toggle-objects") \
			and not MapperState.menu_open:
		_toggle_hide_objects()

	# Undo Tile
	if Input.is_action_just_pressed("undo") and \
			not MapperState.menu_open:
		undo()

	# Toggle Insert / Erase Modes
	if Input.is_action_just_pressed("insert-mode") and \
			not MapperState.menu_open:
		MapperState.is_erase_mode = false		# I
		target_box.size = previous_target_box_size
	elif Input.is_action_just_pressed("erase-mode") and \
			not MapperState.menu_open:
		MapperState.is_erase_mode = true		# D | E | X
		previous_target_box_size = target_box.size
		target_box.size = Resources.tile_size_vector

	# Page Switching
	if Input.is_action_just_pressed("next-page") and \
			not Input.is_key_pressed(KEY_SHIFT) and \
			not MapperState.menu_open:
		_next_page()
	elif Input.is_action_just_pressed("goto-page") and \
			not MapperState.menu_open:
		_on_go_to_page_pressed()
	elif Input.is_action_just_pressed("previous-page") and \
			not Input.is_key_pressed(KEY_SHIFT) and \
			not MapperState.menu_open:
		_prev_page()
	elif Input.is_action_just_pressed("show-selection-area") and \
			not Input.is_key_pressed(KEY_SHIFT) and \
			not MapperState.menu_open:
		_toggle_selection_area(true, true)
	elif Input.is_action_just_pressed("hide-selection-area") and \
			not Input.is_key_pressed(KEY_SHIFT) and \
			not MapperState.menu_open:
		_toggle_selection_area(true, false)

	# Map Shifting
	if Input.is_action_just_pressed("shift-map-up") and \
			Input.is_key_pressed(KEY_SHIFT) and \
			not MapperState.shifting and \
			not MapperState.menu_open:
		MapperState.shifting = true
		shift_map(Resources.Direction.UP)
	elif Input.is_action_just_pressed("shift-map-right") and \
			Input.is_key_pressed(KEY_SHIFT) and \
			not MapperState.shifting and \
			not MapperState.menu_open:
		MapperState.shifting = true
		shift_map(Resources.Direction.RIGHT)
	elif Input.is_action_just_pressed("shift-map-down") and \
			Input.is_key_pressed(KEY_SHIFT) and \
			not MapperState.shifting and \
			not MapperState.menu_open:
		MapperState.shifting = true
		shift_map(Resources.Direction.DOWN)
	elif Input.is_action_just_pressed("shift-map-left") and \
			Input.is_key_pressed(KEY_SHIFT) and \
			not MapperState.shifting and \
			not MapperState.menu_open:
		MapperState.shifting = true
		shift_map(Resources.Direction.LEFT)

	# Cursor
	var mouse_position := get_global_mouse_position()
	var mouse_coordinate := Vector2i(get_global_mouse_position()) / Resources.tile_size_vector
	var snapped_mouse_position := (Vector2i(get_global_mouse_position()) - (Resources.tile_size_vector / 2)).snapped(Resources.tile_size_vector)
	var grabbing_map := false
	
	# ALT + RMB (Right Mouse Button)
	MapperState.copying_multiple = Input.is_key_pressed(KEY_ALT) \
		and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or \
			Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) \
		and mode != MapMode.UNPASSABLE \
		and mouse_over_tile_map() \
		and not MapperState.is_erase_mode

	if Input.is_key_pressed(KEY_CTRL) or Input.is_action_pressed("move-map"):
		cursor_state = "Grab"
		grabbing_map = true
		cursor_tile.visible = false
		cursor_preview.visible = false
		target_box.visible = false
	elif MapperState.is_erase_mode:
		set_target_box_color(Color.RED)
		cursor_tile.visible = false
		cursor_preview.visible = false
		target_box.visible = true
		cursor_state = "Attack"
	elif mode == MapMode.UNPASSABLE:
		cursor_tile.visible = true
		cursor_preview.visible = false
		target_box.visible = false
		cursor_state = "Idle"
	elif Input.is_key_pressed(KEY_ALT):
		set_target_box_color(Color.CYAN)
		if start_copy_position == Vector2i(-1, -1) \
				and MapperState.copying_multiple:
			start_copy_position = snapped_mouse_position
		cursor_tile.visible = false
		cursor_preview.visible = false
		target_box.visible = true
		cursor_state = "Select"
	else:
		set_target_box_color(Color.GREEN)
		if mode == MapMode.UNPASSABLE:
			cursor_tile.visible = true
			cursor_preview.visible = false
		else:
			cursor_tile.visible = false
			cursor_preview.visible = true
		target_box.visible = true
		cursor_state = "Idle"
	
	# Copy Multiple (Done on Release of ALT + RMB)
	if not MapperState.copying_multiple \
			and start_copy_position != Vector2i(-1, -1):
		var copy_dims: Vector2i = Vector2i(
			target_box.size.x / Resources.tile_size,
			target_box.size.y / Resources.tile_size
		)
		var real_start_x: int = min(start_copy_position.x, target_box.position.x)
		var real_start_y: int = min(start_copy_position.y, target_box.position.y)
		var start_copy_coordinate: Vector2i = Vector2i(
			real_start_x / Resources.tile_size,
			real_start_y / Resources.tile_size,
		)
		map_copy_tiles.clear()
		cursor_tile_map.clear()
		clear_cursor_objects()
		for y in range(copy_dims.y):
			map_copy_tiles.append([])
			for x in range(copy_dims.x):
				var ab_index: int = map_tiles[start_copy_coordinate.y + y][start_copy_coordinate.x + x]["ab_index"] if mode == MapMode.TILE or Input.is_key_pressed(KEY_SHIFT) else -10
				var sobj_index: int = map_tiles[start_copy_coordinate.y + y][start_copy_coordinate.x + x]["sobj_index"] if mode == MapMode.OBJECT or Input.is_key_pressed(KEY_SHIFT) else -10
				var unpassable: bool = map_tiles[start_copy_coordinate.y + y][start_copy_coordinate.x + x]["unpassable"] if mode == MapMode.UNPASSABLE or Input.is_key_pressed(KEY_SHIFT) else false
				map_copy_tiles[y].append({
					"ab_index": ab_index,
					"sobj_index": sobj_index,
					"unpassable": unpassable,
				})
				var palette_index := Renderers.map_renderer.tile_renderer.tbl.palette_indices[ab_index]
				var frame := Renderers.map_renderer.tile_renderer.get_frame(ab_index)
				var frame_rect := Rect2i(0, 0, frame.width, frame.height)
				if ab_index >= 0:
					if ab_index not in Renderers.map_renderer.ntk_tileset_source.tile_atlas_position_by_tile_index:
						Renderers.map_renderer.add_tile_to_tile_set_source(self, ab_index)
					cursor_tile_map.set_cell(0, Vector2i(x, y), ab_index, Vector2i(0, 0))
				if sobj_index >= 0:
					var sobj: SObj = Renderers.map_renderer.sobj_renderer.sobj.objects[sobj_index]
					var sobj_height := sobj.height
					var obj_sprite := SObjSprite.new(sobj_index)
					obj_sprite.position.x = x * Resources.tile_size
					obj_sprite.offset.y = -(sobj_height) * Resources.tile_size
					obj_sprite.position.y = ((y - sobj_height + 1) * Resources.tile_size) - obj_sprite.offset.y
					cursor_objects.add_child(obj_sprite)

		start_copy_position = Vector2i(-1, -1)

	# Update Cursor
	if cursor_state in cursor_renderer.cursors:
		Input.set_custom_mouse_cursor(cursor_renderer.cursors[cursor_state].get_frame_texture(cursor_renderer.cursors[cursor_state].current_frame), Input.CURSOR_ARROW, Vector2(0, 0))

	# Change Tile on Left Mouse Button (LMB) - Insert Mode
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and \
			not Input.is_action_pressed("move-map") and \
			not Input.is_key_pressed(KEY_ALT) and \
			not MapperState.is_erase_mode and \
			mouse_over_tile_map() and \
			not MapperState.menu_open and \
			not MapperState.copying_multiple and \
			coordinate_on_map(mouse_coordinate):
		paste_cursor_preview(mouse_coordinate)
		
		if mouse_coordinate.x + len(map_copy_tiles[0]) > MapperState.map_size.x:
			MapperState.map_size.x = mouse_coordinate.x + len(map_copy_tiles[0])
		if mouse_coordinate.y + len(map_copy_tiles) > MapperState.map_size.y:
			MapperState.map_size.y = mouse_coordinate.y + len(map_copy_tiles)
		map_bounds_box.size = Vector2i(MapperState.map_size.x, MapperState.map_size.y) * Resources.tile_size

	# Copy Tile(s) from Selection Area (LMB/RMB) - Start Trigger
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or \
			Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and \
			not Input.is_action_pressed("move-map") and \
			not Input.is_key_pressed(KEY_ALT) and \
			not MapperState.is_erase_mode and \
			not mouse_over_tile_map() and \
			MapperState.over_selection_area and \
			not MapperState.menu_open and \
			not MapperState.copying_multiple and \
			start_selection_position == -1:
		if mode == MapMode.TILE:
			start_selection_position = self.hover_tile_index
		elif mode == MapMode.OBJECT:
			start_selection_position = self.hover_object_index
	# Copy Tile(s) from Selection Area (LMB/RMB) - End Trigger
	elif (not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and \
				not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and \
			not Input.is_action_pressed("move-map") and \
			not Input.is_key_pressed(KEY_ALT) and \
			not MapperState.is_erase_mode and \
			not mouse_over_tile_map() and \
			MapperState.over_selection_area and \
			not MapperState.menu_open and \
			not MapperState.copying_multiple and \
			not start_selection_position == -1:
		map_copy_tiles.clear()
		map_copy_tiles.append([])
		cursor_tile_map.clear()
		clear_cursor_objects()
		var end_selection_position: int  = self.hover_tile_index if mode == MapMode.TILE else self.hover_object_index
		var real_start: int = min(start_selection_position, end_selection_position)
		var real_end: int = max(start_selection_position, end_selection_position)
		target_box.size = Vector2i((real_end - real_start + 1) * Resources.tile_size, Resources.tile_size)
		if mode == MapMode.TILE:
			for i in range(real_start, real_end + 1):
				if i not in Renderers.map_renderer.ntk_tileset_source.tile_atlas_position_by_tile_index:
					Renderers.map_renderer.add_tile_to_tile_set_source(self, i)
				cursor_tile_map.set_cell(0, Vector2i(i - real_start, 0), i, Vector2i(0, 0))
				map_copy_tiles[0].append({
					"ab_index": i,
					"sobj_index": -10,
					"unpassable": false,
				})
		elif mode == MapMode.OBJECT:
			for i in range(real_start, real_end + 1):
				var sobj: SObj = Renderers.map_renderer.sobj_renderer.sobj.objects[i]
				var sobj_height := sobj.height
				var obj_sprite := SObjSprite.new(i)
				obj_sprite.position.x = (i - real_start) * Resources.tile_size
				obj_sprite.offset.y = -(sobj_height) * Resources.tile_size
				obj_sprite.position.y = ((-sobj_height + 1) * Resources.tile_size) - obj_sprite.offset.y
				cursor_objects.add_child(obj_sprite)
				map_copy_tiles[0].append({
					"ab_index": -10,
					"sobj_index": i,
					"unpassable": false,
				})
		start_selection_position = -1

	# Erase Tile on Mouse Button (LMB/RMB) - Eraser Mode
	if (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or \
			Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)) and \
			not Input.is_key_pressed(KEY_ALT) and \
			not Input.is_action_pressed("move-map") and \
			MapperState.is_erase_mode and \
			mouse_over_tile_map() and \
			not MapperState.menu_open and \
			not MapperState.copying_multiple and \
			coordinate_on_map(mouse_coordinate):
		if mode == MapMode.TILE:
			erase_tile(mouse_coordinate)
		elif mode == MapMode.OBJECT:
			erase_object(mouse_coordinate)
		elif mode == MapMode.UNPASSABLE:
			erase_unpassable_tile(mouse_coordinate)

		MapperState.map_size = calculate_map_size()
		map_bounds_box.size = MapperState.map_size * Resources.tile_size
	# Copy Tile on Right Mouse Button (RMB) - Insert Mode
	if Input.is_action_just_pressed("copy-tile") and \
			not Input.is_key_pressed(KEY_ALT) and \
			cursor_state == "Idle" and \
			mouse_over_tile_map() and \
			not MapperState.copying_multiple and \
			not MapperState.menu_open:
		var cursor_tile_coord := get_global_mouse_position()
		cursor_tile_coord.x = floor(cursor_tile_coord.x / Resources.tile_size)
		cursor_tile_coord.y = floor(cursor_tile_coord.y / Resources.tile_size)
		if coordinate_on_map(cursor_tile_coord):
			var index: int = map_tiles[cursor_tile_coord.y][cursor_tile_coord.x]["ab_index"]
			if mode == MapMode.OBJECT:
				index = map_tiles[cursor_tile_coord.y][cursor_tile_coord.x]["sobj_index"]
			update_cursor_preview(index)
			target_box.size = Resources.tile_size_vector
			# Seek to Page
			if mode == MapMode.TILE:
				var previous_tile_page = current_tile_page
				current_tile_page = current_tile_index / int(tile_page_size_spinbox.value)
				if previous_tile_page != current_tile_page:
					load_tileset(current_tile_page)
			elif mode == MapMode.OBJECT:
				var previous_object_page = current_object_page
				current_object_page = current_object_index / int(object_page_size_spinbox.value)
				if previous_object_page != current_object_page:
					load_objectset(current_object_page)

	# Tile Preview
	if coordinate_on_map(mouse_coordinate) and \
			mouse_position.y >= 4 and \
			not grabbing_map and \
			mouse_over_tile_map() and \
			not MapperState.menu_open:
		if MapperState.copying_multiple:
			var real_start_x: int = min(start_copy_position.x, snapped_mouse_position.x)
			var real_start_y: int = min(start_copy_position.y, snapped_mouse_position.y)
			var real_end_x: int = max(start_copy_position.x, snapped_mouse_position.x)
			var real_end_y: int = max(start_copy_position.y, snapped_mouse_position.y)
			target_box.position = Vector2i(real_start_x, real_start_y)
			target_box.size = Vector2(
				max(real_end_x - real_start_x + Resources.tile_size, Resources.tile_size),
				max(real_end_y - real_start_y + Resources.tile_size, Resources.tile_size),
			)
		else:
			cursor_tile.position = snapped_mouse_position
			cursor_preview.position = snapped_mouse_position
			target_box.position = snapped_mouse_position
		if mode != MapMode.UNPASSABLE:
			target_box.visible = true
	else:
		#print("---------------chasing-down-focus-bug---------------------")
		#print("mouse_coordinate: ", mouse_coordinate)
		#print("coordinate_on_map: ", coordinate_on_map(mouse_coordinate))
		#print("mouse_position.y >= 4 :: ", mouse_position.y >= 4)
		#print("not grabbing_map :: ", not grabbing_map)
		#print("mouse_over_tile_map() :: ", mouse_over_tile_map())
		#print("not MapperState.menu_open :: ", not MapperState.menu_open)
		cursor_tile.visible = false
		cursor_preview.visible = false
		target_box.visible = false
	
	if Input.is_action_just_pressed("zoom-in") and \
			not Input.is_key_pressed(KEY_CTRL) and \
			mouse_over_tile_map() and \
			not MapperState.menu_open:
		camera.position = get_global_mouse_position()
		if camera.zoom.x <= camera_max_zoom:
			camera.zoom.x *= 1.5
		if camera.zoom.y <= camera_max_zoom:
			camera.zoom.y *= 1.5
	if Input.is_action_just_pressed("zoom-out") and \
			not Input.is_key_pressed(KEY_CTRL) and \
			mouse_over_tile_map() and \
			not MapperState.menu_open:
		if camera.zoom.x >= camera_min_zoom:
			camera.zoom.x /= 1.5
		if camera.zoom.y >= camera_min_zoom:
			camera.zoom.y /= 1.5

	if mouse_over_tile_map() and \
			not MapperState.menu_open:
		var info_tile_index = tile_map.get_cell_source_id(0, mouse_coordinate)
		status_label.text = "(" + str(mouse_coordinate.x) + ", " + str(mouse_coordinate.y) + ")"
	elif not mouse_over_tile_map() and \
			not MapperState.menu_open:
		if mode == MapMode.TILE:
			status_label.text = "Tile Index: " + str(self.hover_tile_index)
		elif mode == MapMode.OBJECT:
			status_label.text = "Object Index: " + str(self.hover_object_index)

func update_tool_tip(
		tool_tip_text: String,
		tool_tip_position: Vector2=Vector2(0, 0)) -> void:
	tool_tip_label.visible = false
	tool_tip_label.size = Vector2(0, 0)
	tool_tip_label.text = tool_tip_text
	tool_tip_label.position = tool_tip_position
	tool_tip_label.visible = true if len(tool_tip_text) > 0 else false

func mouse_over_tile_map() -> bool:
	return	MapperState.over_window and \
			not MapperState.over_button and \
			not MapperState.over_title_bar and \
			not MapperState.over_title_label and \
			not MapperState.over_selection_area and \
			not MapperState.over_status_bar

func coordinate_on_map(coordinate: Vector2i) -> bool:
	return coordinate.x >= 0 and \
		coordinate.x <= 255 and \
		coordinate.y >= 0 and \
		coordinate.y <= 255

func set_target_box_color(color: Color) -> void:
	var target_box_stylebox: StyleBoxFlat = target_box.get_theme_stylebox("panel")
	target_box_stylebox.border_color = color

func load_map(map_path: String) -> void:
	clear_map()
	Renderers.map_renderer.render_map(self, map_path, true)
	map_tiles.clear()
	for y in range(256):
		map_tiles.append([])
		for x in range(256):
			map_tiles[y].append({
				"ab_index": 0,
				"sobj_index": -1,
				"unpassable": false,
			})
	map_tiles = Renderers.map_renderer.get_map_tile_indices(map_tiles)
	if current_tile_index == 0:
		current_tile_index = map_tiles[0][0]["ab_index"]
	# Add Objects to map_objects dictionary (by coordinate Vector2i)
	for object in objects.get_children():
		var object_coordinate := Vector2i(object.position) / Resources.tile_size_vector
		object_coordinate.y -= 1
		map_objects[object_coordinate] = object
	# Load Unpassable Tiles in
	for i in range(len(Renderers.map_renderer.cmp.tiles)):
		var tile := Renderers.map_renderer.cmp.tiles[i]
		var x := i % Renderers.map_renderer.cmp.width
		var y := i / Renderers.map_renderer.cmp.width
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
	MapperState.map_size = Vector2i(Renderers.map_renderer.cmp.width, Renderers.map_renderer.cmp.height)
	map_bounds_box.size = MapperState.map_size * Resources.tile_size
	
	camera.position = Vector2(-1000, 400)
	title_label.text = map_path.split("/")[-1].replace(".cmp", "")

func paste_cursor_preview(paste_coordinate: Vector2i) -> void:
	for y in range(len(map_copy_tiles)):
		for x in range(len(map_copy_tiles[y])):
			var paste_location: Vector2i = Vector2i(
				paste_coordinate.x + x,
				paste_coordinate.y + y
			)
			if paste_location.x >= 0 \
					and paste_location.x <= 255 \
					and paste_location.y >= 0 \
					and paste_location.y <= 255:
				var tile: Dictionary = map_copy_tiles[y][x]
				# Tile
				current_tile_index = tile["ab_index"]
				if current_tile_index >= 0:
					insert_tile(Vector2i(paste_location.x, paste_location.y))
				elif mode == MapMode.TILE or Input.is_key_pressed(KEY_SHIFT):
					erase_tile(Vector2i(paste_location.x, paste_location.y))
				# Object
				current_object_index = tile["sobj_index"]
				if current_object_index >= 0:
					insert_object(Vector2i(paste_location.x, paste_location.y))
				elif mode == MapMode.OBJECT or Input.is_key_pressed(KEY_SHIFT):
					erase_object(Vector2i(paste_location.x, paste_location.y))
				# Unpassable
				var source_tile_unpassable = tile["unpassable"]
				if source_tile_unpassable:
					insert_unpassable_tile(Vector2i(paste_location.x, paste_location.y))
				elif mode == MapMode.UNPASSABLE or Input.is_key_pressed(KEY_SHIFT):
					erase_unpassable_tile(Vector2i(paste_location.x, paste_location.y))

	start_paste_position = Vector2i(-1, -1)

func shift_map(direction: Resources.Direction) -> void:
	var previous_tile_index: int = current_tile_index
	var previous_object_index: int = current_object_index
	if direction == Resources.Direction.UP:
		# Shift Content Up
		for y in range(MapperState.map_size.y):
			for x in range(MapperState.map_size.x):
				if y > 0:
					# Tile
					current_tile_index = map_tiles[y][x]["ab_index"]
					insert_tile(Vector2i(x, y - 1), false)
					# Object
					current_object_index = map_tiles[y][x]["sobj_index"]
					if current_object_index >= 0:
						insert_object(Vector2i(x, y - 1), false)
					else:
						erase_object(Vector2i(x, y - 1), false)
					# Unpassable
					var source_tile_unpassable = map_tiles[y][x]["unpassable"]
					if source_tile_unpassable:
						insert_unpassable_tile(Vector2i(x, y - 1), false)
					else:
						erase_unpassable_tile(Vector2i(x, y - 1), false)
					
		# Remove Content on X = MapperState.map_size.y - 1
		for x in range(MapperState.map_size.x):
			erase_tile(Vector2i(x, MapperState.map_size.y - 1), false)
			erase_object(Vector2i(x, MapperState.map_size.y - 1), false)
			erase_unpassable_tile(Vector2i(x, MapperState.map_size.y - 1), false)

		MapperState.map_size = calculate_map_size()
		map_bounds_box.size = MapperState.map_size * Resources.tile_size
	elif direction == Resources.Direction.RIGHT:
		# Shift Content Right
		for y in range(MapperState.map_size.y):
			for x in range(MapperState.map_size.x, -1, -1):
				if x < 255:
					# Tile
					current_tile_index = map_tiles[y][x]["ab_index"]
					insert_tile(Vector2i(x + 1, y), false)
					# Object
					current_object_index = map_tiles[y][x]["sobj_index"]
					if current_object_index >= 0:
						insert_object(Vector2i(x + 1, y), false)
					else:
						erase_object(Vector2i(x + 1, y), false)
					# Unpassable
					var source_tile_unpassable = map_tiles[y][x]["unpassable"]
					if source_tile_unpassable:
						insert_unpassable_tile(Vector2i(x + 1, y), false)
					else:
						erase_unpassable_tile(Vector2i(x + 1, y), false)
					
		# Remove Content on Y = 0
		for y in range(MapperState.map_size.y):
			erase_tile(Vector2i(0, y), false)
			erase_object(Vector2i(0, y), false)
			erase_unpassable_tile(Vector2i(0, y), false)

		MapperState.map_size = calculate_map_size()
		map_bounds_box.size = MapperState.map_size * Resources.tile_size
	elif direction == Resources.Direction.DOWN:
		# Shift Content Down
		for y in range(MapperState.map_size.y, -1, -1):
			for x in range(MapperState.map_size.x):
				if y < 255:
					# Tile
					current_tile_index = map_tiles[y][x]["ab_index"]
					insert_tile(Vector2i(x, y + 1), false)
					# Object
					current_object_index = map_tiles[y][x]["sobj_index"]
					if current_object_index >= 0:
						insert_object(Vector2i(x, y + 1), false)
					else:
						erase_object(Vector2i(x, y + 1), false)
					# Unpassable
					var source_tile_unpassable = map_tiles[y][x]["unpassable"]
					if source_tile_unpassable:
						insert_unpassable_tile(Vector2i(x, y + 1), false)
					else:
						erase_unpassable_tile(Vector2i(x, y + 1), false)
					
		# Remove Content on X = 0
		for x in range(MapperState.map_size.x):
			erase_tile(Vector2i(x, 0), false)
			erase_object(Vector2i(x, 0), false)
			erase_unpassable_tile(Vector2i(x, 0), false)

		MapperState.map_size = calculate_map_size()
		map_bounds_box.size = MapperState.map_size * Resources.tile_size
	elif direction == Resources.Direction.LEFT:
		# Shift Content Left
		for y in range(MapperState.map_size.y):
			for x in range(MapperState.map_size.x):
				if x > 0:
					# Tile
					current_tile_index = map_tiles[y][x]["ab_index"]
					insert_tile(Vector2i(x - 1, y), false)
					# Object
					current_object_index = map_tiles[y][x]["sobj_index"]
					if current_object_index >= 0:
						insert_object(Vector2i(x - 1, y), false)
					else:
						erase_object(Vector2i(x - 1, y), false)
					# Unpassable
					var source_tile_unpassable = map_tiles[y][x]["unpassable"]
					if source_tile_unpassable:
						insert_unpassable_tile(Vector2i(x - 1, y), false)
					else:
						erase_unpassable_tile(Vector2i(x - 1, y), false)
					
		# Remove Content on Y = MapperState.map_size.x - 1
		for y in range(MapperState.map_size.y):
			erase_tile(Vector2i(MapperState.map_size.x - 1, y), false)
			erase_object(Vector2i(MapperState.map_size.x - 1, y), false)
			erase_unpassable_tile(Vector2i(MapperState.map_size.x - 1, y), false)

		MapperState.map_size = calculate_map_size()
		map_bounds_box.size = MapperState.map_size * Resources.tile_size

	current_tile_index = previous_tile_index
	current_object_index = previous_object_index
	MapperState.shifting = false

func insert_tile(coodinate: Vector2i, add_to_undo_stack: bool=true) -> void:
	if current_tile_index < 0:
		return

	var previous_tile_index = map_tiles[coodinate.y][coodinate.x]["ab_index"]
	if previous_tile_index != current_tile_index and add_to_undo_stack:
		undo_stack.insert(0, {
			"mouse_coordinate": coodinate,
			"previous_index": previous_tile_index,
			"new_index": current_tile_index,
			"type": MapMode.TILE,
		})
		undo_button.disabled = false
	if current_tile_index not in Renderers.map_renderer.ntk_tileset_source.tile_atlas_position_by_tile_index:
		Renderers.map_renderer.add_tile_to_tile_set_source(self, current_tile_index)
	tile_map.set_cell(0, coodinate, current_tile_index, Vector2i(0, 0))
	undo_button.disabled = false
	map_tiles[coodinate.y][coodinate.x]["ab_index"] = current_tile_index

func erase_tile(coodinate: Vector2i, add_to_undo_stack: bool=true) -> void:
	var previous_tile_index = map_tiles[coodinate.y][coodinate.x]["ab_index"]
	if previous_tile_index != -1 and add_to_undo_stack:
		undo_stack.insert(0, {
			"mouse_coordinate": coodinate,
			"previous_index": previous_tile_index,
			"new_index": -1,
			"type": MapMode.TILE,
		})
		undo_button.disabled = false
	tile_map.set_cell(0, coodinate)
	map_tiles[coodinate.y][coodinate.x]["ab_index"] = -1

func insert_object(coodinate: Vector2i, add_to_undo_stack: bool=true) -> void:
	if current_object_index < 0:
		return

	var previous_object_index = map_tiles[coodinate.y][coodinate.x]["sobj_index"]
	if previous_object_index != current_object_index and add_to_undo_stack:
		undo_stack.insert(0, {
			"mouse_coordinate": coodinate,
			"previous_index": previous_object_index,
			"new_index": current_object_index,
			"type": MapMode.OBJECT,
		})
		undo_button.disabled = false
	if coodinate in map_objects and \
			map_objects[coodinate] != null:
		map_objects[coodinate].queue_free()
		map_objects[coodinate] = null
	map_tiles[coodinate.y][coodinate.x]["sobj_index"] = current_object_index
	Renderers.map_renderer.create_object(self, current_object_index, coodinate)
	map_objects[coodinate] = objects.get_child(objects.get_child_count() - 1)

func erase_object(coodinate: Vector2i, add_to_undo_stack: bool=true) -> void:
	if coodinate in map_objects and \
			map_objects[coodinate] != null:
		map_objects[coodinate].queue_free()
		map_objects[coodinate] = null
		if add_to_undo_stack:
			undo_stack.insert(0, {
				"mouse_coordinate": coodinate,
				"previous_index": map_tiles[coodinate.y][coodinate.x]["sobj_index"],
				"new_index": -1,
				"type": MapMode.OBJECT,
			})
			undo_button.disabled = false
	map_tiles[coodinate.y][coodinate.x]["sobj_index"] = -1

func insert_unpassable_tile(coodinate: Vector2i, add_to_undo_stack: bool=true) -> void:
	var unpassable = map_tiles[coodinate.y][coodinate.x]["unpassable"]
	if not unpassable and add_to_undo_stack:
		undo_stack.insert(0, {
			"mouse_coordinate": coodinate,
			"visible": true,
			"type": MapMode.UNPASSABLE,
		})
		undo_button.disabled = false
	if coodinate in map_unpassables and \
			map_unpassables[coodinate] != null:
		map_unpassables[coodinate].queue_free()
		map_unpassables[coodinate] = null
	map_tiles[coodinate.y][coodinate.x]["unpassable"] = true
	var unpassable_sprite := Sprite2D.new()
	unpassable_sprite.texture = load("res://Images/placeholder-red.svg")
	unpassable_sprite.centered = false
	unpassable_sprite.position = coodinate * Resources.tile_size_vector
	unpassables.add_child(unpassable_sprite)
	map_unpassables[coodinate] = unpassable_sprite

func erase_unpassable_tile(coodinate: Vector2i, add_to_undo_stack: bool=true) -> void:
	if coodinate in map_unpassables and \
			map_unpassables[coodinate] != null:
		map_unpassables[coodinate].queue_free()
		map_unpassables[coodinate] = null
		if add_to_undo_stack:
			undo_stack.insert(0, {
				"mouse_coordinate": coodinate,
				"visible": false,
				"type": MapMode.UNPASSABLE,
			})
			undo_button.disabled = false
	map_tiles[coodinate.y][coodinate.x]["unpassable"] = false

func update_cursor_preview(index: int) -> void:
	map_copy_tiles.clear()
	map_copy_tiles.append([])
	cursor_tile_map.clear()
	clear_cursor_objects()
	if mode == MapMode.TILE \
			and index > 0:
		current_tile_index = index
		var palette_index := Renderers.map_renderer.tile_renderer.tbl.palette_indices[current_tile_index]
		var tile_image: Image = Renderers.map_renderer.tile_renderer.render_frame(current_tile_index, palette_index)
		if tile_image.get_width() > 0 \
				and tile_image.get_height() > 0:
			map_copy_tiles[0].append({
				"ab_index": current_tile_index,
				"sobj_index": -10,
				"unpassable": false,
			})
			if current_tile_index not in Renderers.map_renderer.ntk_tileset_source.tile_atlas_position_by_tile_index:
				Renderers.map_renderer.add_tile_to_tile_set_source(self, current_tile_index)
			cursor_tile_map.set_cell(0, Vector2i(0, 0), current_tile_index, Vector2i(0, 0))
	elif mode == MapMode.OBJECT \
			and index >= 0:
		current_object_index = index
		var sobj: SObj = Renderers.map_renderer.sobj_renderer.sobj.objects[current_object_index]
		var sobj_height := sobj.height
		var obj_sprite := SObjSprite.new(current_object_index)
		obj_sprite.position.y = -(sobj_height - 1) * Resources.tile_size
		cursor_objects.add_child(obj_sprite)
		map_copy_tiles[0].append({
			"ab_index": -10,
			"sobj_index": current_object_index,
			"unpassable": false,
		})
	elif mode == MapMode.UNPASSABLE:
		cursor_tile.texture = load("res://Images/placeholder-red.svg")
		map_copy_tiles[0].append({
			"ab_index": -10,
			"sobj_index": -10,
			"unpassable": true,
		})

func clear_container(container: Container) -> void:
	for item in container.get_children():
		if item != null:
			item.queue_free()
			item = null

func render_tile(thread_tile_index: int) -> void:
	var tile_index: int = thread_ids[thread_tile_index]
	var palette_index := Renderers.map_renderer.tile_renderer.tbl.palette_indices[tile_index]
	Renderers.map_renderer.tile_renderer.render_frame(tile_index, palette_index)

func load_tileset(start_page: int=0) -> void:
	var tile_count: int = int(tile_page_size_spinbox.value)
	var start_tile: int = start_page * tile_count
	var end_tile = min(start_tile + tile_count, Renderers.map_renderer.tile_renderer.tbl.tile_count)

	# Prune Cache
	var tile_cache_size: int = int(Database.get_config_item_value("tile_cache_size"))
	var images_to_prune: int = len(Renderers.map_renderer.tile_renderer.images) + tile_count - tile_cache_size
	if images_to_prune > 0:
		Renderers.map_renderer.tile_renderer.prune_cache(images_to_prune)

	# Collect Unique Tiles
	thread_ids.clear()
	thread_ids.append_array(range(max(1, start_tile), end_tile))

	# Threaded Tile Renderering
	var task_id : int = WorkerThreadPool.add_group_task(render_tile, thread_ids.size(), -1, true)
	WorkerThreadPool.wait_for_group_task_completion(task_id)

	# Load Tile Selection Area
	clear_container(tile_set_container)
	for i in range(start_tile, end_tile):
		var tile_texture := TileTextureRect.new(i)
		tile_texture.custom_minimum_size = Resources.tile_size_vector
		tile_texture.connect("mouse_entered", func(): self.hover_tile_index = i)
		tile_set_container.add_child(tile_texture)
	var max_tile_pages: int = ceil(max_tile_count / int(tile_page_size_spinbox.value))
	page_info_label.text = "Tile Page " + str(current_tile_page + 1) + "/" + str(max_tile_pages + 1)

func render_object(thread_object_index: int) -> void:
	var object_index: int = thread_ids[thread_object_index]
	Renderers.map_renderer.sobj_renderer.render_object(object_index)

func load_objectset(start_page: int=0) -> void:
	var object_count: int = int(object_page_size_spinbox.value)
	var start_object: int = start_page * object_count
	var end_object = min(start_object + object_count, Renderers.map_renderer.sobj_renderer.sobj.object_count)

	# Prune Cache
	var tile_cache_size: int = int(Database.get_config_item_value("tile_cache_size"))
	var images_to_prune: int = len(Renderers.map_renderer.sobj_renderer.tilec_renderer.images) + (object_count * 10) - tile_cache_size
	if images_to_prune > 0:
		Renderers.map_renderer.sobj_renderer.tilec_renderer.prune_cache(images_to_prune)

	var object_cache_size: int = int(Database.get_config_item_value("object_cache_size"))
	var objects_to_prune: int = len(Renderers.map_renderer.sobj_renderer.object_images) + object_count - object_cache_size
	if objects_to_prune > 0:
		Renderers.map_renderer.sobj_renderer.prune_cache(objects_to_prune)

	# Collect Unique Objects
	thread_ids.clear()
	thread_ids.append_array(range(start_object, end_object))
	
	# Threaded Tile Renderering
	var task_id : int = WorkerThreadPool.add_group_task(render_object, thread_ids.size(), -1, true)
	WorkerThreadPool.wait_for_group_task_completion(task_id)
	
	# Load Object Selection Area
	clear_container(object_set_container)
	for i in range(start_object, end_object - 1):
		var object_texture := SObjTextureRect.new(i)
		var palette_index := Renderers.map_renderer.tile_renderer.tbl.palette_indices[i]
		object_texture.texture = Renderers.map_renderer.sobj_renderer.render_object(i)
		object_texture.connect("mouse_entered", func(): self.hover_object_index = i)
		object_texture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		object_texture.anchor_bottom = 1
		object_texture.size_flags_vertical = Control.SIZE_SHRINK_END
		object_texture.grow_vertical = Control.GROW_DIRECTION_BEGIN
		object_set_container.add_child(object_texture)
	var max_object_pages: int = ceil(max_object_count / int(object_page_size_spinbox.value))
	page_info_label.text = "Object Page " + str(current_object_page + 1) + "/" + str(max_object_pages + 1)

func _load_map():
	# Select Map to Load
	file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_OPEN_FILE
	MapperState.menu_open = true
	file_dialog.popup_centered_ratio(0.6)

func _on_load_map_pressed():
	_load_map()

func _save_map():
	# Select Map to Save
	file_dialog.file_mode = FileDialog.FileMode.FILE_MODE_SAVE_FILE
	file_dialog.current_file = Database.get_config_item_value("last_map_path").split("/")[-1]
	MapperState.menu_open = true
	file_dialog.popup_centered_ratio(0.6)

func _on_save_map_pressed():
	_save_map()

func clear_objects() -> void:
	for object in objects.get_children():
		if object != null:
			object.queue_free()
			object = null

func clear_cursor_objects() -> void:
	for object in cursor_objects.get_children():
		if object != null:
			object.queue_free()
			object = null

func clear_map() -> void:
	clear_objects()
	for unpassable in unpassables.get_children():
		if unpassable != null:
			unpassable.queue_free()
			unpassable = null
	Renderers.map_renderer.cmp = null

func update_last_map_path(map_path: String) -> void:
	Database.upsert_config_item("last_map_path", map_path.replace("\\", "/"))

func calculate_map_size() -> Vector2i:
	var map_size: Vector2i = Vector2i(0, 0)

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
			if not empty_tile and tile_counter > map_size.x:
				map_size.x = tile_counter
		row_counter += 1
		if not empty_row and row_counter > map_size.y:
			map_size.y = row_counter
	
	return map_size

func _on_file_dialog_file_selected(map_path: String):
	if file_dialog.file_mode == FileDialog.FileMode.FILE_MODE_OPEN_FILE:
		# Load Map from Path
		var result = map_regex.search(map_path)
		if map_path.ends_with(".cmp"):
			load_map(map_path)
			update_last_map_path(map_path)
	elif file_dialog.file_mode == FileDialog.FileMode.FILE_MODE_SAVE_FILE:
		MapperState.map_size = calculate_map_size()
		map_bounds_box.size = MapperState.map_size * Resources.tile_size

		Renderers.map_renderer.cmp.update_map(MapperState.map_size.x, MapperState.map_size.y, map_tiles)
		Renderers.map_renderer.cmp.save_to_file(map_path)
		update_last_map_path(map_path)
		load_map(map_path)
	set_menu_closed()

func set_menu_closed(delay: float=0.2) -> void:
	var menu_closed_timer := Timer.new()
	
	menu_closed_timer.wait_time = delay
	menu_closed_timer.one_shot = true
	menu_closed_timer.autostart = true

	menu_closed_timer.connect("timeout", func(): MapperState.menu_open = false)
	
	add_child(menu_closed_timer)

func _on_file_dialog_canceled():
	set_menu_closed()

func change_map_mode() -> void:
	# Cycle Modes (Icon is the NEXT mode, does that make sense?)
	if mode == MapMode.TILE:
		change_to_object_mode(current_object_page)
	elif mode == MapMode.OBJECT:
		change_to_unpassable_mode()
	elif mode == MapMode.UNPASSABLE:
		change_to_tile_mode(current_tile_page)

func _on_mode_pressed():
	change_map_mode()

func _toggle_hide_objects():
	MapperState.objects_hidden = not MapperState.objects_hidden
	objects.visible = not MapperState.objects_hidden
	if MapperState.objects_hidden:
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
		var max_tile_pages: int = ceil(max_tile_count / int(tile_page_size_spinbox.value))
		current_tile_page = min(max_tile_pages, current_tile_page + 1)
		if previous_tile_page != current_tile_page:
			load_tileset(current_tile_page)
	elif mode == MapMode.OBJECT:
		var previous_object_page = current_object_page
		var max_object_pages: int = ceil(max_object_count / int(object_page_size_spinbox.value))
		current_object_page = min(max_object_pages, current_object_page + 1)
		if previous_object_page != current_object_page:
			load_objectset(current_object_page)

func _on_next_tile_pressed():
	_next_page()

func _prev_page() -> void:
	if mode == MapMode.TILE:
		var previous_tile_page = current_tile_page
		current_tile_page = max(0, current_tile_page - 1)
		if previous_tile_page != current_tile_page:
			load_tileset(current_tile_page)
	elif mode == MapMode.OBJECT:
		var previous_object_page = current_object_page
		current_object_page = max(0, current_object_page - 1)
		if previous_object_page != current_object_page:
			load_objectset(current_object_page)

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
				Renderers.map_renderer.create_object(self, undo_info["previous_index"], mouse_coordinate)
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
		MapperState.map_size = calculate_map_size()
		map_bounds_box.size = MapperState.map_size * Resources.tile_size

	if not undo_stack:
		undo_stack.clear()
		undo_button.disabled = true
	else:
		undo_button.disabled = false

func _on_undo_pressed():
	undo()

func _on_settings_pressed():
	settings_menu.visible = not settings_menu.visible
	settings_menu.status_label.text = ""
	if not settings_menu.visible:
		set_menu_closed()
	else:
		MapperState.menu_open = true

func change_to_tile_mode(start_page: int=0) -> void:
	_toggle_selection_area(true, false)
	mode = MapMode.TILE
	tile_mode_button.texture_normal = load("res://Images/contrast-bright.svg")
	object_mode_button.texture_normal = load("res://Images/extension-dark.svg")
	unpassable_mode_button.texture_normal = load("res://Images/placeholder-dark.svg")
	hide_panel_button.visible = true
	next_button.visible = true
	goto_page_button.visible = true
	prev_button.visible = true
	unpassables.visible = false
	load_tileset(start_page)
	update_cursor_preview(current_tile_index)
	_toggle_selection_area(true, true)

func _on_tile_mode_pressed():
	var tile_index: int = current_tile_page * int(tile_page_size_spinbox.value)
	change_to_tile_mode(current_tile_page)

func change_to_object_mode(start_page: int=0) -> void:
	_toggle_selection_area(true, false)
	mode = MapMode.OBJECT
	tile_mode_button.texture_normal = load("res://Images/contrast-dark.svg")
	object_mode_button.texture_normal = load("res://Images/extension-bright.svg")
	unpassable_mode_button.texture_normal = load("res://Images/placeholder-dark.svg")
	hide_panel_button.visible = true
	next_button.visible = true
	goto_page_button.visible = true
	prev_button.visible = true
	unpassables.visible = false
	load_objectset(start_page)
	update_cursor_preview(current_object_index)
	_toggle_selection_area(true, true)

func _on_object_mode_pressed():
	var object_index: int = current_object_page * int(object_page_size_spinbox.value)
	change_to_object_mode(object_index)

func change_to_unpassable_mode() -> void:
	_toggle_selection_area(true, false)
	mode = MapMode.UNPASSABLE
	tile_mode_button.texture_normal = load("res://Images/contrast-dark.svg")
	object_mode_button.texture_normal = load("res://Images/extension-dark.svg")
	unpassable_mode_button.texture_normal = load("res://Images/placeholder-bright.svg")
	tile_selection_area.visible = false
	object_selection_area.visible = false
	page_info_label.text = ""
	hide_panel_button.visible = false
	next_button.visible = false
	goto_page_button.visible = false
	prev_button.visible = false
	unpassables.visible = true
	update_cursor_preview(0)

func _on_unpassable_mode_pressed():
	change_to_unpassable_mode()

func _toggle_selection_area(
		override: bool=false,
		override_value: bool=false) -> void:
	var hidden: bool = false
	if mode == MapMode.TILE:
		tile_selection_area.visible = not tile_selection_area.visible \
			if not override else override_value
		hidden = not tile_selection_area.visible
		object_selection_area.visible = false
	elif mode == MapMode.OBJECT:
		object_selection_area.visible = not object_selection_area.visible \
			if not override else override_value
		hidden = not object_selection_area.visible
		tile_selection_area.visible = false
	elif mode == MapMode.UNPASSABLE:
		unpassables.visible = not unpassables.visible \
			if not override else override_value
		hidden = true
		tile_selection_area.visible = false
		object_selection_area.visible = false

	# Update Hover
	if MapperState.over_toggle_selection_area_button:
		var verb := "Hide" if tile_selection_area.visible or object_selection_area.visible else "Show"
		var selection_area := "Tile Panel" if mode == MapMode.TILE else "Object Panel"
		var shortcut := "(↓)" if verb == "Hide" else "(↑)"
		update_tool_tip(
			"%s %s %s" % [verb, selection_area, shortcut],
			next_button.global_position + Vector2(-92, -30)
		)
	
	if hidden:
		hide_panel_button.texture_normal = load("res://Images/eye-crossed.svg")
		hide_panel_button.texture_pressed = load("res://Images/eye-crossed.svg")
		hide_panel_button.texture_hover = load("res://Images/eye-crossed-dark.svg")
		hide_panel_button.texture_disabled = load("res://Images/eye-crossed-dark.svg")
	else:
		hide_panel_button.texture_normal = load("res://Images/eye.svg")
		hide_panel_button.texture_pressed = load("res://Images/eye.svg")
		hide_panel_button.texture_hover = load("res://Images/eye-dark.svg")
		hide_panel_button.texture_disabled = load("res://Images/eye-crossed-dark.svg")

func  _goto_page(page_number: int):
	if mode == MapMode.TILE:
		var previous_tile_page = current_tile_page
		var max_tile_pages: int = ceil(max_tile_count / int(tile_page_size_spinbox.value))
		current_tile_page = min(max_tile_pages, page_number)
		current_tile_page = max(0, current_tile_page)
		goto_page_spinbox.value = current_tile_page + 1
		if previous_tile_page != current_tile_page:
			load_tileset(current_tile_page)
	elif mode == MapMode.OBJECT:
		var previous_object_page = current_object_page
		var max_object_pages: int = ceil(max_object_count / int(object_page_size_spinbox.value))
		current_object_page = min(max_object_pages, page_number)
		current_object_page = max(0, current_object_page)
		goto_page_spinbox.value = current_object_page + 1
		if previous_object_page != current_object_page:
			load_objectset(current_object_page)

func _on_go_to_page_pressed():
	if mode == MapMode.UNPASSABLE:
		return

	goto_page.visible = not goto_page.visible
	if not goto_page.visible:
		set_menu_closed()
	else:
		MapperState.menu_open = true
		var current_page: int = current_tile_page + 1
		if mode == MapMode.OBJECT:
			current_page = current_object_page + 1
		goto_page.page_spin_box.get_line_edit().grab_focus()
		goto_page.page_spin_box.value = current_page

func _on_hide_panel_pressed():
	_toggle_selection_area()
