extends Node
class_name MainController

enum View {GPS, DUNGEON}
var current_view: View = View.GPS
var gps_map: GPSMap
var current_dungeon: Dungeon
var current_destination: String = ""
var travel_result_ui: Node = null
var main_hud: CanvasLayer = null

const TRAVEL_COSTS := {
	"isla_norte": 10,
	"isla_este": 15,
	"puerto_neutral": 20
}

func _ready() -> void:
	add_to_group("main")

	await GameManager.initialize()
	await VoyageManager.check_active_voyage()
	main_hud = $MainHud
	main_hud.action_pressed.connect(_on_action_pressed)
	main_hud.map_pressed.connect(_on_map_pressed)
	main_hud.menu_pressed.connect(_on_menu_pressed)
	_setup_gps_view()
	VoyageManager.voyage_arrived.connect(_on_voyage_arrived)

func _setup_gps_view() -> void:
	var gps_scene: PackedScene = preload("res://scenes/gps_map.tscn")
	gps_map = gps_scene.instantiate()
	add_child(gps_map)
	gps_map.player_entered_island.connect(_on_player_entered_island)
	current_view = View.GPS
	await get_tree().process_frame
	gps_map.queue_redraw()

func _on_player_entered_island(island_pos: Vector2) -> void:
	if current_view == View.DUNGEON:
		return

	gps_map.visible = false
	
	var gps_joystick = gps_map.get_node_or_null("VirtualJoystick/JoystickControl")
	if gps_joystick:
		gps_joystick.set_process_unhandled_input(false)
		gps_joystick.set_process_input(false)
		gps_joystick.visible = false
	
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
	current_destination = destination
	var cost: int = TRAVEL_COSTS.get(destination, 10)
	if GameManager.doblones < cost:
		print("Sin doblones suficientes para viajar")
		return
	GameManager.doblones -= cost

func _on_player_exited_dungeon() -> void:
	if current_dungeon:
		current_dungeon.queue_free()
		current_dungeon = null
	gps_map.visible = true
	
	var gps_joystick = gps_map.get_node_or_null("VirtualJoystick/JoystickControl")
	if gps_joystick:
		gps_joystick.set_process_unhandled_input(true)
		gps_joystick.set_process_input(true)
		gps_joystick.visible = true
	
	if current_destination != "":
		gps_map.start_travel(current_destination)
		gps_map.travel_completed.connect(
			_on_travel_completed, CONNECT_ONE_SHOT)
		current_destination = ""
	current_view = View.GPS
	GameManager.save_player()

func _on_travel_completed() -> void:
	var event := TravelEvents.generate_event()
	GameManager.doblones += event.doblones_delta
	GameManager.doblones = max(0, GameManager.doblones)
	
	var ship_damage: int = event.get("ship_damage", 0)
	if ship_damage > 0:
		GameManager.damage_ship(ship_damage)
	
	var result_scene: PackedScene = preload(
		"res://scenes/travel_result.tscn")
	travel_result_ui = result_scene.instantiate()
	add_child(travel_result_ui)
	travel_result_ui.show_result(event)
	travel_result_ui.closed.connect(_on_result_closed)
	
	await GameManager.save_player()

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
			if is_instance_valid(current_dungeon):
				current_dungeon.visible = true
				if is_instance_valid(gps_map):
					gps_map.visible = false
		4:
			if is_instance_valid(current_dungeon):
				current_dungeon._on_board_pressed()

func update_action_state(state: int) -> void:
	if is_instance_valid(main_hud):
		main_hud.set_action_state(state)

func _on_menu_pressed() -> void:
	pass

func _on_map_pressed() -> void:
	var map = get_node_or_null("MapOverlay")
	if is_instance_valid(map):
		map.queue_free()
	else:
		MapButton._open_map()

func _on_voyage_arrived(destination_id: String) -> void:
	GameState.debug_log("voyage_arrived: " + destination_id)
	var menu: CanvasLayer = preload("res://scenes/arrival_menu.tscn").instantiate()
	GameState.debug_log("menu created: " + str(is_instance_valid(menu)))
	var island_name: String = GameState.get_island_name(destination_id)
	GameState.debug_log("island_name: " + island_name)
	menu.set_island_name(island_name)
	add_child(menu)
	GameState.debug_log("menu added to scene")
	menu.go_ashore.connect(_on_arrival_go_ashore)
	menu.stay_onboard.connect(_on_arrival_stay)
	menu.set_sail.connect(_on_arrival_set_sail)

func _on_arrival_go_ashore() -> void:
	if is_instance_valid(current_dungeon):
		current_dungeon.queue_free()
		current_dungeon = null
	var island_pos := Vector2(GameManager.home_lat, GameManager.home_lng)
	var p_seed := int(island_pos.x) * 73856093 ^ int(island_pos.y) * 19349663
	var dungeon_scene: PackedScene = preload("res://scenes/dungeon.tscn")
	current_dungeon = dungeon_scene.instantiate()
	add_child(current_dungeon)
	current_dungeon.setup(p_seed, island_pos)
	current_dungeon.player_exited_dungeon.connect(_on_player_exited_dungeon)
	current_dungeon.destination_chosen.connect(_on_destination_chosen)
	current_view = View.DUNGEON
	gps_map.visible = false

func _on_arrival_stay() -> void:
	pass

func _on_arrival_set_sail() -> void:
	_on_sail_pressed()
