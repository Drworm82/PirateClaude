extends Node

signal home_position_ready(lat: float, lng: float)
signal player_position_changed(lat: float, lng: float)

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
var home_island_id: String = ""
var islands_cache: Array = []
var doblones_onboard: int = 0
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
	emit_signal("player_position_changed", lat, lng)


func _on_gps_error(reason: String) -> void:
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
	await SupabaseClient.sign_in_anonymous()
	await SupabaseClient.auth_completed
	player_id = SupabaseClient._user_id
	GameState.debug_log("player_id set: " + player_id)
	await _load_or_create_player()

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
		doblones = int(p.get("doblones", 100))
		if doblones == 0:
			doblones = 100
		prestigio = p.get("prestigio", 0)
		home_lat = p.get("lat_center", 19.4326)
		home_lng = p.get("lng_center", -99.1332)
		ship_hp = p.get("ship_hp", 100)
		home_island_id = p.get("home_island_id", "")
		if _pending_gps_sync:
			_pending_gps_sync = false
			_sync_home_position()
		if home_island_id == "":
			await _find_home_island()
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
	await _create_or_find_home_island()


func _create_or_find_home_island() -> void:
	# Esperar GPS real con timeout de 5 segundos
	var timeout: float = 5.0
	var elapsed: float = 0.0
	while (GpsService.last_lat == 19.4326 and GpsService.last_lng == -99.1332) and elapsed < timeout:
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5
	
	var lat: float = GpsService.last_lat
	var lng: float = GpsService.last_lng
	log_debug("home coords: " + str(snappedf(lat, 0.0001)) + "," + str(snappedf(lng, 0.0001)))
	# Buscar isla home existente a menos de 500m
	var http := SupabaseClient.select("islands", "tipo=eq.home")
	var response: Array = await http.request_completed
	var body: String = response[3].get_string_from_utf8()
	var data: Variant = JSON.parse_string(body)

	var found_id: String = ""
	if data is Array:
		for isl in data:
			var ilat: float = isl.get("lat", 0.0)
			var ilng: float = isl.get("lng", 0.0)
			var dist: float = _haversine_km(lat, lng, ilat, ilng)
			if dist < 0.35:
				found_id = isl.get("id", "")
				log_debug("home: " + str(snappedf(ilat, 0.0001)) + "," + str(snappedf(ilng, 0.0001)))
				log_debug("yo: " + str(snappedf(lat, 0.0001)) + "," + str(snappedf(lng, 0.0001)))
				break

	if found_id == "":
		# Crear isla home nueva
		var http2 := SupabaseClient.insert("islands", {
			"nombre": "Isla " + player_id.left(4),
			"lat": lat,
			"lng": lng,
			"tipo": "home",
			"terreno": "tropical",
			"relieve": "colinas",
			"costa": "playa",
			"faccion": "Independiente",
			"poblacion": "pequeña",
			"recursos": ["madera", "peces"],
			"comercio": ["exporta: madera"]
		})
		var r2: Array = await http2.request_completed
		var b2: String = r2[3].get_string_from_utf8()
		var d2: Variant = JSON.parse_string(b2)
		if d2 is Array and d2.size() > 0:
			found_id = d2[0].get("id", "")
			log_debug("isla home creada")

	if found_id != "":
		home_island_id = found_id
		SupabaseClient.upsert("player_island_knowledge", {
			"player_id": player_id,
			"island_id": found_id,
			"nivel": 5
		})


func _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
	var R: float = 6371.0
	var dlat: float = deg_to_rad(lat2 - lat1)
	var dlng: float = deg_to_rad(lng2 - lng1)
	var a: float = sin(dlat/2) * sin(dlat/2) + cos(deg_to_rad(lat1)) * cos(deg_to_rad(lat2)) * sin(dlng/2) * sin(dlng/2)
	return R * 2.0 * atan2(sqrt(a), sqrt(1.0 - a))

func save_player() -> void:
	var http := SupabaseClient.upsert("players", {
		"id": player_id,
		"doblones": doblones,
		"prestigio": prestigio,
		"ship_hp": ship_hp,
		"ultima_conexion": Time.get_datetime_string_from_system()
	})
	var response: Array = await http.request_completed

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


func load_islands() -> Array:
	var http := SupabaseClient.select("islands", "")
	var response: Array = await http.request_completed
	var body: String = response[3].get_string_from_utf8()
	var data: Variant = JSON.parse_string(body)
	if data is Array:
		islands_cache = data
		log_debug("islas cargadas: " + str(data.size()))
		return data
	log_debug("islas err: " + str(response[1]))
	log_debug("islas body: " + body.left(80))
	return []


func load_island_knowledge() -> Array:
	var http := SupabaseClient.select(
		"player_island_knowledge",
		"player_id=eq." + player_id
	)
	var response: Array = await http.request_completed
	var body: String = response[3].get_string_from_utf8()
	var data: Variant = JSON.parse_string(body)
	if data is Array:
		return data
	return []


func unlock_island_knowledge(island_id: String, nivel: int) -> void:
	var data := {
		"player_id": player_id,
		"island_id": island_id,
		"nivel": nivel
	}
	SupabaseClient.upsert("player_island_knowledge", data)

func _find_home_island() -> void:
	var http := SupabaseClient.select("islands", "tipo=eq.home&order=id&limit=1")
	var response: Array = await http.request_completed
	var body: String = response[3].get_string_from_utf8()
	var data: Variant = JSON.parse_string(body)
	if data is Array and data.size() > 0:
		home_island_id = data[0].get("id", "")
		log_debug("home_island_id: " + home_island_id)

func get_doblones_onboard() -> int:
	return doblones_onboard

func set_doblones_onboard(amount: int) -> void:
	doblones_onboard = amount
