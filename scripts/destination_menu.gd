extends CanvasLayer
class_name DestinationMenu

signal destination_selected(destination: String)
signal cancelled

var _buttons: Array = []

func _get_joystick():
	return get_tree().get_first_node_in_group("joystick")

func show_menu() -> void:
	visible = true
	var joy = _get_joystick()
	if joy:
		joy.set_enabled(false)

func hide_menu() -> void:
	visible = false
	var joy = _get_joystick()
	if joy:
		joy.set_enabled(true)

func _ready() -> void:
	add_to_group("destination_menu")
	$Panel/VBoxContainer/Cancelar.pressed.connect(func(): hide_menu(); emit_signal("cancelled"))

func setup(from_island: String) -> void:
	$Panel/VBoxContainer/ContextLabel.text = "Zarpando desde: " + from_island
	var hp_text := "Barco: " + str(GameManager.ship_hp) + "/" + str(GameManager.ship_hp_max) + " HP"
	$Panel/VBoxContainer/Label.text = "Selecciona destino\n" + hp_text
	_setup_button($Panel/VBoxContainer/Isla1, "Isla Enana", "isla_norte", 10)
	_setup_button($Panel/VBoxContainer/Isla2, "Isla del Cocinero", "isla_este", 15)
	_setup_button($Panel/VBoxContainer/PuertoNeutral, "Puerto Loguetown", "puerto_neutral", 20)
	_setup_button($Panel/VBoxContainer/Cancelar, "", "", 0)

func _setup_button(btn: Button, island_name: String, destination: String, cost: int) -> void:
	if destination == "":
		return
	var can_afford: bool = GameManager.doblones >= cost
	var hp_ok: bool = GameManager.ship_hp > 0
	btn.text = island_name + "  (" + str(cost) + " D)"
	btn.disabled = not can_afford or not hp_ok
	if not can_afford:
		btn.text += " — sin doblones"
	elif not hp_ok:
		btn.text += " — barco destruido"
	if btn.pressed.get_connections().size() > 0:
		btn.pressed.disconnect(btn.pressed.get_connections()[0].callable)
	btn.pressed.connect(func(): hide_menu(); emit_signal("destination_selected", destination))
	_buttons.append({"btn": btn, "destination": destination})

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
	if $Panel/VBoxContainer/Cancelar.get_global_rect().has_point(pos):
		hide_menu()
		emit_signal("cancelled")
		return
	for item in _buttons:
		var btn: Button = item["btn"]
		if not btn.disabled and btn.get_global_rect().has_point(pos):
			hide_menu()
			emit_signal("destination_selected", item["destination"])
			return