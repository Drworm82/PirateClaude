extends Node
class_name MainController

enum View {GPS, DUNGEON, SHIP}
var current_view: View = View.GPS
var gps_map: GPSMap
var current_dungeon: Dungeon
var current_ship_interior: ShipInterior = null
var current_destination: String = ""
var travel_result_ui: Node = null
var main_hud: CanvasLayer = null
var _last_action_state: int = -1

const TRAVEL_COSTS := {
	"isla_norte": 10,
	"isla_este": 15,
	"puerto_neutral": 20
}

func _ready() -> void:
	add_to_group("main")

	await GameManager.initialize()
	await VoyageManager.check_active_voyage()

	if VoyageManager.active_voyage.is_empty() and GameManager.doblones_onboard > 0:
		GameManager.doblones += GameManager.doblones_onboard
		GameManager.doblones_onboard = 0

	main_hud = $MainHud
	main_hud.action_pressed.connect(_on_action_pressed)
	main_hud.map_pressed.connect(_on_map_pressed)
	main_hud.menu_pressed.connect(_on_menu_pressed)
	_setup_gps_view()
	VoyageManager.voyage_arrived.connect(_on_voyage_arrived)
	VoyageManager.voyage_updated.connect(_on_voyage_updated)

	# Si hay viaje activo al iniciar, mostrar interior del barco
	if not VoyageManager.active_voyage.is_empty():
		_enter_ship_interior()

func _setup_gps_view() -> void:
	var gps_scene: PackedScene = preload("res://scenes/gps_map.tscn")
	gps_map = gps_scene.instantiate()
	add_child(gps_map)
	gps_map.player_entered_island.connect(_on_player_entered_island)
	current_view = View.GPS
	await get_tree().process_frame
	gps_map.queue_redraw()

# ── Interior del barco ────────────────────────────────────────────────────
func _enter_ship_interior() -> void:
	if is_instance_valid(current_ship_interior):
		return
	var scene: PackedScene = preload("res://scenes/ship_interior.tscn")
	current_ship_interior = scene.instantiate()
	add_child(current_ship_interior)
	current_ship_interior.enter_ship("lancha")
	GameState.debug_log("ship cam current: " + str(current_ship_interior._camera.is_current()))
	# Ocultar GPS mientras se ve el interior
	if is_instance_valid(gps_map):
		gps_map.visible = false
	current_view = View.SHIP

func _exit_ship_interior() -> void:
	if is_instance_valid(current_ship_interior):
		# Desactivar Camera2D antes de queue_free para evitar render fantasma
		var ship_cam: Camera2D = current_ship_interior.get_node_or_null("Camera2D")
		if ship_cam:
			ship_cam.enabled = false
		current_ship_interior.visible = false
		current_ship_interior.exit_ship()  # llama queue_free internamente
		current_ship_interior = null
	if is_instance_valid(gps_map):
		gps_map.visible = true
	current_view = View.GPS

# ── Toggle GPS ↔ Ship Interior durante viaje ─────────────────────────────
func _toggle_ship_view() -> void:
	if not is_instance_valid(current_ship_interior):
		return
	if current_view == View.SHIP:
		# Volver al mapa GPS — desactivar cámara del interior antes de ocultarlo
		var ship_cam: Camera2D = current_ship_interior.get_node_or_null("Camera2D")
		if ship_cam:
			ship_cam.enabled = false
		current_ship_interior.visible = false
		if is_instance_valid(gps_map):
			gps_map.visible = true
		current_view = View.GPS
	else:
		# Ver interior del barco — ocultar GPS y activar cámara del interior
		if is_instance_valid(gps_map):
			gps_map.visible = false
		current_ship_interior.visible = true
		var ship_cam: Camera2D = current_ship_interior.get_node_or_null("Camera2D")
		if ship_cam:
			ship_cam.enabled = true
			ship_cam.make_current()
		current_view = View.SHIP

func _on_voyage_updated(_seconds: int, _doblones: int, _progress: float) -> void:
	if is_instance_valid(current_dungeon) and current_dungeon.visible:
		current_dungeon.visible = false
		var boat_sprite = current_dungeon.get_node_or_null("Boat/Sprite2D")
		if boat_sprite:
			boat_sprite.visible = false
		var dungeon_cam: Camera2D = current_dungeon.get_node_or_null("Player/Camera2D")
		if dungeon_cam:
			dungeon_cam.enabled = false
			GameState.debug_log("dungeon cam disabled: " + str(dungeon_cam.enabled))
		else:
			GameState.debug_log("dungeon cam NOT FOUND")
	# Crear interior del barco la primera vez
	if not is_instance_valid(current_ship_interior):
		_enter_ship_interior()
	# Setear Action Button a "Ver barco" durante el viaje
	update_action_state(3)

func _on_player_entered_island(island_pos: Vector2) -> void:
	if current_view == View.DUNGEON:
		return

	gps_map.visible = false

	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")

	if gps_map.joystick:
		gps_map.joystick.set_enabled(false)

	var island_name := "Isla desconocida"
	for island in gps_map.islands:
		if island.pos.distance_to(island_pos) < 10:
			island_name = island.get("name", "Isla")
			break
	GameManager.current_island_name = island_name

	var dungeon_scene: PackedScene = preload("res://scenes/dungeon.tscn")
	current_dungeon = dungeon_scene.instantiate()
	add_child(current_dungeon)
	var p_seed := int(island_pos.x) * 73856093 ^ int(island_pos.y) * 19349663
	current_dungeon.setup(p_seed, island_pos)
	current_dungeon.player_exited_dungeon.connect(_on_player_exited_dungeon)
	current_dungeon.destination_chosen.connect(_on_destination_chosen)
	current_view = View.DUNGEON

func _on_destination_chosen(destination: String) -> void:
	GameState.debug_log("destination_chosen: " + destination)
	current_destination = destination
	var cost: int = TRAVEL_COSTS.get(destination, 10)
	if GameManager.doblones < cost:
		return
	GameManager.doblones -= cost

func _on_player_exited_dungeon() -> void:
	if current_dungeon:
		current_dungeon.queue_free()
		current_dungeon = null
	gps_map.visible = true

	if current_destination != "":
		gps_map.start_travel(current_destination)
		gps_map.travel_completed.connect(_on_travel_completed, CONNECT_ONE_SHOT)
		current_destination = ""
	current_view = View.GPS
	await GameManager.save_player_state()
	if not VoyageManager.active_voyage.is_empty():
		if not is_instance_valid(current_ship_interior):
			_enter_ship_interior()
		update_action_state(3)

func _on_travel_completed() -> void:
	var event := TravelEvents.generate_event()
	GameManager.doblones += event.doblones_delta
	GameManager.doblones = max(0, GameManager.doblones)

	var ship_damage: int = event.get("ship_damage", 0)
	if ship_damage > 0:
		GameManager.damage_ship(ship_damage)

	var result_scene: PackedScene = preload("res://scenes/travel_result.tscn")
	travel_result_ui = result_scene.instantiate()
	add_child(travel_result_ui)
	travel_result_ui.show_result(event)
	travel_result_ui.closed.connect(_on_result_closed)

	await GameManager.save_player_state()

func _on_result_closed() -> void:
	if travel_result_ui:
		travel_result_ui.queue_free()
		travel_result_ui = null
	gps_map.queue_redraw()

func open_map() -> void:
	var dungeon := current_dungeon
	var islands: Array = []
	if gps_map:
		islands = gps_map.islands
	MapButton.open_map(dungeon, islands)

func _on_sail_pressed() -> void:
	main_hud.disable_for_menu()
	if is_instance_valid(current_dungeon):
		var boat_sprite = current_dungeon.get_node_or_null("Boat/Sprite2D")
		if boat_sprite:
			boat_sprite.visible = false
	var menu: CanvasLayer = preload("res://scenes/destinationmenu.tscn").instantiate()
	add_child(menu)
	menu.menu_closed.connect(func():
		main_hud.enable_after_menu()
		main_hud.input_enabled = true
	)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_M:
			open_map()

func _on_action_pressed(state: int) -> void:
	GameState.debug_log("action pressed state: " + str(state))
	match state:
		0:
			pass
		1:
			if is_instance_valid(gps_map):
				gps_map._on_enter_island()
		2:
			_on_sail_pressed()
		3:
			# Toggle GPS ↔ interior del barco durante viaje
			if not VoyageManager.active_voyage.is_empty():
				_toggle_ship_view()
		4:
			if is_instance_valid(current_dungeon):
				current_dungeon._on_board_pressed()

func update_action_state(state: int) -> void:
	if not is_instance_valid(main_hud):
		return
	if state == _last_action_state:
		return
	_last_action_state = state
	GameState.debug_log("set_state: " + str(state))
	main_hud.set_action_state(state)

func _on_menu_pressed() -> void:
	pass

func _on_map_pressed() -> void:
	if MapButton.map_overlay and is_instance_valid(MapButton.map_overlay):
		MapButton._on_map_closed()
	else:
		open_map()

func _on_voyage_arrived(destination_id: String) -> void:
	GameState.debug_log("voyage_arrived: " + destination_id)
	# Destruir interior del barco al llegar
	_exit_ship_interior()

	var menu: CanvasLayer = preload("res://scenes/arrival_menu.tscn").instantiate()
	var island_name: String = GameState.get_island_name(destination_id)
	menu.set_island_name(island_name)
	add_child(menu)
	menu.go_ashore.connect(_on_arrival_go_ashore)
	menu.stay_onboard.connect(_on_arrival_stay)
	menu.set_sail.connect(_on_arrival_set_sail)

func _on_arrival_go_ashore() -> void:
	if is_instance_valid(current_dungeon):
		current_dungeon.queue_free()
		current_dungeon = null
	# Ocultar GPS antes de mostrar dungeon
	if is_instance_valid(gps_map):
		gps_map.visible = false
	var island_pos := Vector2(GameManager.home_lat, GameManager.home_lng)
	var p_seed := int(island_pos.x) * 73856093 ^ int(island_pos.y) * 19349663
	var dungeon_scene: PackedScene = preload("res://scenes/dungeon.tscn")
	current_dungeon = dungeon_scene.instantiate()
	add_child(current_dungeon)
	current_dungeon.setup(p_seed, island_pos)
	current_dungeon.player_exited_dungeon.connect(_on_player_exited_dungeon)
	current_dungeon.destination_chosen.connect(_on_destination_chosen)
	# Asegurar que la Camera2D del dungeon esté activa
	await get_tree().process_frame
	var dungeon_cam: Camera2D = current_dungeon.get_node_or_null("Player/Camera2D")
	if dungeon_cam:
		dungeon_cam.enabled = true
		dungeon_cam.make_current()
	current_view = View.DUNGEON
	await GameManager.save_player_state()

func _on_arrival_stay() -> void:
	pass

func _on_arrival_set_sail() -> void:
	_on_sail_pressed()