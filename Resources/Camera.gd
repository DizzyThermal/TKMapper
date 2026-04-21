extends Camera2D

var mouse_start_pos
var screen_start_position

var dragging = false

var zoom_step = 2.0
var min_zoom = 0.125
var max_zoom = 4

func _input(event):
	if event.is_action("move-map"):
		if event.is_pressed():
			mouse_start_pos = event.position
			screen_start_position = position
			dragging = true
		else:
			dragging = false
	elif event is InputEventMouseMotion and dragging:
		position = (Vector2(1, 1) / zoom) * (mouse_start_pos - event.position) + screen_start_position
