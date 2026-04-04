# gps_service.gd
# Autoload: GpsService
extends Node

signal location_updated(lat: float, lng: float)
signal location_error(reason: String)

enum State { IDLE, WAITING_PERMISSION, ACTIVE, UNAVAILABLE }

var state: State = State.IDLE
var last_lat: float = 19.4326
var last_lng: float = -99.1332

var _location_manager = null
var _is_android: bool = false
var _poll_timer: float = 0.0

const PROVIDER = "gps"
const POLL_INTERVAL: float = 5.0


func _ready() -> void:
	_is_android = OS.get_name() == "Android"
	if _is_android:
		_request_permission()
	else:
		state = State.ACTIVE
		call_deferred("_emit_fallback")


func _emit_fallback() -> void:
	emit_signal("location_updated", last_lat, last_lng)


func _request_permission() -> void:
	state = State.WAITING_PERMISSION
	OS.request_permissions()


func _on_request_permissions_result(permissions: PackedStringArray, granted: PackedStringArray) -> void:
	if "android.permission.ACCESS_FINE_LOCATION" in granted:
		_start_gps()
	else:
		state = State.UNAVAILABLE
		emit_signal("location_error", "Permiso de ubicación denegado")


func _start_gps() -> void:
	var activity = Engine.get_singleton("GodotFragment")
	if activity == null:
		emit_signal("location_error", "No se pudo acceder al contexto Android")
		state = State.UNAVAILABLE
		return

	_location_manager = activity.getSystemService("location")
	if _location_manager == null:
		emit_signal("location_error", "LocationManager no disponible")
		state = State.UNAVAILABLE
		return

	if not _location_manager.isProviderEnabled(PROVIDER):
		emit_signal("location_error", "GPS desactivado en el dispositivo")
		state = State.UNAVAILABLE
		return

	state = State.ACTIVE

	var last_known = _location_manager.getLastKnownLocation(PROVIDER)
	if last_known != null:
		last_lat = last_known.getLatitude()
		last_lng = last_known.getLongitude()
		emit_signal("location_updated", last_lat, last_lng)


func _process(delta: float) -> void:
	if state != State.ACTIVE or not _is_android or _location_manager == null:
		return
	_poll_timer += delta
	if _poll_timer >= POLL_INTERVAL:
		_poll_timer = 0.0
		_poll_location()


func _poll_location() -> void:
	var loc = _location_manager.getLastKnownLocation(PROVIDER)
	if loc != null:
		var lat = loc.getLatitude()
		var lng = loc.getLongitude()
		if lat != last_lat or lng != last_lng:
			last_lat = lat
			last_lng = lng
			emit_signal("location_updated", lat, lng)


func get_current_location() -> Vector2:
	return Vector2(last_lat, last_lng)


func stop() -> void:
	if _location_manager != null:
		_location_manager.removeUpdates(null)
	state = State.IDLE