class_name NTK_Frame extends Node

var left: int
var top: int
var right: int
var bottom: int
var width: int
var height: int
var size: Vector2i = Vector2i(0, 0)
var pivot: Vector2i = Vector2i(0, 0)
var source_file_bytes: PackedByteArray
var pixel_data_offset: int
var pixel_data_length: int
var mask_image: Image

func _init(
		p_left: int,
		p_top: int,
		p_right: int,
		p_bottom: int,
		p_width: int,
		p_height: int,
		p_source_file_bytes: PackedByteArray,
		p_pixel_data_offset: int,
		p_pixel_data_length: int,
		p_mask_image: Image):
	self.left = p_left
	self.top = p_top
	self.right = p_right
	self.bottom = p_bottom
	self.width = p_width
	self.height = p_height
	self.pixel_data_offset = p_pixel_data_offset
	self.pixel_data_length = p_pixel_data_length
	self.size = Vector2i(self.width, self.height)
	self.pivot = Vector2i(self.left, self.top)
	self.source_file_bytes = p_source_file_bytes
	self.mask_image = p_mask_image
