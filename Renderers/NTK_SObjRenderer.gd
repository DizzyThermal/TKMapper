class_name NTK_SObjRenderer extends Node

var tilec_renderer: NTK_TileRenderer
var sobj: SObjTblFileHandler

func _init():
	var start_time := Time.get_ticks_msec()

	self.tilec_renderer = NTK_TileRenderer.new("tilec\\d+\\.dat", "TileC.pal", "TILEC.TBL")
	self.sobj = SObjTblFileHandler.new(DatFileHandler.new("tile.dat").get_file("SObj.tbl"))

	if Debug.debug_renderer_timings:
		print("[SObjRenderer]: ", Time.get_ticks_msec() - start_time, " ms")
