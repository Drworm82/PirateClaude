extends Node
class_name MainController

enum View {GPS, DUNGEON}
var current_view: View = View.GPS
var gps_map: GPSMap
var current_dungeon: Dungeon
var current_destination: String = ""
var travel_result_ui: Node = null

const TRAVEL_COSTS := {
	"isla_norte": 10,
	"isla_este": 15,
	"puerto_neutral": 20
}

func _ready() -> void:
	await GameManager.initialize()
	_setup_gps_view()

func _setup_gps_view() -> void:
	var gps_scene: PackedScene = preload("res://scenes/gps_map.tscn")
	gps_map = gps_scene.instantiate()
	add_child(gps_map)
	gps_map.player_entered_island.connect(_on_player_entered_island)
	current_view = View.GPS

func _on_player_entered_island(island_pos: Vector2) -> void:
	gps_map.visible = false
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

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_M:
			open_map()
