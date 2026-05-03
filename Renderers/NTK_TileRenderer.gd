class_name NTK_TileRenderer extends NTK_Renderer

var tbl: TileTblFileHandler

func _numeric_sort(a: String, b: String) -> bool:
	if int(a.replace("tile", "").replace("c", "").replace(".dat", "")) \
		< int(b.replace("tile", "").replace("c", "").replace(".dat", "")):
		return true
	return false

func _init(tile_regex="tile\\d+\\.dat", tile_pal="tile.pal", tile_tbl="tile.tbl"):
	var start_time: int = Time.get_ticks_msec()
	var ntk_data_directory := DirAccess.open(Resources.data_dir)

	# EPFs
	var tileDatRegex: RegEx = RegEx.new()
	tileDatRegex.compile(tile_regex)

	var files: Array[String] = []
	for file_name in ntk_data_directory.get_files():
		var result := tileDatRegex.search(file_name)
		if result:
			files.append(file_name)
	files.sort_custom(_numeric_sort)
	for file_name in files:
		epfs.append(EpfFileHandler.new(DatFileHandler.new(file_name).get_file(file_name.replace("dat", "epf"))))

	var tile_dat := DatFileHandler.new("tile.dat")
	pal = PalFileHandler.new(tile_dat.get_file(tile_pal))
	tbl = TileTblFileHandler.new(tile_dat.get_file(tile_tbl))
	
	if Debug.debug_renderer_timings:
		var tile_prefix = tile_tbl.to_lower().replace(".tbl", "")
		print("[TileRenderer]: [", tile_prefix, "]: ", Time.get_ticks_msec() - start_time, " ms")
