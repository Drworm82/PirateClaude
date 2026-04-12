extends Node

const SHIP_SPEED_KMH: float = 500.0
const SHIP_RANGE_KM: float = 5.0
const DOBLONES_PER_KM: int = 2

var active_voyage: Dictionary = {}
var _timer: Timer

signal voyage_updated(seconds_remaining: int, doblones_remaining: int, progress: float)
signal voyage_arrived(destination_id: String)
signal voyage_drifting()
signal check_completed

func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.one_shot = false
	_timer.timeout.connect(_tick)
	add_child(_timer)

func _process(_delta: float) -> void:
	if active_voyage.is_empty():
		return
	if not _timer.is_inside_tree() or _timer.is_stopped():
		_timer.start()

func _get_departure_unix() -> float:
	return float(active_voyage.get("departure_time", 0.0))

func _get_seconds_remaining() -> int:
	var arrival: float = float(active_voyage.get("arrival_time", 0.0))
	var now: int = int(Time.get_unix_time_from_system())
	return maxi(0, int(arrival) - now)

func _tick() -> void:
	if active_voyage.is_empty():
		return
	var seconds_remaining: int = _get_seconds_remaining()
	var now: float = Time.get_unix_time_from_system()
	var elapsed_minutes: float = (now - _get_departure_unix()) / 60.0
	var km_traveled: float = (SHIP_SPEED_KMH / 60.0) * elapsed_minutes
	var doblones_at_departure: int = active_voyage.get("doblones_at_departure", 0)
	var doblones_remaining: int = doblones_at_departure - int(km_traveled * DOBLONES_PER_KM)

	# Mantener en memoria sincronizado
	GameManager.doblones_onboard = maxi(0, doblones_remaining)

	if doblones_remaining <= 0:
		_set_drifting()
		return
	if seconds_remaining <= 0:
		_set_arrived()
		return
	var total_seconds: int = int(active_voyage.get("arrival_time", 0.0) - active_voyage.get("departure_time", 0.0))
	var progress: float = 0.0
	if total_seconds > 0:
		progress = clampf(1.0 - (float(seconds_remaining) / float(total_seconds)), 0.0, 1.0)
	voyage_updated.emit(seconds_remaining, doblones_remaining, progress)

func start_voyage(destination_island_id: String) -> void:
	GameState.debug_log("start_voyage dob:" + str(GameManager.doblones) + " onboard:" + str(GameManager.doblones_onboard))
	if GameState.get_player_id() == "":
		return
	var distance_km: float = GameState.get_distance_to(destination_island_id)
	var duration_seconds: int = int((distance_km / SHIP_SPEED_KMH) * 3600.0)
	var now: float = Time.get_unix_time_from_system()

	# ── Calcular doblones a embarcar ──────────────────────────────────────
	# Usar onboard si ya hay un viaje activo, si no tomar de doblones en tierra
	var doblones: int = GameManager.doblones_onboard
	if doblones <= 0:
		doblones = GameManager.doblones
	# Mover todos los doblones disponibles al barco
	GameManager.doblones_onboard = doblones
	GameManager.doblones = 0

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
			"origin_island_id": GameState.get_current_island_id(),
			"destination_island_id": destination_island_id,
			"departure_time": now,
			"arrival_time": now + duration_seconds,
			"doblones_at_departure": doblones,
			"doblones_per_km": DOBLONES_PER_KM,
			"distance_km": distance_km,
			"status": "sailing"
		}
		await GameManager.save_player_state()
		_timer.start(1.0)

func check_active_voyage() -> void:
	if GameState.get_player_id() == "":
		check_completed.emit()
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
		var dep_str: String = str(v.get("departure_time", "")).replace("Z", "")
		var arr_str: String = str(v.get("arrival_time", "")).replace("Z", "")
		active_voyage = {
			"id": str(v.get("id", "")),
			"origin_island_id": str(v.get("origin_island_id", "")),
			"destination_island_id": str(v.get("destination_island_id", "")),
			"departure_time": float(Time.get_unix_time_from_datetime_string(dep_str)),
			"arrival_time": float(Time.get_unix_time_from_datetime_string(arr_str)),
			"doblones_at_departure": int(v.get("doblones_at_departure", 0)),
			"doblones_per_km": int(v.get("doblones_per_km", DOBLONES_PER_KM)),
			"distance_km": float(v.get("distance_km", 0.0)),
			"status": str(v.get("status", "sailing"))
		}
		_timer.start(1.0)
		_tick()
	check_completed.emit()

func _set_arrived() -> void:
	_timer.stop()
	var destination_id: String = active_voyage.destination_island_id

	# Devolver doblones sobrantes a tierra
	var sobrantes: int = GameManager.doblones_onboard
	if sobrantes > 0:
		GameManager.doblones += sobrantes
		GameManager.doblones_onboard = 0

	GameState.set_current_island_id(destination_id)

	var http: HTTPRequest = SupabaseClient.upsert("voyages", {
		"id": active_voyage.id,
		"status": "arrived"
	})
	await http.request_completed

	active_voyage = {}
	await GameManager.save_player_state()
	voyage_arrived.emit(destination_id)

func _set_drifting() -> void:
	_timer.stop()
	GameManager.doblones_onboard = 0
	GameManager.doblones = 0
	var http: HTTPRequest = SupabaseClient.upsert("voyages", {
		"id": active_voyage.id,
		"status": "drifting"
	})
	await http.request_completed
	active_voyage = {}
	await GameManager.save_player_state()
	voyage_drifting.emit()

func _iso_to_unix(iso: String) -> float:
	return float(Time.get_unix_time_from_datetime_string(iso))