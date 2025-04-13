extends Panel

@onready var data_directory_line_edit: LineEdit = $VBoxContainer/DataDirectoryContainer/LineEdit
@onready var tile_page_size_spin_box: SpinBox = $VBoxContainer/TilePageSizeContainer/SpinBox
@onready var object_page_size_spin_box: SpinBox = $VBoxContainer/ObjectPageSizeContainer/SpinBox
@onready var tile_cache_size_spin_box: SpinBox = $VBoxContainer/TileCacheSizeContainer/SpinBox
@onready var object_cache_size_spin_box: SpinBox = $VBoxContainer/ObjectCacheSizeContainer/SpinBox
@onready var status_label: RichTextLabel = $StatusLabel

var parent: Node2D

func set_parent(new_parent: Node2D) -> void:
	self.parent = new_parent

func _on_close_button_pressed():
	visible = false
	MapperState.menu_open = false
	status_label.text = ""

func _on_data_directory_line_edit_text_submitted(new_data_dir_path):
	if FileAccess.file_exists(new_data_dir_path + "/tile.dat"):
		Database.upsert_config_item("data_dir", new_data_dir_path)
		status_label.text = "[b][color=green]Updated Data Directory[/color][/b]: %s" % new_data_dir_path
	else:
		status_label.text = "[b][color=red]Invalid Data Directory[/color][/b]: %s" % new_data_dir_path
		data_directory_line_edit.text = Database.get_config_item_value("data_dir")

func _on_tile_page_size_value_changed(new_tile_page_size):
	var new_size: int = int(new_tile_page_size)
	if new_size is int and \
			new_size >= 0 and \
			new_size <= 500:
		Database.upsert_config_item("tile_page_size", str(new_size))
		if parent.mode == parent.MapMode.TILE:
			parent.load_tileset(parent.current_tile_page * new_size)
		status_label.text = "[b][color=green]Updated Tile Page Size[/color][/b]: %s" % str(new_size)
	else:
		status_label.text = "[b][color=red]Invalid Tile Page Size[/color][/b]: %s" % str(new_size)
		tile_page_size_spin_box.value = int(Database.get_config_item_value("tile_page_size"))

func _on_object_page_size_value_changed(new_object_page_size):
	var new_size: int = int(new_object_page_size)
	if new_size is int and \
			new_size >= 0 and \
			new_size <= 100:
		Database.upsert_config_item("object_page_size", str(new_size))
		if parent.mode == parent.MapMode.OBJECT:
			parent.load_objectset(parent.current_object_page * new_size)
		status_label.text = "[b][color=green]Updated Object Page Size[/color][/b]: %s" % str(new_size)
	else:
		status_label.text = "[b][color=red]Invalid Object Page Size[/color][/b]: %s" % str(new_size)
		object_page_size_spin_box.value = int(Database.get_config_item_value("object_page_size"))

func _on_tile_cache_size_value_changed(new_tile_cache_size):
	var new_size: int = int(new_tile_cache_size)
	if new_size is int and \
			new_size >= 0 and \
			new_size <= 5000:
		Database.upsert_config_item("tile_cache_size", str(new_size))
		status_label.text = "[b][color=green]Updated Tile Cache Size[/color][/b]: %s" % str(new_size)
	else:
		status_label.text = "[b][color=red]Invalid Tile Cache Size[/color][/b]: %s" % str(new_size)
		tile_cache_size_spin_box.value = int(Database.get_config_item_value("tile_cache_size"))

func _on_object_cache_size_value_changed(new_object_cache_size):
	var new_size: int = int(new_object_cache_size)
	if new_size is int and \
			new_size >= 0 and \
			new_size <= 500:
		Database.upsert_config_item("object_cache_size", str(new_size))
		status_label.text = "[b][color=green]Updated Object Cache Size[/color][/b]: %s" % str(new_size)
	else:
		status_label.text = "[b][color=red]Invalid Object Cache Size[/color][/b]: %s" % str(new_size)
		object_cache_size_spin_box.value = int(Database.get_config_item_value("object_cache_size"))
