class_name MapFileHandler extends BaseMapFileHandler

func _init(file_path):
	super(file_path)

	var file_position: int = file_offset

	width = decode_u16_be(file_position)
	file_position += 2
	height = decode_u16_be(file_position)
	file_position += 2

	var includes_passable_tiles: bool = false
	var data_length: int = file_size - 4;
	if (width * height * 6) == data_length:
		includes_passable_tiles = true

	var tile_size: int = 6 if includes_passable_tiles else 4
	var tile_count: int = data_length / tile_size
	tiles.resize(tile_count)
	for i in range(tile_count):
		var idx: int = i * tile_size
		var ab_index: int = decode_u16_be(file_position + idx)
		var unpassable_tile: bool = bool(decode_u16_be(file_position + idx + 2)) if includes_passable_tiles else false
		var sobj_offset: int = 4 if includes_passable_tiles else 2
		var sobj_index: int = decode_u16_be(file_position + idx + sobj_offset) - 1
		tiles[i] = MapTile.new(
			ab_index,
			unpassable_tile,
			sobj_index,
		)
