class_name DatFile extends Node

var file_name: String
var source_file_bytes: PackedByteArray
var file_data_offset: int
var file_data_length: int
var start_data_location: int
var end_data_location: int
var size: int

func _init(
		p_file_name: String,
		p_source_file_bytes: PackedByteArray,
		p_file_data_offset: int,
		p_file_data_length: int,
		p_start_data_location: int,
		p_end_data_location: int,
		p_size: int) -> void:
	self.file_name = p_file_name
	self.source_file_bytes = p_source_file_bytes
	self.file_data_offset = p_file_data_offset
	self.file_data_length = p_file_data_length
	self.start_data_location = p_start_data_location
	self.end_data_location = p_end_data_location
	self.size = p_size
