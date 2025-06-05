class_name TileTextureRect extends TextureRect

const NTK_Frame = preload("res://DataTypes/NTK_Frame.gd")
const Palette = preload("res://DataTypes/Palette.gd")

var tile_index: int
var palette_index: int

var palette_animation_last_tick := 0
var is_animated: bool = false
var animation_length: int = 0

func _init(tile_index: int) -> void:
	self.tile_index = tile_index
	self.palette_index = Renderers.map_renderer.tile_renderer.tbl.palette_indices[self.tile_index]
	var tile_image: Image = Renderers.map_renderer.tile_renderer.render_frame(
		self.tile_index, self.palette_index, self.palette_animation_last_tick)
	if tile_image != null \
			and tile_image.get_width() > 0 \
			and tile_image.get_height() > 0:
		self.texture = ImageTexture.create_from_image(tile_image)
	# Determine if Tile is animated
	var palette: Palette = Renderers.map_renderer.tile_renderer.pal.get_palette(self.palette_index)
	if palette.is_animated:
		var animated_colors: Array[int] = []
		for animation_range in palette.animation_ranges:
			var min_index = animation_range.min_index
			var max_index = animation_range.max_index
			animated_colors.append(range(min_index, max_index+1))
			if max_index - min_index + 1 > self.animation_length:
				self.animation_length = max_index - min_index + 1
		var frame: NTK_Frame = Renderers.map_renderer.tile_renderer.get_frame(self.tile_index)
		var frame_raw_pixel_data: Array[int] = frame.raw_pixel_data_array
		if Resources.arrays_intersect(palette.animation_indices, frame_raw_pixel_data):
			self.is_animated = true

func _process(delta):
	if MapperState.palette_animation_tick != self.palette_animation_last_tick \
			and self.is_animated:
		self.palette_animation_last_tick = MapperState.palette_animation_tick
		var tile_image: Image = Renderers.map_renderer.tile_renderer.render_frame(
		self.tile_index, self.palette_index, self.palette_animation_last_tick % self.animation_length)
		if tile_image != null \
				and tile_image.get_width() > 0 \
				and tile_image.get_height() > 0:
			self.texture = ImageTexture.create_from_image(tile_image)
