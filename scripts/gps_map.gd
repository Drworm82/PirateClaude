extends Node2D
class_name GPSMap

signal player_entered_island(island_pos: Vector2)
signal travel_completed

const OCEAN_COLOR := Color(0.102, 0.227, 0.361)
const PLAYER_COLOR := Color(0.4, 0.6, 0.9)
const ISLAND_COLOR := Color(0.176, 0.416, 0.31)
const ISLAND_RADIUS := 40.0
const PLAYER_SPEED := 150.0
const TRAVEL_SPEED := 80.0

const DESTINATIONS := {
	"isla_norte": {"pos": Vector2(200, 150), "name": "Isla Enana", "cost": 10},
	"isla_este": {"pos": Vector2(800, 200), "name": "Isla del Cocinero", "cost": 15},
	"puerto_neutral": {"pos": Vector2(640, 600), "name": "Puerto Loguetown", "cost": 20}
}

var player_screen_pos := Vector2(640, 360)
var islands: Array[Dictionary] = [
	{pos = Vector2(200, 150), name = "Isla Enana"},
	{pos = Vector2(500, 350), name = "Isla del Cocinero"},
	{pos = Vector2(800, 200), name = "Isla Drum Jr."}
]
var nearby_island: Dictionary = {}
var initialized := false
var traveling: bool = false
var travel_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	initialized = true
	var home_island := get_home_island()
	if not islands.any(func(i): 
			return i.pos.distance_to(home_island) < 50):
		islands.insert(0, {
			pos = home_island,
			is_home = true,
			name = "Tu isla"
		})
	player_screen_pos = home_island + Vector2(80, 0)
	queue_redraw()

func get_home_island() -> Vector2:
	var center := Vector2(640, 360)
	return center

func _physics_process(delta: float) -> void:
	if not traveling:
		var direction := Input.get_vector(
			"move_left", "move_right", "move_up", "move_down"
		)
		player_screen_pos += direction * PLAYER_SPEED * delta
		player_screen_pos.x = clamp(player_screen_pos.x, 0, 1280)
		player_screen_pos.y = clamp(player_screen_pos.y, 0, 720)
		
		nearby_island = {}
		for island in islands:
			if player_screen_pos.distance_to(island.pos) < 80.0:
				nearby_island = island
				break
	else:
		var dir := (travel_target - player_screen_pos).normalized()
		var dist := player_screen_pos.distance_to(travel_target)
		if dist < 5.0:
			traveling = false
			player_screen_pos = travel_target
			emit_signal("travel_completed")
		else:
			player_screen_pos += dir * TRAVEL_SPEED * delta
	
	queue_redraw()

func start_travel(destination: String) -> void:
	if destination in DESTINATIONS:
		travel_target = DESTINATIONS[destination].pos
		traveling = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_E:
			if not nearby_island.is_empty():
				emit_signal("player_entered_island", nearby_island.pos)

func _draw() -> void:
	if not initialized:
		return
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), OCEAN_COLOR)
	for island in islands:
		var color := ISLAND_COLOR
		var radius := ISLAND_RADIUS
		if island.get("is_home", false):
			color = Color(0.8, 0.6, 0.2)
			radius = 50.0
		draw_circle(island.pos, radius, color)
	draw_circle(player_screen_pos, 20.0, PLAYER_COLOR)
	
	if not nearby_island.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			player_screen_pos + Vector2(-40, -30),
			"E — Entrar",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color.WHITE
		)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(20, 30),
		"Doblones: " + str(GameManager.doblones),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color.WHITE
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(20, 55),
		"Barco: " + str(GameManager.ship_hp) + "/" + str(GameManager.ship_hp_max) + " HP",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		Color(0.9, 0.4, 0.2) if GameManager.ship_hp < 30 else Color.WHITE
	)

func update_player_position(_gps_lat: float, _gps_lng: float) -> void:
	queue_redraw()
