class_name NTK_FileHandler extends Node

var file_bytes: PackedByteArray
var file_offset: int
var file_size: int

func _init(file, data_directory=Resources.data_dir):
	if file is DatFile:
		file_bytes = file.source_file_bytes
		file_offset = file.file_data_offset
		file_size = file.file_data_length
	elif file is PackedByteArray:
		file_bytes = file
		file_offset = 0
		file_size = len(file_bytes)
	elif "/" in file or "\\" in file:
		file_bytes = FileAccess.get_file_as_bytes(file)
		file_offset = 0
		file_size = len(file_bytes)
	else:
		file_bytes = FileAccess.get_file_as_bytes(data_directory + "/" + file)
		file_offset = 0
		file_size = len(file_bytes)

func read_utf8(file_position: int, length: int) -> String:
	var byte_slice := file_bytes.slice(
		file_position,
		file_position + length)

	return byte_slice.get_string_from_utf8()

func read_utf16(file_position: int, length: int) -> String:
	var byte_slice := file_bytes.slice(
		file_position,
		file_position + (length * 2))
	
	return byte_slice.get_string_from_utf16()
