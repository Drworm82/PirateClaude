extends CanvasLayer

signal menu_closed

@onready var island_list: VBoxContainer = $Panel/ScrollContainer/IslandList
@onready var loading_label: Label = $Panel/LoadingLabel

var _buttons: Array = []

func _ready() -> void:
	load_destinations()

func load_destinations() -> void:
	loading_label.visible = true
	island_list.visible = false

	var http: HTTPRequest = SupabaseClient.supabase_rpc(
		"get_reachable_islands",
		{
			"origin_id": GameState.get_current_island_id(),
			"max_range_km": VoyageManager.SHIP_RANGE_KM
		}
	)
	var response: Array = await http.request_completed
	var body: String = response[3].get_string_from_utf8()
	var data: Variant = JSON.parse_string(body)

	loading_label.visible = false
	island_list.visible = true
	_buttons.clear()

	for child in island_list.get_children():
		child.queue_free()

	if data is Array:
		for island in data:
			var btn: Button = Button.new()
			btn.text = "%s — %.1f km" % [island.get("nombre", "?"), island.get("distance_km", 0.0)]
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			btn.set_meta("island_id", island.get("island_id", ""))
			btn.set_meta("distance_km", island.get("distance_km", 0.0))
			island_list.add_child(btn)
			_buttons.append(btn)

	var cancel_btn: Button = Button.new()
	cancel_btn.text = "Cancelar"
	cancel_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	cancel_btn.set_meta("island_id", "__cancel__")
	cancel_btn.set_meta("distance_km", 0.0)
	island_list.add_child(cancel_btn)
	_buttons.append(cancel_btn)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		for btn in _buttons:
			if not is_instance_valid(btn):
				continue
			if btn.get_global_rect().has_point(event.position):
				var island_id: String = btn.get_meta("island_id", "")
				if island_id == "__cancel__":
					_on_cancel_pressed()
				else:
					var distance_km: float = btn.get_meta("distance_km", 0.0)
					_on_island_selected(island_id, distance_km)
				return

func _on_island_selected(island_id: String, _distance_km: float) -> void:
	await VoyageManager.start_voyage(island_id)
	menu_closed.emit()
	queue_free()

func _on_cancel_pressed() -> void:
	menu_closed.emit()
	queue_free()
