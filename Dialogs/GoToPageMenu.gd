extends Panel

@onready var page_spin_box: SpinBox = $VBoxContainer/PageNumberContainer/SpinBox

var parent: Node2D

func set_parent(new_parent: Node2D) -> void:
	self.parent = new_parent

func _on_close_button_pressed():
	visible = false
	MapperState.menu_open = false

func _on_spin_box_value_changed(new_page_number):
	parent._goto_page(new_page_number - 1)
	visible = false
	MapperState.menu_open = false
