extends CanvasLayer

signal menu_closed

@onready var island_list: VBoxContainer = $Panel/ContentMargin/ScrollContainer/IslandList
@onready var loading_label: Label = $Panel/LoadingLabel

var _buttons: Array = []
var _btn_y_offsets: Array = []
var _selecting: bool = false

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
	await get_tree().process_frame
	await get_tree().process_frame
	_btn_y_offsets.clear()
	var y: float = 0.0
	for btn in _buttons:
		_btn_y_offsets.append(y)
		GameState.debug_log(btn.text.left(8) + " h:" + str(btn.size.y) + " y:" + str(y))
		y += btn.size.y

func _input(event: InputEvent) -> void:
	if _selecting:
		return
	if not event is InputEventScreenTouch:
		return
	if not event.pressed:
		return
	get_viewport().set_input_as_handled()
	var raw_y: float = event.position.y
	var adj_y: float = raw_y - 90.0

	for i in range(_buttons.size()):
		var btn = _buttons[i]
		if not is_instance_valid(btn):
			continue
		var y_start: float = _btn_y_offsets[i] if i < _btn_y_offsets.size() else 0.0
		var y_end: float = y_start + btn.size.y if btn.size.y > 0 else y_start + 31.0
		var btn_rect: Rect2 = Rect2(0.0, y_start, 720.0, y_end - y_start)
		if btn_rect.has_point(Vector2(event.position.x, adj_y)):
			var island_id: String = btn.get_meta("island_id", "")
			if island_id == "__cancel__":
				_on_cancel_pressed()
			else:
				var distance_km: float = btn.get_meta("distance_km", 0.0)
				_on_island_selected(island_id, distance_km)
			return

func _on_island_selected(island_id: String, _distance_km: float) -> void:
	if _selecting:
		return
	_selecting = true
	await VoyageManager.start_voyage(island_id)
	menu_closed.emit()
	queue_free()

func _on_cancel_pressed() -> void:
	menu_closed.emit()
	queue_free()