class_name NTK_Cursor extends Node

const NTK_Frame = preload("res://DataTypes/NTK_Frame.gd")
const Palette = preload("res://DataTypes/Palette.gd")

const cursor_frame_count: int = 9
const cursor_frame_delay: float = 0.15

enum CursorState {
	IDLE = 0,
	SELECT = 1,
	INSPECT = 2,
	GRAB = 3,
	ATTACK = 4,
}

var cursor_renderer: NTK_Renderer

func _init():
	var bint0_dat := DatFileHandler.new("bint0.dat")

	self.cursor_renderer = NTK_Renderer.new()
	self.cursor_renderer.epfs.append(EpfFileHandler.new(bint0_dat.get_file("CURSOR02.epf")))
	self.cursor_renderer.pal = PalFileHandler.new(bint0_dat.get_file("CURSOR02.pal"))

func get_cursor_frame_sprite(cursor_state: CursorState) -> FrameSprite:
	var cursor_frame_index: int = (GameState.cursor_animation_tick % cursor_frame_count) + (int(cursor_state) * cursor_frame_count)
	var frame: NTK_Frame = self.cursor_renderer.get_frame(cursor_frame_index)
	var palette: Palette = self.cursor_renderer.pal.get_palette(0)
	var frame_key: String = "-".join(["Cursor", cursor_frame_index])
	var cursor_frame_sprite: FrameSprite = FrameSprite.new(frame_key, frame, palette)
	cursor_frame_sprite.set_meta("frame_index", cursor_frame_index)
	cursor_frame_sprite.z_index = 3

	return cursor_frame_sprite
