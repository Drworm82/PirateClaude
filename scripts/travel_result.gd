extends CanvasLayer

signal closed

func show_result(event: Dictionary) -> void:
	var delta: int = event.get("doblones_delta", 0)
	$Panel/Title.text = event.get("title", "")
	$Panel/Description.text = event.get("description", "")
	if delta > 0:
		$Panel/DoblonesLabel.text = "+" + str(delta) + " doblones"
		$Panel/DoblonesLabel.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	elif delta < 0:
		$Panel/DoblonesLabel.text = str(delta) + " doblones"
		$Panel/DoblonesLabel.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	else:
		$Panel/DoblonesLabel.text = "Sin cambios"
	$Panel/ContinuarBtn.pressed.connect(func(): emit_signal("closed"))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var pos: Vector2 = Vector2.ZERO
	var is_press: bool = false
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
		is_press = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		is_press = true
	if not is_press:
		return
	get_viewport().set_input_as_handled()
	if $Panel/ContinuarBtn.get_global_rect().has_point(pos):
		emit_signal("closed")