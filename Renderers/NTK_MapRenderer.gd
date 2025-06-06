class_name NTK_MapRenderer extends Node

const CmpFileHandler = preload("res://FileHandlers/CmpFileHandler.gd")
const SObj = preload("res://DataTypes/SObj.gd")
const NTK_Frame = preload("res://DataTypes/NTK_Frame.gd")
const NTK_TileSetSource = preload("res://DataTypes/NTK_TileSetSource.gd")

var tile_renderer: NTK_TileRenderer = null
var sobj_renderer: NTK_SObjRenderer = null

var cmp: CmpFileHandler = null
var tile_set: TileSet
var ntk_tileset_source := NTK_TileSetSource.new()
var thread_ids: Array[int] = []

var mutex: Mutex = Mutex.new()

func _init():
	var start_time := Time.get_ticks_msec()

	tile_renderer = NTK_TileRenderer.new()
	sobj_renderer = NTK_SObjRenderer.new()

	if Debug.debug_renderer_timings:
		print("[MapRenderer]: ", Time.get_ticks_msec() - start_time, " ms")

func get_map_name(map_path: String) -> String:
	var map_name: String = ""

	if "/" in map_path:
		map_name = map_path.split("/")[-1]
	elif "\\" in map_path:
		map_name = map_path.split("\\")[-1]

	return map_name

func _load_map(map_path: String):
	cmp = CmpFileHandler.new(map_path)

func render_map(parent: Node2D, map_path: String, render_objects: bool) -> void:
	_load_map(map_path)
	render_map_cropped(parent, map_path, 0, 0, cmp.width, cmp.height, render_objects)

func render_map_cropped(parent: Node2D, map_path: String, x: int, y: int, width: int, height: int, render_objects: bool=true) -> void:
	var start_time := Time.get_ticks_msec()
	_load_map(map_path)
	if width == 0 or height == 0:
		x = 0
		y = 0
		width = cmp.width
		height = cmp.height
	else:
		# Crop and adjust width/height if x/y are negative
		width = min(width, cmp.width) if x >= 0 else width - x
		height = min(height, cmp.height) if y >= 0 else height - y
		x = x if x >= 0 else 0
		y = y if y >= 0 else 0

	# Create TileMap (Ground)
	var tilemap_start_time := Time.get_ticks_msec()
	create_tilemap(parent, map_path, x, y, width, height)
	var map_name: String = get_map_name(map_path)

	if Debug.debug_renderer_timings:
		print("[", map_name, "]: Create TileMap: ", Time.get_ticks_msec() - tilemap_start_time, " ms")
	if render_objects:
		# Create Objects (Static Objects)
		var objects_start_time := Time.get_ticks_msec()
		create_objects(parent, map_path, x, y, width, height)
		if Debug.debug_renderer_timings:
			print("[", map_name, "]: Create Objects: ", Time.get_ticks_msec() - objects_start_time, " ms")
	
	if Debug.debug_renderer_timings:
		print("[", map_name, "]: ------- Loaded: ", Time.get_ticks_msec() - start_time, " ms\n")

func get_map_tile_indices(tile_indices) -> Array:
	for i in range(len(cmp.tiles)):
		var tile := cmp.tiles[i]
		var x := i % cmp.width
		var y := i / cmp.width
		tile_indices[y][x]["ab_index"] = tile.ab_index
		tile_indices[y][x]["sobj_index"] = tile.sobj_index
		tile_indices[y][x]["unpassable_tile"] = tile.unpassable_tile

	return tile_indices

func get_tile_collision(coordinate: Vector2i) -> int:
	if not cmp:
		return 0x0

	var tile_index := (coordinate.y * cmp.width) + coordinate.x
	if tile_index < 0 or tile_index >= len(cmp.tiles):
		return 0xF

	var unpassable_tile := cmp.tiles[tile_index].unpassable_tile
	if unpassable_tile:
		return 0xF

	var sobj_index := cmp.tiles[tile_index].sobj_index
	if sobj_index < 0:
		return 0x0

	var sobj := sobj_renderer.sobj
	return sobj.objects[sobj_index].collision

func create_tile_set_source() -> TileSetAtlasSource:
	for i in range(len(cmp.tiles)):
		var tile_position := Vector2i((i % cmp.width), (i / cmp.width))
		var tile_index := cmp.tiles[i].ab_index
		var palette_index = tile_renderer.tbl.palette_indices[tile_index]
		tile_renderer.render_frame(tile_index, palette_index, false)
		ntk_tileset_source.add_tile(tile_position, tile_index)

	if len(ntk_tileset_source.tile_atlas_position_by_tile_index) < ntk_tileset_source.tile_set_width:
		ntk_tileset_source.tile_set_width = len(ntk_tileset_source.tile_atlas_position_by_tile_index)
	
	var num_of_tiles = len(ntk_tileset_source.tile_atlas_position_by_tile_index)
	var tile_set_image_size = Vector2i((ntk_tileset_source.tile_set_width + 1) * Resources.tile_size, (ntk_tileset_source.tile_atlas_position.y + 1) * Resources.tile_size)
	var tile_set_image = Image.create_empty(
		tile_set_image_size.x, tile_set_image_size.y, false, Image.FORMAT_RGBA8)
	for tile_index in ntk_tileset_source.tile_atlas_position_by_tile_index:
		var tile_position = ntk_tileset_source.tile_atlas_position_by_tile_index[tile_index]
		var palette_index = tile_renderer.tbl.palette_indices[tile_index]
		tile_set_image.blit_rect(tile_renderer.render_frame(tile_index, palette_index), Resources.tile_rect, tile_position * Resources.tile_size)

	var tile_set_source := TileSetAtlasSource.new()
	if tile_set_image.get_width() > 0 \
			and tile_set_image.get_height() > 0:
		tile_set_source.texture = ImageTexture.create_from_image(tile_set_image)
	tile_set_source.texture_region_size = Resources.tile_size_vector
	for tile_index in ntk_tileset_source.tile_atlas_position_by_tile_index:
		var tile_position = ntk_tileset_source.tile_atlas_position_by_tile_index[tile_index]
		tile_set_source.create_tile(tile_position)

	return tile_set_source

func add_tile_to_tile_set_source(
		parent: Node2D,
		tile_index: int) -> void:
	var palette_index = tile_renderer.tbl.palette_indices[tile_index]
	var frame: NTK_Frame = null
	frame = tile_renderer.get_frame(tile_index)
	var palette := tile_renderer.pal.get_palette(palette_index)
	var tile_set_source := TileSetAtlasSource.new()
	tile_set_source.texture_region_size = Resources.tile_size_vector
	if palette.is_animated and \
			Resources.arrays_intersect(
				palette.animation_indices,
				frame.raw_pixel_data_array):
		var animation_count := 0
		var animated_colors: Array[int] = []
		for animation_range in palette.animation_ranges:
			var min_index = animation_range.min_index
			var max_index = animation_range.max_index
			animated_colors.append(range(min_index, max_index+1))
			if max_index - min_index + 1 > animation_count:
				animation_count = max_index - min_index + 1
		var tile_image: Image = tile_renderer.render_animated_frame(
			tile_index, animation_count, palette_index)
		if tile_image.get_width() > 0 \
				and tile_image.get_height() > 0:
			tile_set_source.texture = ImageTexture.create_from_image(tile_image)
		tile_set_source.create_tile(Vector2i(0, 0))
		tile_set_source.set_tile_animation_columns(Vector2i(0, 0), animation_count)
		tile_set_source.set_tile_animation_frames_count(Vector2i(0, 0), animation_count)
		for j in range(animation_count):
			tile_set_source.set_tile_animation_frame_duration(Vector2i(0, 0), j, 0.5)
	else:
		var tile_image: Image = tile_renderer.render_frame(
				tile_index,
				palette_index,
				0, 0,
				false)
		if tile_image != null \
				and tile_image.get_width() > 0 \
				and tile_image.get_height() > 0:
			tile_set_source.texture = ImageTexture.create_from_image(tile_image)
		tile_set_source.create_tile(Vector2i(0, 0))
	if not parent.tile_map.tile_set.has_source(tile_index):
		parent.tile_map.tile_set.add_source(tile_set_source, tile_index)

func prerender_tile(thread_index: int) -> void:
	var tile_index: int = thread_ids[thread_index]
	var palette_index = tile_renderer.tbl.palette_indices[tile_index]
	var frame := tile_renderer.get_frame(tile_index)
	var palette := tile_renderer.pal.get_palette(palette_index)
	var tile_set_source := TileSetAtlasSource.new()
	tile_set_source.texture_region_size = Resources.tile_size_vector
	if palette.is_animated and \
			Resources.arrays_intersect(
				palette.animation_indices,
				frame.raw_pixel_data_array):
		var animation_count := len(palette.animation_indices) / len(palette.animation_ranges)
		var tile_image: Image = tile_renderer.render_animated_frame(tile_index,
				animation_count,
				palette_index)
		if tile_image.get_width() > 0 \
				and tile_image.get_height() > 0:
			tile_set_source.texture = ImageTexture.create_from_image(tile_image)
		tile_set_source.create_tile(Vector2i(0, 0))
		tile_set_source.set_tile_animation_columns(Vector2i(0, 0), animation_count)
		tile_set_source.set_tile_animation_frames_count(Vector2i(0, 0), animation_count)
		for j in range(animation_count):
			tile_set_source.set_tile_animation_frame_duration(Vector2i(0, 0), j, 0.5)
	else:
		var tile_image: Image = tile_renderer.render_frame(
				tile_index,
				palette_index,
				false)
		if tile_image.get_width() > 0 \
				and tile_image.get_height() > 0:
			tile_set_source.texture = ImageTexture.create_from_image(tile_image)
		tile_set_source.create_tile(Vector2i(0, 0))
	mutex.lock()
	if not self.tile_set.has_source(tile_index):
		self.tile_set.add_source(tile_set_source, tile_index)
	mutex.unlock()

func create_tile_set() -> void:
	tile_set = TileSet.new()
	tile_set.tile_size = Resources.tile_size_vector

	# Collect Unique Tiles
	thread_ids.clear()
	for tile in cmp.tiles:
		var tile_index: int = tile.ab_index
		if tile_index not in thread_ids and \
				tile_index != 0 and \
				tile_index != 65535:
			thread_ids.append(tile_index)
	
	# Threaded Tile Renderering
	var task_id : int = WorkerThreadPool.add_group_task(prerender_tile, thread_ids.size(), -1, true)
	WorkerThreadPool.wait_for_group_task_completion(task_id)

func create_tilemap(parent: Node2D, map_path: String, x: int, y: int, width: int, height: int) -> void:
	var tile_map: TileMap = parent.tile_map
	tile_map.clear()

	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Resources.tile_size_vector
	create_tile_set()
	tile_map.tile_set = self.tile_set

	var map_area := Rect2i(x, y, width, height)
	var start_i: int = max(0, (y * cmp.width) + (x % cmp.width))
	var end_i: int = min(len(cmp.tiles), ((y + height) * cmp.width) + ((x + cmp.width) % cmp.width))
	var debug_image: Image = null
	var map_name: String = get_map_name(map_path)
	if Debug.debug_map_tilemap:
		debug_image = Image.create_empty(
			width * Resources.tile_size, height * Resources.tile_size, false,Image.FORMAT_RGBA8)
	for i in range(start_i, end_i):
		var tile_position := Vector2i((i % cmp.width), (i / cmp.width))
		if not map_area.has_point(tile_position):
			continue
		var ab_index := cmp.tiles[i].ab_index
		if tile_position in Debug.debug_tile_coords:
			print("[", map_name, "]: DEBUG: Frame[", ab_index, "] (", tile_position.x, ", ", tile_position.y, ")")
		var frame = tile_renderer.get_frame(ab_index)
		if ab_index == 0:
			print("[", map_name, "]: WARNING: Tile AB Index 0: ", tile_position.x, ", ", tile_position.y)
			continue
		if frame.width <= 0 or frame.height <= 0:
			print("[", map_name, "]: WARNING: Tile[", ab_index, "] Tile Dims: ", frame.width, " x ", frame.height, " | Tile Coords: ", tile_position.x, ", ", tile_position.y)
			continue
		tile_map.set_cell(0, tile_position, ab_index, Vector2i(0, 0))

		if Debug.debug_tile_indices and ab_index in Debug.debug_tile_indices:
			print("DEBUG:  Tile[", ab_index, "]:")
			print("DEBUG:    Palette Index: ", tile_renderer.tbl.palette_indices[ab_index])

		# Overlay Tiles
		if Debug.debug_map_tilemap:
			debug_image.blit_rect(
				tile_renderer.frames[ab_index],
				Rect2i(0, 0, frame.width, frame.height),
				Vector2i(
					(tile_position.x - x) * Resources.tile_size,
					(tile_position.y - y) * Resources.tile_size))
	if Debug.debug_map_tilemap:
		Debug.save_to_desktop(debug_image, "Map-" + map_name + ".png")

func create_object(parent: Node2D, sobj_index: int, location: Vector2i) -> void:
	var sobj: SObj = sobj_renderer.sobj.objects[sobj_index]
	var sobj_height := sobj.height

	var obj_sprite := SObjSprite.new(sobj_index)

	obj_sprite.position.x = location.x * Resources.tile_size
	obj_sprite.offset.y = -(sobj_height) * Resources.tile_size
	obj_sprite.position.y = ((location.y - sobj_height + 1) * Resources.tile_size) - obj_sprite.offset.y

	mutex.lock()
	parent.objects.add_child(obj_sprite)
	mutex.unlock()

func render_object(thread_index: int) -> void:
	var sobj_index: int = thread_ids[thread_index]
	sobj_renderer.render_object(sobj_index)

func create_objects(parent: Node2D, map_path: String, x: int, y: int, width: int, height: int) -> void:
	var start_i: int = max(0, (y * cmp.width) + (x % cmp.width))
	var end_i: int = min(len(cmp.tiles), ((y + height) * cmp.width) + ((x + cmp.width) % cmp.width))
	var map_area := Rect2i(x, y, width, height)
	
	# Collect Unique Objects
	thread_ids.clear()
	for i in range(start_i, end_i):
		var tile_position := Vector2i((i % cmp.width), (i / cmp.width))
		if not map_area.has_point(tile_position):
			continue
		var sobj_index := cmp.tiles[i].sobj_index
		if sobj_index < 1:
			continue
		var sobj: SObj = sobj_renderer.sobj.objects[sobj_index]
		var sobj_height := sobj.height
		if sobj_height < 1:
			continue
		# Add Unique SObjs
		if sobj_index not in thread_ids:
			thread_ids.append(sobj_index)
	
	# Threaded Object Renderering
	var task_id : int = WorkerThreadPool.add_group_task(render_object, thread_ids.size(), -1, true)
	WorkerThreadPool.wait_for_group_task_completion(task_id)

	parent.clear_objects()
	for i in range(start_i, end_i):
		var tile_position := Vector2i((i % cmp.width), (i / cmp.width))
		if not map_area.has_point(tile_position):
			continue
		var sobj_index := cmp.tiles[i].sobj_index
		if sobj_index < 1:
			continue
		var sobj: SObj = sobj_renderer.sobj.objects[sobj_index]
		var sobj_height := sobj.height
		if sobj_height < 1:
			continue
		create_object(parent, sobj_index, tile_position)
