extends Node

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

func initialize() -> void:
	SupabaseClient.sign_in_anonymous()
	var result: bool = await SupabaseClient.auth_completed
	if result and SupabaseClient._user_id != "":
		player_id = SupabaseClient._user_id
		is_authenticated = true
		await _load_or_create_player()
	else:
		print("Auth fallida — modo offline")

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
		print("Jugador cargado: ", doblones, " doblones")
	else:
		await _create_player()

func _create_player() -> void:
	var http := SupabaseClient.insert("players", {
		"id": player_id,
		"doblones": 100,
		"prestigio": 0,
		"lat_center": home_lat,
		"lng_center": home_lng,
		"ship_hp": 100
	})
	var response: Array = await http.request_completed
	var body: String = response[3].get_string_from_utf8()
	print("Jugador creado. Response: ", response[1])
	print("Body: ", body)

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
