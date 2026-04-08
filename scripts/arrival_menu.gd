extends CanvasLayer

signal stay_onboard
signal go_ashore
signal set_sail

var _btn_go_ashore: Button
var _btn_stay_onboard: Button
var _btn_set_sail: Button

func _ready() -> void:
	_btn_go_ashore = get_node("Panel/VBox/BtnGoAshore")
	_btn_stay_onboard = get_node("Panel/VBox/BtnStayOnboard")
	_btn_set_sail = get_node("Panel/VBox/BtnSetSail")

func set_island_name(island_name: String) -> void:
	get_node("Panel/VBox/IslandLabel").text = island_name

func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch and not event is InputEventMouseButton:
		return
	var pressed: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = event.position
	if not pressed:
		return
	if _btn_go_ashore.get_global_rect().has_point(pos):
		go_ashore.emit()
		queue_free()
	elif _btn_stay_onboard.get_global_rect().has_point(pos):
		stay_onboard.emit()
		queue_free()
	elif _btn_set_sail.get_global_rect().has_point(pos):
		set_sail.emit()
		queue_free()