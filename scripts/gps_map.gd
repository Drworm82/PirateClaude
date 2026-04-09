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

const SCALE: float = 10000.0

var _player_lat: float = 0.0
var _player_lng: float = 0.0
var _map_center: Vector2

const DESTINATIONS := {
	"isla_norte": {"pos": Vector2(200, 150), "name": "Isla Enana", "cost": 10},
	"isla_este": {"pos": Vector2(800, 200), "name": "Isla del Cocinero", "cost": 15},
	"puerto_neutral": {"pos": Vector2(640, 600), "name": "Puerto Loguetown", "cost": 20}
}

var player_screen_pos := Vector2(360, 640)
var debug_gps: bool = true
var islands: Array = []
var island_knowledge: Dictionary = {}
var nearby_island: Dictionary = {}
var initialized := false
var _map_initialized := false
var traveling: bool = false
var travel_target: Vector2 = Vector2.ZERO
var travel_origin: Vector2 = Vector2.ZERO
var travel_destination_name: String = ""
var travel_total_distance: float = 0.0
var joystick = null


func _ready() -> void:
	initialized = true
	await get_tree().process_frame
	_map_center = get_viewport_rect().size / 2.0
	player_screen_pos = _map_center
	queue_redraw()
	GameManager.home_position_ready.connect(_on_home_ready)
	GameManager.player_position_changed.connect(_on_player_moved)
	VoyageManager.voyage_updated.connect(_on_voyage_updated)
	# Esperar a que GPS y auth estén listos
	await get_tree().create_timer(3.0).timeout
	await _load_islands_from_supabase()

	joystick = get_tree().get_first_node_in_group("joystick")
	if joystick:
		joystick.set_enabled(false)


func get_home_island() -> Vector2:
	return get_viewport_rect().size / 2.0


func _on_home_ready(lat: float, lng: float) -> void:
	_player_lat = lat
	_player_lng = lng
	_map_center = get_viewport_rect().size / 2.0
	player_screen_pos = _map_center
	if islands.size() > 0:
		_place_islands_relative()
		_center_on_home_island()
	queue_redraw()


func _place_player_at_center() -> void:
	player_screen_pos = _map_center


func _place_islands_relative() -> void:
	if _player_lat == 0.0:
		_player_lat = GpsService.last_lat
		_player_lng = GpsService.last_lng
		_map_center = get_viewport_rect().size / 2.0
		player_screen_pos = _map_center
	for island in islands:
		var lat: float = island.get("lat", 0.0)
		var lng: float = island.get("lng", 0.0)
		island["pos"] = _world_to_screen(lat, lng)


func _world_to_screen(lat: float, lng: float) -> Vector2:
	var dx = (lng - _player_lng) * SCALE
	var dy = (lat - _player_lat) * SCALE * -1.0
	return _map_center + Vector2(dx, dy)


func _physics_process(delta: float) -> void:
	if not _map_initialized:
		var size = get_viewport_rect().size
		if size.x > 0 and size.y > 0:
			_map_center = size / 2.0
			player_screen_pos = _map_center
			_map_initialized = true
			_place_islands_relative()
			queue_redraw()
	var main = get_tree().get_first_node_in_group("main")
	if not traveling:
		nearby_island = {}
		for island in islands:
			if player_screen_pos.distance_to(island.pos) < 80.0:
				nearby_island = island
				break
		if not nearby_island.is_empty():
			main.update_action_state(1)
		else:
			main.update_action_state(2)
	else:
		main.update_action_state(3)
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


func _on_enter_island() -> void:
	if not nearby_island.is_empty():
		player_entered_island.emit(nearby_island.get("pos", Vector2.ZERO))


func _draw() -> void:
	if not initialized:
		return
	draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), OCEAN_COLOR)
	for island in islands:
		var color: Color
		var radius: float = ISLAND_RADIUS
		match island.get("tipo", "normal"):
			"zona_segura":
				color = Color(0.23, 0.35, 0.54)
				radius = 35.0
			"home":
				color = Color(0.8, 0.6, 0.2)
				radius = 50.0
			"normal":
				color = ISLAND_COLOR
		draw_circle(island.pos, radius, color)
	draw_circle(player_screen_pos, 20.0, PLAYER_COLOR)

	if not nearby_island.is_empty():
		draw_string(
			ThemeDB.fallback_font,
			player_screen_pos + Vector2(-40, -30),
			"Entrar",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 14, Color.WHITE
		)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(20, 30),
		"Doblones: " + str(GameManager.doblones),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1, 16, Color.WHITE
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(20, 55),
		"Barco: " + str(GameManager.ship_hp) + "/" + str(GameManager.ship_hp_max) + " HP",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1, 16,
		Color(0.9, 0.4, 0.2) if GameManager.ship_hp < 30 else Color.WHITE
	)

	if debug_gps:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(20, 80),
			"GPS: " + str(snappedf(GpsService.last_lat, 0.000001)) + ", " + str(snappedf(GpsService.last_lng, 0.000001)),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 14, Color(0.5, 1.0, 0.5)
		)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(20, 100),
			"Estado: " + str(GpsService.state),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1, 14, Color(0.5, 1.0, 0.5)
		)
		var log_y: float = 120.0
		for line in GameManager.debug_log:
			draw_string(
				ThemeDB.fallback_font,
				Vector2(20, log_y),
				line,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1, 12, Color(1.0, 1.0, 0.5)
			)
			log_y += 16.0

	if traveling:
		draw_line(travel_origin, travel_target, Color(1, 1, 1, 0.3), 2.0)
		draw_line(travel_origin, player_screen_pos, Color(0.4, 0.8, 1.0, 0.8), 2.0)

		var progress: float = 0.0
		if travel_total_distance > 0:
			progress = 1.0 - (player_screen_pos.distance_to(travel_target) / travel_total_distance)
		progress = clamp(progress, 0.0, 1.0)

		var bar_x: float = 20.0
		var bar_y: float = 85.0
		var bar_w: float = 300.0
		var bar_h: float = 12.0

		draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2, 0.8))
		draw_rect(Rect2(bar_x, bar_y, bar_w * progress, bar_h), Color(0.4, 0.8, 1.0))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(bar_x, bar_y - 4),
			"Rumbo a: " + travel_destination_name + "  " + str(int(progress * 100)) + "%",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE
		)
		draw_circle(travel_target, 8.0, Color(0.4, 0.8, 1.0, 0.6))


func update_player_position(_gps_lat: float, _gps_lng: float) -> void:
	queue_redraw()


func _on_player_moved(lat: float, lng: float) -> void:
	if traveling:
		return
	_player_lat = lat
	_player_lng = lng
	player_screen_pos = _map_center
	_place_islands_relative()
	queue_redraw()


func _load_islands_from_supabase() -> void:
	SupabaseClient.refresh_token()
	await get_tree().create_timer(0.5).timeout
	var raw_islands: Array = await GameManager.load_islands()
	var raw_knowledge: Array = await GameManager.load_island_knowledge()
	
	island_knowledge = {}
	for k in raw_knowledge:
		island_knowledge[k.get("island_id", "")] = k.get("nivel", 1)
	
	islands = []
	for isl in raw_islands:
		var island_id: String = isl.get("id", "")
		var nivel: int = island_knowledge.get(island_id, 0)
		islands.append({
			"id": island_id,
			"pos": Vector2(0, 0),
			"lat": isl.get("lat", 0.0),
			"lng": isl.get("lng", 0.0),
			"nombre": isl.get("nombre", "???"),
			"tipo": isl.get("tipo", "normal"),
			"terreno": isl.get("terreno", ""),
			"relieve": isl.get("relieve", ""),
			"costa": isl.get("costa", ""),
			"faccion": isl.get("faccion", ""),
			"poblacion": isl.get("poblacion", ""),
			"recursos": isl.get("recursos", []),
			"comercio": isl.get("comercio", []),
			"nivel": nivel
		})
	
	GameManager.log_debug("player_lat: " + str(snappedf(_player_lat, 0.0001)))
	GameManager.log_debug("islands: " + str(islands.size()))
	for isl in islands:
		GameManager.log_debug(isl.get("tipo","?") + " lat:" + str(snappedf(isl.get("lat",0.0), 0.001)))
	
	_place_islands_relative()
	_center_on_home_island()
	queue_redraw()


func _center_on_home_island() -> void:
	for island in islands:
		if island.get("tipo", "") == "home":
			GameManager.log_debug("home pos: " + str(island.pos))
			GameManager.log_debug("player: " + str(player_screen_pos))
			player_screen_pos = island.pos
			GameManager.log_debug("after: " + str(player_screen_pos))
			return
	GameManager.log_debug("home NOT found")


func _exit_tree() -> void:
	if joystick:
		joystick.set_enabled(false)


func _on_voyage_updated(seconds_remaining: int, doblones_remaining: int, progress: float) -> void:
	_update_voyage_hud(seconds_remaining, doblones_remaining)
	
	if not VoyageManager.active_voyage.is_empty():
		var origin: Dictionary = GameState.get_island_coords(
			VoyageManager.active_voyage.get("origin_island_id", ""))
		var dest: Dictionary = GameState.get_island_coords(
			VoyageManager.active_voyage.get("destination_island_id", ""))
		if origin["lat"] != 0.0 and dest["lat"] != 0.0:
			_player_lat = lerpf(origin["lat"], dest["lat"], progress)
			_player_lng = lerpf(origin["lng"], dest["lng"], progress)
			_place_islands_relative()
			queue_redraw()


func _update_voyage_hud(seconds_remaining: int, doblones_remaining: int) -> void:
	var hud = get_node_or_null("VoyageHUD")
	if hud:
		hud.visible = true
