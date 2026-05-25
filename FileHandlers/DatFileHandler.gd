class_name DatFileHandler extends NTK_FileHandler

const HEADER: int = 4
const FILE_NAME_LENGTH: int = 12

var file_count: int = 0
var files: Dictionary[String, DatFile] = {}

func _init(file):
	super(file)
	var file_position: int = file_offset

	file_count = file_bytes.decode_u32(file_position) - 1
	file_position += 4

	for i in range(file_count):
		var start_data_location: int = file_bytes.decode_u32(file_position)
		file_position += 4
		var file_name: String = read_utf8(file_position, FILE_NAME_LENGTH)
		file_position += FILE_NAME_LENGTH
		var _unknown: int
		file_position += 1
		var next_file_position: int = file_position
		var end_data_location: int = file_bytes.decode_u32(file_position)
		file_position += 4
		var size: int = end_data_location - start_data_location
		file_position = start_data_location
		files[file_name.to_lower()] = DatFile.new(file_name, file_bytes, file_position, size, start_data_location, end_data_location, size)
		file_position = next_file_position

func contains_file(file_name: String) -> bool:
	return files.has(file_name.to_lower())

func get_file(file_name: String) -> DatFile:
	var dat_file: DatFile

	if files.has(file_name.to_lower()):
		dat_file = files[file_name.to_lower()]

	return dat_file

func get_file_names() -> Array[String]:
	return files.keys()
