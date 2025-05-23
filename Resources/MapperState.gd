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

# Tick
var tick_rate := 64
var tick := 0
var tick_cooldown := 0.0
var elapsed_time := 0.0

# Updates Frame Animated Palette Pixel
var palette_animation_tick_rate := 28
var palette_animation_tick := 0

func _process(delta) -> void:
	# Update Tick
	elapsed_time += delta * 1000
	tick_cooldown -= delta
	if tick_cooldown <= 0:
		tick += 1
		if tick % palette_animation_tick_rate == 0:
			palette_animation_tick += 1
		tick_cooldown = 1 / float(tick_rate)
