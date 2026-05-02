class_name NTK_MapRenderer extends Node

const CmpFileHandler = preload("res://FileHandlers/CmpFileHandler.gd")
const Palette = preload("res://DataTypes/Palette.gd")
const SObj = preload("res://DataTypes/SObj.gd")
const NTK_Frame = preload("res://DataTypes/NTK_Frame.gd")

var tile_renderer: NTK_TileRenderer = null
var sobj_renderer: NTK_SObjRenderer = null

var cmp: CmpFileHandler = null
var thread_ids: Array[int] = []

var tiles: Node2D
var tile_locations: Dictionary[Vector2i, FrameSprite] = {}

var objects: Node2D
var object_locations: Dictionary[Vector2i, Node2D] = {}

var tile_collision: Dictionary[Vector2i, int] = {}

#var mutex: Mutex = Mutex.new()

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
	cmp = CmpFileHandler.new(map_path)

func render_map(map_path: String, render_objects: bool) -> void:
	_load_map(map_path)
	render_map_cropped(map_path, 0, 0, cmp.width, cmp.height, render_objects)

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
	create_tilemap(x, y, width, height, submap)
	var map_name: String = get_map_name(map_path)
	if Debug.debug_renderer_timings:
		print("[", map_name, "]: Create TileMap: ", Time.get_ticks_msec() - tilemap_start_time, " ms")

	if render_objects:
		# Create Objects (Static Objects)
		var objects_start_time := Time.get_ticks_msec()
		create_objects(x, y, width, height, submap)
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
	delete_tile(tile_coordinate)
	if ab_index > 0:
		var palette_index: int = tile_renderer.tbl.palette_indices[ab_index]
		var tile_sprite: FrameSprite = create_tile_sprite(ab_index, palette_index)
		tile_sprite.position = tile_coordinate * Resources.tile_size_vector
		self.tile_locations[tile_coordinate] = tile_sprite
		self.tiles.add_child(tile_sprite)

func create_tilemap(x: int, y: int, width: int, height: int, submap: bool=false) -> void:
	var start_i: int = 0 if submap else max(0, (y * cmp.width) + (x % cmp.width))
	var end_i: int = len(cmp.tiles) if submap else min(len(cmp.tiles), ((y + height) * cmp.width) + ((x + cmp.width) % cmp.width))
	for i in range(start_i, end_i):
		var ab_index: int = cmp.tiles[i].ab_index
		var tile_coordinate: Vector2i = Vector2i((i % cmp.width), (i / cmp.width))
		if submap:
			tile_coordinate += Vector2i(x, y)
		var frame = tile_renderer.get_frame(ab_index)
		if ab_index == 0 or \
				frame.width <= 0 or \
				frame.height <= 0:
			continue
		update_tile(ab_index, tile_coordinate)
		# Tile Collision
		if cmp.tiles[i].unpassable_tile:
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
	var sobj_height: int = sobj.height
	for idx in range(len(sobj.tile_indices)):
		var tile_index: int = sobj.tile_indices[idx]
		var palette_index: int = sobj_renderer.tilec_renderer.tbl.palette_indices[tile_index]
		var tilec_sprite: FrameSprite = create_tilec_sprite(tile_index, palette_index)
		tilec_sprite.y_sort_enabled = true
		tilec_sprite.offset = -(idx + 1) * Vector2i(0, Resources.tile_size) + tilec_sprite.ntk_frame.pivot + Vector2i(0, Resources.tile_size)
		tilec_sprite.position = Vector2i(0, -Resources.tile_size)
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
	var sobj_height := sobj.height
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
	delete_object(object_coordinate)
	if sobj_index >= 1:
		var sobj: SObj = sobj_renderer.sobj.objects[sobj_index]
		var sobj_height := sobj.height
		if sobj_height >= 1:
			var object_node: Node2D = create_object_sprite(sobj_index)
			object_node.position = (object_coordinate + Vector2i(0, 1)) * Resources.tile_size_vector
			self.object_locations[object_coordinate] = object_node
			self.objects.add_child(object_node)

func create_objects(x: int, y: int, width: int, height: int, submap: bool=false) -> void:
	var start_i: int = 0 if submap else max(0, (y * cmp.width) + (x % cmp.width))
	var end_i: int = len(cmp.tiles) if submap else min(len(cmp.tiles), ((y + height) * cmp.width) + ((x + cmp.width) % cmp.width))

	for i in range(start_i, end_i):
		var sobj_index := cmp.tiles[i].sobj_index
		var object_coordinate: Vector2i = Vector2i((i % cmp.width), (i / cmp.width))
		if submap:
			object_coordinate += Vector2i(x, y)
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
