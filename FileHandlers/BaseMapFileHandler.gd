class_name BaseMapFileHandler extends NTK_FileHandler

var map_name: String = ""
var width: int = 0
var height: int = 0
var tiles: Array[MapTile] = []

func _init(file_path):
	super(file_path)

func update_map(map_width: int, map_height: int, map_tiles: Array) -> void:
	tiles.clear()
	self.width = map_width
	self.height = map_height
	for y in range(self.height):
		for x in range(self.width):
			tiles.append(MapTile.new(
				map_tiles[y][x]["ab_index"],
				int(map_tiles[y][x]["unpassable"]),
				map_tiles[y][x]["sobj_index"],
			))

func save_to_file(
		file_path: String,
		compress: bool=true,
		include_passable_flag: bool=true) -> void:
	if DirAccess.dir_exists_absolute(file_path):
		DirAccess.remove_absolute(file_path)

	var map_file_access := FileAccess.open(file_path, FileAccess.ModeFlags.WRITE)

	if compress:
		map_file_access.store_8(67)	# C
		map_file_access.store_8(77)	# M
		map_file_access.store_8(65)	# A
		map_file_access.store_8(80)	# P

	# Dimensions
	map_file_access.store_16(self.width)
	map_file_access.store_16(self.height)

	# Collect Map Data
	var map_data: PackedByteArray = PackedByteArray()
	var tile_size: int = 6 if include_passable_flag else 4
	map_data.resize(len(tiles) * tile_size)
	var map_data_pointer := 0
	for tile in tiles:
		map_data.encode_u16(map_data_pointer, max(tile.ab_index, 0))
		if include_passable_flag:
			map_data.encode_u16(map_data_pointer + 2, int(tile.unpassable_tile))
		var sobj_offset: int = 4 if include_passable_flag else 2
		map_data.encode_u16(map_data_pointer + sobj_offset, tile.sobj_index + 1)
		map_data_pointer += tile_size

	if compress:
		# Deflate Map Data
		var compressed_map_data := map_data.compress(FileAccess.COMPRESSION_DEFLATE)
		map_file_access.store_buffer(compressed_map_data)
	else:
		map_file_access.store_buffer(map_data)

	map_file_access.flush()
	map_file_access.close()
