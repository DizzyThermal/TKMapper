extends Node

var tile_size := 48
var tile_size_vector := Vector2i(tile_size, tile_size)
var tile_rect := Rect2i(0, 0, tile_size, tile_size)
var palette_color_count := 256

var config_path := "res://config.json"
var game_db_path := "res://game.db"

var data_dir := ""
var map_dir := ""
var local_map_dir := "res://Maps"
var mnm_dir := ""
var desktop_dir := ""

# Test Map (Maps/TK010000.cmp)
var start_map_id: int = 10000

# TODO: See if this is problematic for future items
var offset_range: Array[int] = []

enum EntityType {
	Player,
	Monster,
	NPC,
}

enum Totem {
	JUJAK = 0,
	BAEKHO = 1,
	HYUNMOO = 2,
	CHUNGRYONG = 3,
}

enum Gender {
	MALE = 0,
	FEMALE = 1,
}

func _init():
	if not ResourceLoader.exists(config_path):
		var template_config := FileAccess.open("res://config.json.template", FileAccess.READ)
		var config := FileAccess.open("res://config.json", FileAccess.WRITE)
		config.store_string(template_config.get_as_text())
		config.flush()
		config.close()
		template_config.close()

	if OS.get_name() == "Windows":
		desktop_dir = OS.get_environment("USERPROFILE") + "/Desktop/"
	else:
		desktop_dir = OS.get_environment("HOME") + "/Desktop/"

	var config_file := FileAccess.open(config_path, FileAccess.READ)
	var config_json = JSON.parse_string(config_file.get_as_text())

	var home_dir := OS.get_environment("HOME") if OS.get_environment("HOME") else OS.get_environment("USERPROFILE")
	self.data_dir = config_json.data_dir.replace("\\", "/").replace("${HOME}", home_dir)
	self.map_dir = config_json.map_dir.replace("\\", "/").replace("${HOME}", home_dir)
	self.mnm_dir = config_json.mnm_dir.replace("\\", "/").replace("${HOME}", home_dir)
	self.start_map_id = config_json.start_map_id

	# Check NTK Data Directory
	if not FileAccess.file_exists(self.data_dir + "/tile.dat"):
		print("'", self.data_dir, "' is an invalid NTK data directory")
		OS.kill(OS.get_process_id())

	# Check NTK Map Directory
	if not FileAccess.file_exists(self.map_dir + "/TK000000.cmp"):
		print("'", self.map_dir, "' is an invalid NTK map directory")
		OS.kill(OS.get_process_id())
	
	# Generate Offset Range
	for i in range(48, 144):
		offset_range.append(i)
	for i in range(176, 256):
		offset_range.append(i)

static func arrays_intersect(
		array_1: Array[int],
		array_2: Array[int]) -> bool:
	var intersected := false

	for item in array_1:
		if item in array_2:
			intersected = true
			break
	
	return intersected
