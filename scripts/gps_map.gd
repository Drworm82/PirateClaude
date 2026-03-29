extends Node2D
class_name GPSMap

signal player_entered_island(island_pos: Vector2)

const OCEAN_COLOR := Color(0.102, 0.227, 0.361)
const PLAYER_COLOR := Color(0.4, 0.6, 0.9)
const ISLAND_COLOR := Color(0.176, 0.416, 0.31)
const ISLAND_RADIUS := 40.0
const CLICK_RADIUS := 60.0

var player_screen_pos := Vector2(614, 345)
var islands: Array[Dictionary] = [
	{pos = Vector2(200, 150)},
	{pos = Vector2(500, 350)},
	{pos = Vector2(800, 200)}
]
var initialized := false

func _ready() -> void:
	initialized = true
	queue_redraw()

func _draw() -> void:
	if not initialized:
		return
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), OCEAN_COLOR)
	for island in islands:
		draw_circle(island.pos, ISLAND_RADIUS, ISLAND_COLOR)
	draw_circle(player_screen_pos, 20.0, PLAYER_COLOR)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_check_island_click(event.position)

func _check_island_click(click_pos: Vector2) -> void:
	for island in islands:
		if click_pos.distance_to(island.pos) < CLICK_RADIUS:
			emit_signal("player_entered_island", island.pos)
			return

func update_player_position(_gps_lat: float, _gps_lng: float) -> void:
	queue_redraw()
