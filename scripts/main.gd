extends Node
class_name MainController

enum View {GPS, DUNGEON}
var current_view: View = View.GPS
var gps_map: GPSMap
var current_dungeon: Dungeon
var current_destination: String = ""

func _ready() -> void:
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

func _on_player_exited_dungeon() -> void:
	if current_dungeon:
		current_dungeon.queue_free()
		current_dungeon = null
	gps_map.visible = true
	if current_destination != "":
		gps_map.start_travel(current_destination)
		current_destination = ""
	current_view = View.GPS
