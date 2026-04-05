extends Node

signal home_position_ready(lat: float, lng: float)

var player_id: String = ""
var doblones: int = 100
var prestigio: int = 0
var home_lat: float = 19.4326
var home_lng: float = -99.1332
var is_authenticated: bool = false

var ship_hp: int = 100
var ship_hp_max: int = 100
var ship_repair_cost: int = 5
var current_island_name: String = "Tu isla"
var _pending_gps_sync: bool = false
var debug_log: Array[String] = []

func _ready() -> void:
	GpsService.location_updated.connect(_on_gps_location)
	GpsService.location_error.connect(_on_gps_error)

func _on_gps_location(lat: float, lng: float) -> void:
	home_lat = lat
	home_lng = lng
	emit_signal("home_position_ready", lat, lng)
	if is_authenticated and player_id != "":
		_sync_home_position()
	else:
		_pending_gps_sync = true


func _on_gps_error(reason: String) -> void:
	print("GPS Error: ", reason)
	emit_signal("home_position_ready", home_lat, home_lng)


func _sync_home_position() -> void:
	var data = {
		"id": GameManager.player_id,
		"lat_center": home_lat,
		"lng_center": home_lng
	}
	SupabaseClient.upsert("players", data)

func initialize() -> void:
	log_debug("init started")
	# DEBUG: descomentar solo para resetear token
	# SupabaseClient._clear_token()
	SupabaseClient.sign_in_anonymous()
	var result: bool = await SupabaseClient.auth_completed
	log_debug("auth: " + str(result) + " id: " + SupabaseClient._user_id)
	if result and SupabaseClient._user_id != "":
		player_id = SupabaseClient._user_id
		is_authenticated = true
		log_debug("authenticated")
		await _load_or_create_player()
		log_debug("player loaded")
		if _pending_gps_sync:
			_pending_gps_sync = false
			_sync_home_position()
	else:
		log_debug("auth failed")

func _load_or_create_player() -> void:
	var http := SupabaseClient.select(
		"players",
		"id=eq." + player_id
	)
	var response: Array = await http.request_completed
	var body: String = response[3].get_string_from_utf8()
	var data: Variant = JSON.parse_string(body)

	if data is Array and data.size() > 0:
		var p: Dictionary = data[0]
		doblones = p.get("doblones", 100)
		prestigio = p.get("prestigio", 0)
		home_lat = p.get("lat_center", 19.4326)
		home_lng = p.get("lng_center", -99.1332)
		ship_hp = p.get("ship_hp", 100)
		if _pending_gps_sync:
			_pending_gps_sync = false
			_sync_home_position()
		print("Jugador cargado: ", doblones, " doblones")
	else:
		await _create_player()

func _create_player() -> void:
	log_debug("creating player")
	var http := SupabaseClient.insert("players", {
		"id": player_id,
		"doblones": 100,
		"prestigio": 0,
		"lat_center": home_lat,
		"lng_center": home_lng,
		"ship_hp": 100
	})
	var response: Array = await http.request_completed
	log_debug("create resp: " + str(response[1]))
	log_debug("body: " + response[3].get_string_from_utf8().left(60))

func save_player() -> void:
	var http := SupabaseClient.upsert("players", {
		"id": player_id,
		"doblones": doblones,
		"prestigio": prestigio,
		"ship_hp": ship_hp,
		"ultima_conexion": Time.get_datetime_string_from_system()
	})
	var response: Array = await http.request_completed
	print("Guardado. Response: ", response[1])

func repair_ship(amount: int) -> void:
	var cost: int = amount * ship_repair_cost
	if doblones >= cost:
		doblones -= cost
		ship_hp = min(ship_hp + amount, ship_hp_max)
		save_player()

func damage_ship(amount: int) -> void:
	ship_hp = max(0, ship_hp - amount)


func log_debug(msg: String) -> void:
	debug_log.append(msg)
	if debug_log.size() > 8:
		debug_log.pop_front()
