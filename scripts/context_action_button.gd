extends CanvasLayer

signal action_pressed

@onready var button: Button = $Button

func _ready() -> void:
	add_to_group("context_button")
	button.visible = false
	button.pressed.connect(func(): emit_signal("action_pressed"))

func _input(event: InputEvent) -> void:
	if not button.visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		var btn_rect := button.get_global_rect()
		if btn_rect.has_point(event.position):
			emit_signal("action_pressed")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var btn_rect := button.get_global_rect()
		if btn_rect.has_point(event.position):
			emit_signal("action_pressed")
			get_viewport().set_input_as_handled()

func show_action(text: String) -> void:
	button.text = text
	button.visible = true

func hide_action() -> void:
	button.visible = false