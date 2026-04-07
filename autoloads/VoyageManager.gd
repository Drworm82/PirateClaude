extends Node

const SHIP_SPEED_KMH: float = 5.0
const SHIP_RANGE_KM: float = 5.0
const DOBLONES_PER_KM: int = 2

var active_voyage: Dictionary = {}
var _timer: float = 0.0

signal voyage_updated(seconds_remaining: int, doblones_remaining: int)
signal voyage_arrived()
signal voyage_drifting()

func _ready() -> void:
	await get_tree().process_frame
	check_active_voyage()

func _process(delta: float) -> void:
	if active_voyage.is_empty():
		return
	_timer += delta
	if _timer >= 1.0:
		_timer = 0.0
		_tick()

func _tick() -> void:
	var now: float = Time.get_unix_time_from_system()
	var seconds_remaining: int = int(active_voyage.arrival_unix - now)
	var elapsed_minutes: float = (now - active_voyage.departure_unix) / 60.0
	var km_traveled: float = (SHIP_SPEED_KMH / 60.0) * elapsed_minutes
	var doblones_remaining: int = active_voyage.doblones_at_departure - int(km_traveled * DOBLONES_PER_KM)

	if doblones_remaining <= 0:
		_set_drifting()
		return
	if seconds_remaining <= 0:
		_set_arrived()
		return
	voyage_updated.emit(seconds_remaining, doblones_remaining)

func start_voyage(destination_island_id: String) -> void:
	var distance_km: float = GameState.get_distance_to(destination_island_id)
	var duration_seconds: int = int((distance_km / SHIP_SPEED_KMH) * 3600.0)
	var now: float = Time.get_unix_time_from_system()
	var doblones: int = GameState.get_doblones_onboard()

	var payload: Dictionary = {
		"player_id": GameState.get_player_id(),
		"origin_island_id": GameState.get_current_island_id(),
		"destination_island_id": destination_island_id,
		"ship_type": "lancha",
		"departure_time": Time.get_datetime_string_from_unix_time(int(now)) + "Z",
		"arrival_time": Time.get_datetime_string_from_unix_time(int(now) + duration_seconds) + "Z",
		"doblones_at_departure": doblones,
		"doblones_per_km": DOBLONES_PER_KM,
		"distance_km": distance_km,
		"status": "sailing"
	}

	var http: HTTPRequest = SupabaseClient.insert("voyages", payload)
	var response: Array = await http.request_completed
	var body: String = response[3].get_string_from_utf8()
	var data: Variant = JSON.parse_string(body)

	if data is Array and data.size() > 0:
		active_voyage = {
			"id": str(data[0].get("id", "")),
			"departure_unix": now,
			"arrival_unix": now + duration_seconds,
			"doblones_at_departure": doblones,
			"destination_island_id": destination_island_id
		}

func check_active_voyage() -> void:
	if GameState.get_player_id() == "":
		return
	var http: HTTPRequest = SupabaseClient.select(
		"voyages",
		"player_id=eq." + GameState.get_player_id() + "&status=eq.sailing&order=departure_time.desc&limit=1"
	)
	var response: Array = await http.request_completed
	var body: String = response[3].get_string_from_utf8()
	var data: Variant = JSON.parse_string(body)

	if data is Array and data.size() > 0:
		var v: Dictionary = data[0]
		active_voyage = {
			"id": str(v.get("id", "")),
			"departure_unix": _iso_to_unix(str(v.get("departure_time", ""))),
			"arrival_unix": _iso_to_unix(str(v.get("arrival_time", ""))),
			"doblones_at_departure": int(v.get("doblones_at_departure", 0)),
			"destination_island_id": str(v.get("destination_island_id", ""))
		}

func _set_arrived() -> void:
	var http: HTTPRequest = SupabaseClient.upsert("voyages", {
		"id": active_voyage.id,
		"status": "arrived"
	})
	await http.request_completed
	GameState.set_current_island_id(active_voyage.destination_island_id)
	active_voyage = {}
	voyage_arrived.emit()

func _set_drifting() -> void:
	var http: HTTPRequest = SupabaseClient.upsert("voyages", {
		"id": active_voyage.id,
		"status": "drifting"
	})
	await http.request_completed
	active_voyage = {}
	voyage_drifting.emit()

func _iso_to_unix(iso: String) -> float:
	return float(Time.get_unix_time_from_datetime_string(iso))