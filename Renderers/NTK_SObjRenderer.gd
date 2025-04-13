class_name NTK_SObjRenderer extends Node

const SObj = preload("res://DataTypes/SObj.gd")

var tilec_renderer: NTK_TileRenderer = null
var sobj: SObjTblFileHandler = null

var object_images := {}

func prune_cache(images_to_remove: int) -> void:
	var keys_to_remove: Array[int] = []
	for image_key in object_images.keys():
		keys_to_remove.append(image_key)
		if len(keys_to_remove) >= images_to_remove:
			break
	for image_key in keys_to_remove:
		object_images.erase(image_key)

func _init():
	var start_time := Time.get_ticks_msec()
	tilec_renderer = NTK_TileRenderer.new("tilec\\d+\\.dat", "TileC.pal", "TILEC.TBL")
	sobj = SObjTblFileHandler.new(DatFileHandler.new("tile.dat").get_file("SObj.tbl"))
	
	if Debug.debug_renderer_timings:
		print("[SObjRenderer]: ", Time.get_ticks_msec() - start_time, " ms")

func render_object(object_index: int) -> ImageTexture:
	var object: SObj = sobj.objects[object_index]
	var actual_height = object.height
	var object_image := Image.create(Resources.tile_size, Resources.tile_size * actual_height, false, Image.FORMAT_RGBA8)
	if object_index not in object_images:
		for i in range(object.height):
			var tile_index := object.tile_indices[i]
			var palette_index := tilec_renderer.tbl.palette_indices[tile_index]
			var image_key := str(tile_index) + "-" + str(palette_index)
			var frame := tilec_renderer.get_frame(object.tile_indices[i])
			var frame_rect := Rect2i(0, 0, frame.width, frame.height)
			object_image.blit_rect_mask(
				tilec_renderer.render_frame(object.tile_indices[i], palette_index), 
				frame.mask_image,
				frame_rect,
				Vector2i(frame.left, (actual_height - i - 1) * Resources.tile_size + frame.top))
			object_images[object_index] = object_image

	if object_index in object_images:
		return ImageTexture.create_from_image(object_images[object_index])
	else:
		return ImageTexture.create_from_image(object_image)
