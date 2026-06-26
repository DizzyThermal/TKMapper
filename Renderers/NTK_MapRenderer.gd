class_name NTK_MapRenderer extends Node

var tile_renderer: NTK_TileRenderer
var sobj_renderer: NTK_SObjRenderer

var map: BaseMapFileHandler
var thread_ids: Array[int] = []

var tiles: Node2D
var tile_locations: Dictionary[Vector2i, FrameSprite] = {}

var objects: Node2D
var object_locations: Dictionary[Vector2i, Node2D] = {}

var tile_collision: Dictionary[Vector2i, int] = {}

func _init(src_tiles: Node2D=null, src_objects: Node2D=null):
	var start_time := Time.get_ticks_msec()

	self.tiles = src_tiles
	self.objects = src_objects

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
	if map_path.ends_with('cmp'):
		map = CmpFileHandler.new(map_path)
	elif map_path.ends_with('map'):
		map = MapFileHandler.new(map_path)

func render_map(map_path: String, render_objects: bool) -> void:
	_load_map(map_path)
	render_map_cropped(map_path, 0, 0, map.width, map.height, render_objects)

func render_submap(map_path: String, location: Rect2i) -> void:
	render_map_cropped(map_path, location.position.x, location.position.y, location.size.x, location.size.y, true, true)

func render_map_cropped(map_path: String, x: int, y: int, width: int, height: int, render_objects: bool=true, submap: bool=false) -> void:
	if not submap:
		self.clear_map()

	var start_time := Time.get_ticks_msec()
	_load_map(map_path)
	if width == 0 or height == 0:
		x = 0
		y = 0
		width = map.width
		height = map.height
	else:
		# Crop and adjust width/height if x/y are negative
		width = min(width, map.width) if x >= 0 else width - x
		height = min(height, map.height) if y >= 0 else height - y
		x = x if x >= 0 else 0
		y = y if y >= 0 else 0

	# Render Map
	for local_y in range(height):
		for local_x in range(width):
			var source_x: int = x + local_x if not submap else local_x
			var source_y: int = y + local_y if not submap else local_y
			var dest_x: int = x + local_x
			var dest_y: int = y + local_y

			if source_x < 0 or source_y < 0 or \
					source_x >= map.width or source_y >= map.height:
				continue

			var tile_idx: int = (source_y * map.width) + source_x
			var tile_data = map.tiles[tile_idx]
			var coordinate: Vector2i = Vector2i(dest_x, dest_y)
			# Tile
			var ab_index: int = tile_data.ab_index
			if ab_index != 0:
				var frame = tile_renderer.get_frame(ab_index)
				if frame.width > 0 and frame.height > 0:
					_create_tile_direct(ab_index, coordinate)
					if tile_data.unpassable_tile:
						tile_collision[coordinate] = 0xF
			# Static Object
			var sobj_index: int = tile_data.sobj_index
			if sobj_index >= 1:
				_create_object_direct(sobj_index, coordinate)
				var sobj_collision: int = sobj_renderer.sobj.objects[sobj_index].collision
				if coordinate in tile_collision and sobj_collision > tile_collision[coordinate]:
					tile_collision[coordinate] = sobj_collision

func _create_tile_direct(
		ab_index: int,
		coordinate: Vector2i) -> void:
	var palette_index: int = tile_renderer.tbl.palette_indices[ab_index]
	var tile_sprite: FrameSprite = create_tile_sprite(ab_index, palette_index)
	tile_sprite.position = coordinate * Resources.tile_size_vector
	self.tile_locations[coordinate] = tile_sprite
	self.tiles.add_child(tile_sprite)

func _create_object_direct(
		sobj_index: int,
		coordinate: Vector2i) -> void:
	var sobj: SObj = sobj_renderer.sobj.objects[sobj_index]
	if sobj.height < 1:
		return
	var object_node: Node2D = create_object_sprite(sobj_index)
	object_node.position = (coordinate + Vector2i(0, 1)) * Resources.tile_size_vector
	self.object_locations[coordinate] = object_node
	self.objects.add_child(object_node)

func update_map_tiles(
		tiles_to_update: Array[Vector2i],
		tiles_to_clear: Array[Vector2i]=[]) -> void:
	for coordinate in tiles_to_update:
		if coordinate.x < 0 or \
				coordinate.y < 0 or \
				coordinate.x >= map.width or \
				coordinate.y >= map.height:
			continue
		# Tile
		var tile_idx: int = (coordinate.y * map.width) + coordinate.x
		var ab_index: int = map.tiles[tile_idx].ab_index
		var frame = tile_renderer.get_frame(ab_index)
		if ab_index == 0 or frame.width <= 0 or frame.height <= 0:
			continue
		update_tile(ab_index, coordinate)
		# Tile Collision
		if map.tiles[tile_idx].unpassable_tile:
			tile_collision[coordinate] = 0xF
		# Object
		var object_idx: int = (coordinate.y * map.width) + coordinate.x
		var sobj_index := map.tiles[object_idx].sobj_index
		update_object(sobj_index, coordinate)
		# Object Collision
		if sobj_index > 0:
			var sobj: SObj = sobj_renderer.sobj.objects[sobj_index]
			var sobj_collision: int = sobj_renderer.sobj.objects[sobj_index].collision
			if coordinate in tile_collision and \
					sobj_collision > tile_collision[coordinate]:
				tile_collision[coordinate] = sobj_collision
	for coordinate in tiles_to_clear:
		delete_tile(coordinate)
		delete_object(coordinate)
		tile_collision[coordinate] = 0x0

func get_map_tile_indices(tile_indices) -> Array:
	for i in range(len(map.tiles)):
		var tile := map.tiles[i]
		var x: int = i % map.width
		var y: int = i / map.width
		tile_indices[y][x]["ab_index"] = tile.ab_index
		tile_indices[y][x]["sobj_index"] = tile.sobj_index
		tile_indices[y][x]["unpassable_tile"] = tile.unpassable_tile

	return tile_indices

func get_tile_collision(coordinate: Vector2i) -> int:
	if not map:
		return 0x0

	var tile_index := (coordinate.y * map.width) + coordinate.x
	if tile_index < 0 or tile_index >= len(map.tiles):
		return 0xF

	var unpassable_tile := map.tiles[tile_index].unpassable_tile
	if unpassable_tile:
		return 0xF

	var sobj_index := map.tiles[tile_index].sobj_index
	if sobj_index < 0:
		return 0x0

	var sobj := sobj_renderer.sobj
	return sobj.objects[sobj_index].collision

func create_tile_sprite(ab_index: int, palette_index: int, cache_prefix="tile") -> FrameSprite:
	var frame: NTK_Frame = tile_renderer.get_frame(ab_index)
	var palette: Palette = tile_renderer.pal.get_palette(palette_index)
	var tile_key: String = "-".join([cache_prefix, ab_index, palette_index])
	var tile_sprite: FrameSprite = FrameSprite.new(tile_key, frame, palette)
	tile_sprite.set_meta("ab_index", ab_index)
	tile_sprite.set_meta("palette_index", palette_index)

	return tile_sprite

func create_tile_texture_rect(ab_index: int, palette_index: int, cache_prefix="tile") -> FrameTextureRect:
	var frame: NTK_Frame = tile_renderer.get_frame(ab_index)
	var palette: Palette = tile_renderer.pal.get_palette(palette_index)
	var tile_key: String = "-".join([cache_prefix, ab_index, palette_index])
	var tile_texture_rect: FrameTextureRect = FrameTextureRect.new(tile_key, frame, palette)
	tile_texture_rect.set_meta("ab_index", ab_index)
	tile_texture_rect.set_meta("palette_index", palette_index)

	return tile_texture_rect

func delete_tile(tile_coordinate: Vector2i) -> void:
	if tile_coordinate in self.tile_locations:
		var tile: FrameSprite = self.tile_locations[tile_coordinate]
		if tile != null:
			tile.queue_free()
		self.tile_locations.erase(tile_coordinate)

func update_tile(ab_index: int, tile_coordinate: Vector2i) -> void:
	# If ab_index is the same, don't update
	if tile_coordinate in self.tile_locations and \
			self.tile_locations[tile_coordinate] != null:
		var tile_sprite: FrameSprite = self.tile_locations[tile_coordinate]
		if tile_sprite.get_meta("ab_index") == ab_index:
			return
	# Clear previous tile
	delete_tile(tile_coordinate)
	if ab_index > 0:
		var palette_index: int = tile_renderer.tbl.palette_indices[ab_index]
		var tile_sprite: FrameSprite = create_tile_sprite(ab_index, palette_index)
		tile_sprite.position = tile_coordinate * Resources.tile_size_vector
		self.tile_locations[tile_coordinate] = tile_sprite
		self.tiles.add_child(tile_sprite)

func create_tilemap(x: int, y: int, width: int, height: int, submap: bool=false) -> void:
	for local_y in range(height):
		for local_x in range(width):
			var source_x: int = x + local_x
			var source_y: int = y + local_y
			var dest_x: int = source_x
			var dest_y: int = source_y
			if submap:
				source_x = local_x
				source_y = local_y
				dest_x = x + local_x
				dest_y = y + local_y
			if source_x < 0 or \
					source_y < 0 or \
					source_x >= map.width or \
					source_y >= map.height:
				continue
			var tile_idx: int = (source_y * map.width) + source_x
			var ab_index: int = map.tiles[tile_idx].ab_index
			var tile_coordinate: Vector2i = Vector2i(dest_x, dest_y)
			var frame = tile_renderer.get_frame(ab_index)
			if ab_index == 0 or frame.width <= 0 or frame.height <= 0:
				continue
			update_tile(ab_index, tile_coordinate)
			# Tile Collision
			if map.tiles[tile_idx].unpassable_tile:
				tile_collision[tile_coordinate] = 0xF

func create_tilec_sprite(ab_index: int, palette_index: int, cache_prefix="tilec") -> FrameSprite:
	var frame: NTK_Frame = sobj_renderer.tilec_renderer.get_frame(ab_index)
	var palette: Palette = sobj_renderer.tilec_renderer.pal.get_palette(palette_index)
	var tile_key: String = "-".join([cache_prefix, ab_index, palette_index])
	var tilec_sprite: FrameSprite = FrameSprite.new(tile_key, frame, palette)
	tilec_sprite.set_meta("ab_index", ab_index)
	tilec_sprite.set_meta("palette_index", palette_index)

	return tilec_sprite

func create_object_sprite(sobj_index: int) -> Node2D:
	var object: Node2D = Node2D.new()
	object.y_sort_enabled = true
	var sobj: SObj = sobj_renderer.sobj.objects[sobj_index]
	for idx in range(len(sobj.tile_indices)):
		var tile_index: int = sobj.tile_indices[idx]
		var palette_index: int = sobj_renderer.tilec_renderer.tbl.palette_indices[tile_index]
		var tilec_sprite: FrameSprite = create_tilec_sprite(tile_index, palette_index)
		tilec_sprite.y_sort_enabled = true
		tilec_sprite.offset = -(idx + 1) * Vector2i(0, Resources.tile_size) + tilec_sprite.ntk_frame.pivot # + Vector2i(0, Resources.tile_size / 2)
		object.add_child(tilec_sprite)
	object.set_meta("sobj_index", sobj_index)

	return object

func create_object_texture_rect(ab_index: int, palette_index: int, cache_prefix="tilec") -> FrameTextureRect:
	var frame: NTK_Frame = sobj_renderer.tilec_renderer.get_frame(ab_index)
	var palette: Palette = sobj_renderer.tilec_renderer.pal.get_palette(palette_index)
	var tile_key: String = "-".join([cache_prefix, ab_index, palette_index])
	var tile_texture_rect: FrameTextureRect = FrameTextureRect.new(tile_key, frame, palette)
	tile_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP
	tile_texture_rect.set_meta("ab_index", ab_index)
	tile_texture_rect.set_meta("palette_index", palette_index)

	return tile_texture_rect

func create_object_texture(sobj_index: int) -> VBoxContainer:
	var container: VBoxContainer = VBoxContainer.new()
	container.add_theme_constant_override("separation", 0)
	var sobj: SObj = sobj_renderer.sobj.objects[sobj_index]
	for idx in range(len(sobj.tile_indices)):
		var tile_index: int = sobj.tile_indices[idx]
		var palette_index: int = sobj_renderer.tilec_renderer.tbl.palette_indices[tile_index]
		var frame: NTK_Frame = sobj_renderer.tilec_renderer.get_frame(tile_index)
		var tilec_texture_rect: FrameTextureRect = create_object_texture_rect(tile_index, palette_index)
		var tilec_margin_container: MarginContainer = MarginContainer.new()
		tilec_margin_container.custom_minimum_size = Resources.tile_size_vector
		tilec_margin_container.add_theme_constant_override("margin_top", frame.top)
		tilec_margin_container.add_theme_constant_override("margin_left", frame.left)
		tilec_margin_container.add_child(tilec_texture_rect)
		container.add_child(tilec_margin_container)
		container.move_child(tilec_margin_container, 0)
	container.set_meta("sobj_index", sobj_index)

	return container

func delete_object(object_coordinate: Vector2i) -> void:
	if object_coordinate in self.object_locations:
		var object: Node2D = self.object_locations[object_coordinate]
		if object != null:
			object.queue_free()
		self.object_locations.erase(object_coordinate)

func update_object(sobj_index: int, object_coordinate: Vector2i) -> void:
	# If ab_index is the same, don't update
	if object_coordinate in self.object_locations and \
			self.object_locations[object_coordinate] != null:
		var object_node: Node2D = self.object_locations[object_coordinate]
		if object_node.get_meta("sobj_index") == sobj_index:
			return
	delete_object(object_coordinate)
	if sobj_index >= 1:
		var sobj: SObj = sobj_renderer.sobj.objects[sobj_index]
		var sobj_height := sobj.height
		if sobj_height >= 1:
			var object_node: Node2D = create_object_sprite(sobj_index)
			#object_node.position = object_coordinate * Resources.tile_size_vector + Vector2i(0, Resources.tile_size / 2)
			object_node.position = (object_coordinate + Vector2i(0, 1)) * Resources.tile_size_vector
			self.object_locations[object_coordinate] = object_node
			self.objects.add_child(object_node)

func create_objects(x: int, y: int, width: int, height: int, submap: bool=false) -> void:
	for local_y in range(height):
		for local_x in range(width):
			var source_x: int = x + local_x
			var source_y: int = y + local_y
			var dest_x: int = source_x
			var dest_y: int = source_y
			if submap:
				source_x = local_x
				source_y = local_y
				dest_x = x + local_x
				dest_y = y + local_y
			if source_x < 0 or \
					source_y < 0 or \
					source_x >= map.width or \
					source_y >= map.height:
				continue
			var object_idx: int = (source_y * map.width) + source_x
			var object_coordinate: Vector2i = Vector2i(dest_x, dest_y)
			var sobj_index: int = map.tiles[object_idx].sobj_index
			update_object(sobj_index, object_coordinate)
			# Object Collision
			if sobj_index > 0:
				var sobj: SObj = sobj_renderer.sobj.objects[sobj_index]
				var sobj_collision: int = sobj_renderer.sobj.objects[sobj_index].collision
				if object_coordinate in tile_collision and \
						sobj_collision > tile_collision[object_coordinate]:
					tile_collision[object_coordinate] = sobj_collision

func clear_tiles() -> void:
	if self.tiles != null and \
			self.tiles.get_child_count() > 0:
		for tile in self.tiles.get_children():
			tile.queue_free()
	self.tile_locations.clear()

func clear_objects() -> void:
	if self.objects != null and \
			self.objects.get_child_count() > 0:
		for object in self.objects.get_children():
			object.queue_free()

func clear_map() -> void:
	self.clear_tiles()
	self.clear_objects()
