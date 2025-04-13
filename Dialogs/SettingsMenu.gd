extends Panel

@onready var data_directory_line_edit: LineEdit = $VBoxContainer/DataDirectoryContainer/LineEdit
@onready var tile_page_size_spin_box: SpinBox = $VBoxContainer/TilePageSizeContainer/SpinBox
@onready var object_page_size_spin_box: SpinBox = $VBoxContainer/ObjectPageSizeContainer/SpinBox

var parent: Node2D

func set_parent(new_parent: Node2D) -> void:
	self.parent = new_parent

func _on_close_button_pressed():
	visible = false
	MapperState.menu_open = false

func _on_data_directory_line_edit_text_submitted(new_data_dir_path):
	if FileAccess.file_exists(new_data_dir_path + "/tile.dat"):
		Database.upsert_config_item("data_dir", new_data_dir_path)
		print_rich("\n  [b][color=green][UPDATED][/color] Data Directory: %s[/b]" % new_data_dir_path)
	else:
		print_rich("\n  [b][color=red][ERROR][/color] Invalid Data Directory: %s[/b]" % new_data_dir_path)
		data_directory_line_edit.text = Database.get_config_item_value("data_dir")

func _on_tile_page_size_value_changed(new_tile_page_size):
	var new_size: int = int(new_tile_page_size)
	if new_size is int and \
			new_size >= 0 and \
			new_size <= 500:
		Database.upsert_config_item("tile_page_size", str(new_size))
		if parent.mode == parent.MapMode.TILE:
			parent.load_tileset(parent.current_tile_page * new_size)
		print_rich("\n  [b][color=green][UPDATED][/color] Tile Page Size: %s[/b]" % str(new_size))
	else:
		print_rich("\n  [b][color=red][ERROR][/color] Invalid Tile Page Size: %s[/b]" % str(new_size))
		tile_page_size_spin_box.value = int(Database.get_config_item_value("tile_page_size"))

func _on_object_page_size_value_changed(new_object_page_size):
	var new_size: int = int(new_object_page_size)
	if new_size is int and \
			new_size >= 0 and \
			new_size <= 100:
		Database.upsert_config_item("object_page_size", str(new_size))
		if parent.mode == parent.MapMode.OBJECT:
			parent.load_objectset(parent.current_object_page * new_size)
		print_rich("\n  [b][color=green][UPDATED][/color] Object Page Size: %s[/b]" % str(new_size))
	else:
		print_rich("\n  [b][color=green][UPDATED][/color] Object Page Size: %s[/b]" % str(new_size))
		object_page_size_spin_box.value = int(Database.get_config_item_value("object_page_size"))
