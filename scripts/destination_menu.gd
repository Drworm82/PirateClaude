extends CanvasLayer
class_name DestinationMenu

signal destination_selected(destination: String)
signal cancelled

func _ready() -> void:
	$Panel/VBoxContainer/Isla1.pressed.connect(
		func(): emit_signal("destination_selected", "isla_norte"))
	$Panel/VBoxContainer/Isla2.pressed.connect(
		func(): emit_signal("destination_selected", "isla_este"))
	$Panel/VBoxContainer/PuertoNeutral.pressed.connect(
		func(): emit_signal("destination_selected", "puerto_neutral"))
	$Panel/Cancelar.pressed.connect(
		func(): emit_signal("cancelled"))
