extends Panel

@onready var page_spin_box: SpinBox = $VBoxContainer/PageNumberContainer/SpinBox

var parent: Node2D

func _ready() -> void:
	page_spin_box.select_all_on_focus = true

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("escape"):
		_on_close_button_pressed()

func set_parent(new_parent: Node2D) -> void:
	self.parent = new_parent

func _on_close_button_pressed():
	visible = false
	parent.set_menu_closed()

func _on_spin_box_value_changed(new_page_number):
	parent._goto_page(new_page_number - 1)
	visible = false
	parent.set_menu_closed()
