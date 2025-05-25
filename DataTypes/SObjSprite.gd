class_name SObjSprite extends Sprite2D

const NTK_Frame = preload("res://DataTypes/NTK_Frame.gd")
const Palette = preload("res://DataTypes/Palette.gd")

var object_index: int

var palette_animation_last_tick := 0
var is_animated: bool = false
var animation_length: int = 0

func _init(object_index: int) -> void:
	self.object_index = object_index
	self.texture = Renderers.map_renderer.sobj_renderer.render_object(
		self.object_index, palette_animation_last_tick)
	self.centered = false
	self.y_sort_enabled = true
	self.z_index = 1
	self.z_as_relative = false
	# Determine if SObj is animated
	var sobj: SObj = Renderers.map_renderer.sobj_renderer.sobj.objects[self.object_index]
	for tile_index in sobj.tile_indices:
		var palette_index: int = Renderers.map_renderer.sobj_renderer.tilec_renderer.tbl.palette_indices[tile_index]
		var palette: Palette = Renderers.map_renderer.sobj_renderer.tilec_renderer.pal.get_palette(palette_index)
		if not palette.is_animated:
			continue
		var animated_colors: Array[int] = []
		for animation_range in palette.animation_ranges:
			var min_index = animation_range.min_index
			var max_index = animation_range.max_index
			animated_colors.append(range(min_index, max_index+1))
			if max_index - min_index + 1 > animation_length:
				animation_length = max_index - min_index + 1
		var frame: NTK_Frame = Renderers.map_renderer.sobj_renderer.tilec_renderer.get_frame(tile_index)
		var frame_raw_pixel_data: Array[int] = frame.raw_pixel_data_array
		if Resources.arrays_intersect(palette.animation_indices, frame_raw_pixel_data):
			is_animated = true
			break

func _process(delta):
	if MapperState.palette_animation_tick != palette_animation_last_tick \
			and is_animated:
		palette_animation_last_tick = MapperState.palette_animation_tick
		self.texture = Renderers.map_renderer.sobj_renderer.render_object(
			self.object_index, palette_animation_last_tick % animation_length)
