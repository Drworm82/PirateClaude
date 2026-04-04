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

const SCALE: float = 10000.0  # píxeles por grado (ajustable)

var _player_lat: float = 0.0
var _player_lng: float = 0.0
var _map_center: Vector2  # centro de pantalla

const DESTINATIONS := {
	"isla_norte": {"pos": Vector2(200, 150), "name": "Isla Enana", "cost": 10},
	"isla_este": {"pos": Vector2(800, 200), "name": "Isla del Cocinero", "cost": 15},
	"puerto_neutral": {"pos": Vector2(640, 600), "name": "Puerto Loguetown", "cost": 20}
}

var player_screen_pos := Vector2(360, 640)
var islands: Array[Dictionary] = [
	{pos = Vector2(200, 150), name = "Isla Enana"},
	{pos = Vector2(500, 350), name = "Isla del Cocinero"},
	{pos = Vector2(800, 200), name = "Isla Drum Jr."}
]
var nearby_island: Dictionary = {}
var initialized := false
var traveling: bool = false
var travel_target: Vector2 = Vector2.ZERO
var travel_origin: Vector2 = Vector2.ZERO
var travel_destination_name: String = ""
var travel_total_distance: float = 0.0
var joystick = null
var context_button = null

func _ready() -> void:
	initialized = true
	_map_center = get_viewport_rect().size / 2.0
	GameManager.home_position_ready.connect(_on_home_ready)
	var home_island := get_home_island()
	if not islands.any(func(i):
			return i.pos.distance_to(home_island) < 50):
		islands.insert(0, {
			pos = home_island,
			is_home = true,
			name = "Tu isla"
		})
	player_screen_pos = home_island + Vector2(150, 0)
	queue_redraw()

	joystick = get_tree().get_first_node_in_group("joystick")
	context_button = get_node_or_null("ContextActionButton")
	if context_button:
		context_button.action_pressed.connect(_on_context_pressed)

func get_home_island() -> Vector2:
	var center := get_viewport_rect().size / 2.0
	return center


func _on_home_ready(lat: float, lng: float) -> void:
	_player_lat = lat
	_player_lng = lng
	_place_player_at_center()
	_place_islands_relative()


func _place_player_at_center() -> void:
	player_screen_pos = _map_center


func _place_islands_relative() -> void:
	for island in islands:
		if "lat" in island and "lng" in island:
			island.pos = _world_to_screen(island.lat, island.lng)


func _world_to_screen(lat: float, lng: float) -> Vector2:
	var dx = (lng - _player_lng) * SCALE
	var dy = (lat - _player_lat) * SCALE * -1.0
	return _map_center + Vector2(dx, dy)


func _physics_process(delta: float) -> void:
	if not traveling:
		var direction := Input.get_vector(
			"move_left", "move_right", "move_up", "move_down"
		)
		player_screen_pos += direction * PLAYER_SPEED * delta
		var vp := get_viewport_rect().size
	player_screen_pos.x = clamp(player_screen_pos.x, 0, vp.x)
	player_screen_pos.y = clamp(player_screen_pos.y, 0, vp.y)

		nearby_island = {}
		for island in islands:
			if player_screen_pos.distance_to(island.pos) < 80.0:
				nearby_island = island
				break

		if context_button != null:
			if not nearby_island.is_empty():
				context_button.show_action("Entrar")
				if joystick:
					joystick.set_enabled(false)
			else:
				context_button.hide_action()
				if joystick:
					joystick.set_enabled(true)
	else:
		if context_button != null:
			context_button.hide_action()
		var dir := (travel_target - player_screen_pos).normalized()
		var dist: float = player_screen_pos.distance_to(travel_target)
		if dist < 5.0:
			traveling = false
			player_screen_pos = travel_target
			travel_destination_name = ""
			travel_total_distance = 0.0
			emit_signal("travel_completed")
		else:
			player_screen_pos += dir * TRAVEL_SPEED * delta

	queue_redraw()

func start_travel(destination: String) -> void:
	if destination in DESTINATIONS:
		travel_origin = player_screen_pos
		travel_target = DESTINATIONS[destination].pos
		travel_destination_name = DESTINATIONS[destination].name
		travel_total_distance = player_screen_pos.distance_to(travel_target)
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
	
	if traveling:
		draw_line(travel_origin, travel_target, 
			Color(1, 1, 1, 0.3), 2.0)
		draw_line(travel_origin, player_screen_pos,
			Color(0.4, 0.8, 1.0, 0.8), 2.0)
		
		var progress: float = 0.0
		if travel_total_distance > 0:
			progress = 1.0 - (player_screen_pos.distance_to(
				travel_target) / travel_total_distance)
		progress = clamp(progress, 0.0, 1.0)
		
		var bar_x: float = 20.0
		var bar_y: float = 85.0
		var bar_w: float = 300.0
		var bar_h: float = 12.0
		
		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h),
			Color(0.2, 0.2, 0.2, 0.8))
		draw_rect(Rect2(bar_x, bar_y, bar_w * progress, bar_h),
			Color(0.4, 0.8, 1.0))
		
		draw_string(
			ThemeDB.fallback_font,
			Vector2(bar_x, bar_y - 4),
			"Rumbo a: " + travel_destination_name + 
			"  " + str(int(progress * 100)) + "%",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color.WHITE
		)
		
		draw_circle(travel_target, 8.0, 
			Color(0.4, 0.8, 1.0, 0.6))

func update_player_position(_gps_lat: float, _gps_lng: float) -> void:
	queue_redraw()

func _on_context_pressed() -> void:
	if not nearby_island.is_empty():
		emit_signal("player_entered_island", nearby_island.pos)

func _exit_tree() -> void:
	if joystick:
		joystick.set_enabled(false)
