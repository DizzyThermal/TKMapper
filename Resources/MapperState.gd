extends Node

var map_size: Vector2i = Vector2i(1, 1)

var menu_open: bool = false

var over_window: bool = false
var over_title_bar: bool = false
var over_title_label: bool = false
var over_status_bar: bool = false
var over_selection_area: bool = false
var over_button: bool = false
var over_toggle_selection_area_button: bool = false

var objects_hidden: bool = false
var is_erase_mode: bool = false
var shifting: bool = false

var copying_multiple: bool = false
var pasting_multiple: bool = false
