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
		OS.request_permissions()
		await get_tree().create_timer(1.0).timeout
		_start_gps()
	else:
		state = State.ACTIVE
		call_deferred("_emit_fallback")


func _start_gps() -> void:
	var activity_class = JavaClassWrapper.wrap("android.app.ActivityThread")
	if activity_class == null:
		last_lat = 1.1
		state = State.UNAVAILABLE
		return

	var app = activity_class.currentApplication()
	if app == null:
		last_lat = 1.2
		state = State.UNAVAILABLE
		return

	var context = app.getApplicationContext()
	if context == null:
		last_lat = 1.3
		state = State.UNAVAILABLE
		return

	last_lat = 1.5  # debug: contexto obtenido

	_location_manager = context.getSystemService("location")
	if _location_manager == null:
		last_lat = 2.0
		state = State.UNAVAILABLE
		return

	last_lat = 2.5  # debug: LocationManager obtenido

	if not _location_manager.isProviderEnabled(PROVIDER):
		last_lat = 3.0
		state = State.UNAVAILABLE
		return

	state = State.ACTIVE
	last_lat = 4.0  # debug: todo OK

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