class_name SObjTblFileHandler extends NTK_FileHandler

var TBL_MASK: int = 0x7F

var object_count: int = 0
var objects: Dictionary[int, SObj] = {}

func _init(file):
	super(file)
	
	var file_position: int = file_offset
	object_count = file_bytes.decode_u32(file_position)
	file_position += 4
	
	var _unknown_short: int = file_bytes.decode_u16(file_position)
	file_position += 2
	
	# Objects
	for i in range(object_count):
		# _unknown_bytes[5]
		file_position += 5
		var collision: int = file_bytes[file_position]
		file_position += 1
		var height: int = file_bytes[file_position]
		file_position += 1
		var tile_indices: Array[int] = []
		for j in range(height):
			tile_indices.append(
				file_bytes[file_position] | \
				(file_bytes[file_position + 1] << 8)
			)
			file_position += 2
		objects[i] = SObj.new(collision, height, tile_indices)
