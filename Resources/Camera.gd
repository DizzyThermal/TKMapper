extends Camera2D

var mouse_start_pos
var screen_start_position

var dragging = false

var min_zoom = 0.1
var max_zoom = 2

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
