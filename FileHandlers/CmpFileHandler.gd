class_name CmpFileHandler extends NTK_FileHandler

var map_name: String = ""
var width: int = 0
var height: int = 0
var tiles: Array[CmpTile] = []

func _init(file_path):
	super(file_path)

	var file_position: int = file_offset + 4  # CMAP

	var dims: int = file_bytes.decode_u32(file_position)
	file_position += 4
	self.width = dims & 0x0000FFFF
	self.height = dims >> 0x10

	var compressed_data: PackedByteArray = file_bytes.slice(
		file_position,
		file_position + file_size - 4
	)
	file_position += file_size - 4
	var map_data: PackedByteArray = compressed_data.decompress_dynamic(width * height * 6, FileAccess.COMPRESSION_DEFLATE)

	var tile_count: int = len(map_data) / 6
	tiles.resize(tile_count)
	for i in range(tile_count):
		var idx := (i * 6)
		tiles[i] = CmpTile.new(
			map_data.decode_u16(idx),
			bool(map_data.decode_u16(idx + 2)),
			map_data.decode_u16(idx + 4) - 1
		)

func update_map(map_width: int, map_height: int, map_tiles: Array) -> void:
	tiles.clear()
	self.width = map_width
	self.height = map_height
	for y in range(self.height):
		for x in range(self.width):
			tiles.append(CmpTile.new(
				map_tiles[y][x]["ab_index"],
				int(map_tiles[y][x]["unpassable"]),
				map_tiles[y][x]["sobj_index"],
			))

func save_to_file(file_path: String) -> void:
	if DirAccess.dir_exists_absolute(file_path):
		DirAccess.remove_absolute(file_path)

	var map_file_access := FileAccess.open(file_path, FileAccess.ModeFlags.WRITE)
	
	map_file_access.store_8(67)	# C
	map_file_access.store_8(77)	# M
	map_file_access.store_8(65)	# A
	map_file_access.store_8(80)	# P

	# Dimensions
	map_file_access.store_16(self.width)
	map_file_access.store_16(self.height)

	# Collect Map Data
	var map_data: PackedByteArray = PackedByteArray()
	map_data.resize(len(tiles) * 6)
	var map_data_pointer := 0
	for tile in tiles:
		map_data.encode_u16(map_data_pointer, max(tile.ab_index, 0))
		map_data.encode_u16(map_data_pointer + 2, int(tile.unpassable_tile))
		map_data.encode_u16(map_data_pointer + 4, tile.sobj_index + 1)
		map_data_pointer += 6

	# Deflate Map Data
	var compressed_map_data := map_data.compress(FileAccess.COMPRESSION_DEFLATE)
	map_file_access.store_buffer(compressed_map_data)

	map_file_access.flush()
	map_file_access.close()
