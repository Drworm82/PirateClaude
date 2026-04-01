extends CanvasLayer
class_name DestinationMenu

signal destination_selected(destination: String)
signal cancelled

func _ready() -> void:
	$Panel/Cancelar.pressed.connect(
		func(): emit_signal("cancelled"))

func setup(from_island: String) -> void:
	$Panel/ContextLabel.text = "Zarpando desde: " + from_island
	
	var hp_color := Color.RED if GameManager.ship_hp < 30 else Color.WHITE
	var hp_text := "Barco: " + str(GameManager.ship_hp) + "/" + str(GameManager.ship_hp_max) + " HP"
	$Panel/Label.text = "Selecciona destino\n" + hp_text
	
	_setup_button($Panel/VBoxContainer/Isla1, "Isla Enana", "isla_norte", 10)
	_setup_button($Panel/VBoxContainer/Isla2, "Isla del Cocinero", "isla_este", 15)
	_setup_button($Panel/VBoxContainer/PuertoNeutral, "Puerto Loguetown", "puerto_neutral", 20)

func _setup_button(btn: Button, island_name: String, destination: String, cost: int) -> void:
	var can_afford: bool = GameManager.doblones >= cost
	var hp_ok: bool = GameManager.ship_hp > 0
	
	btn.text = island_name + "  (" + str(cost) + " D)"
	btn.disabled = not can_afford or not hp_ok
	
	if not can_afford:
		btn.text += " — sin doblones"
	elif not hp_ok:
		btn.text += " — barco destruido"
	
	if btn.pressed.get_connections().size() > 0:
		btn.pressed.disconnect(
			btn.pressed.get_connections()[0].callable)
	
	btn.pressed.connect(
		func(): emit_signal("destination_selected", destination))
