class_name SObjSprite extends Sprite2D

var object_index: int

var palette_animation_last_tick := 0

func _init(object_index: int) -> void:
	self.object_index = object_index
	self.texture = Renderers.map_renderer.sobj_renderer.render_object(
		self.object_index, palette_animation_last_tick)
	self.centered = false
	self.y_sort_enabled = true
	self.z_index = 1
	self.z_as_relative = false

func _process(delta):
	if MapperState.palette_animation_tick != palette_animation_last_tick:
		palette_animation_last_tick = MapperState.palette_animation_tick
		self.texture = Renderers.map_renderer.sobj_renderer.render_object(
			self.object_index, palette_animation_last_tick)
