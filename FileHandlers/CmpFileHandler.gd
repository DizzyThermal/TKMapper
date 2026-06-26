class_name CmpFileHandler extends BaseMapFileHandler

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
		tiles[i] = MapTile.new(
			map_data.decode_u16(idx),
			bool(map_data.decode_u16(idx + 2)),
			map_data.decode_u16(idx + 4) - 1
		)
