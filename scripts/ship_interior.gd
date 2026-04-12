extends Node2D
class_name ShipInterior

const SHIP_WIDTH: float  = 120.0
const SHIP_HEIGHT: float = 220.0
const SHIP_COLOR       := Color(0.35, 0.22, 0.12)
const DECK_COLOR       := Color(0.55, 0.38, 0.22)
const WATER_COLOR      := Color(0.10, 0.22, 0.36)
const MAST_COLOR       := Color(0.25, 0.15, 0.08)
const BARREL_COLOR     := Color(0.40, 0.28, 0.15)

@onready var player = $Player
var joystick = null
var _initialized: bool = false
var ship_type: String = "lancha"
var _camera: Camera2D = null

func _ready() -> void:
	# Desactivar la Camera2D del player — usamos la nuestra
	var player_cam: Camera2D = player.get_node_or_null("Camera2D")
	if player_cam:
		player_cam.enabled = false

	# Crear cámara propia centrada en el barco
	_camera = Camera2D.new()
	_camera.position = Vector2.ZERO
	_camera.zoom = Vector2(1.5, 1.5)
	add_child(_camera)
	_camera.make_current()

	joystick = get_tree().get_first_node_in_group("joystick")
	if joystick:
		joystick.set_enabled(true)

	await get_tree().process_frame
	player.position = Vector2(0.0, 20.0)
	player.can_move = true
	_initialized = true
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not _initialized:
		return
	if is_instance_valid(player):
		player.position.x = clamp(player.position.x, -SHIP_WIDTH / 2.0 + 16.0, SHIP_WIDTH / 2.0 - 16.0)
		player.position.y = clamp(player.position.y, -SHIP_HEIGHT / 2.0 + 16.0, SHIP_HEIGHT / 2.0 - 16.0)

func _draw() -> void:
	if not _initialized:
		return

	# Fondo océano
	draw_rect(Rect2(-400, -600, 800, 1200), WATER_COLOR)
	for i in range(-7, 8):
		draw_line(Vector2(-300, i * 80.0), Vector2(300, i * 80.0),
				  Color(0.15, 0.30, 0.50, 0.3), 2.0)

	# Casco
	var hull := PackedVector2Array([
		Vector2(0, -SHIP_HEIGHT / 2.0 - 20.0),
		Vector2(SHIP_WIDTH / 2.0, -SHIP_HEIGHT / 2.0 + 40.0),
		Vector2(SHIP_WIDTH / 2.0, SHIP_HEIGHT / 2.0 - 20.0),
		Vector2(0, SHIP_HEIGHT / 2.0 + 10.0),
		Vector2(-SHIP_WIDTH / 2.0, SHIP_HEIGHT / 2.0 - 20.0),
		Vector2(-SHIP_WIDTH / 2.0, -SHIP_HEIGHT / 2.0 + 40.0),
	])
	draw_colored_polygon(hull, SHIP_COLOR)

	# Cubierta
	var deck := Rect2(-SHIP_WIDTH / 2.0 + 10.0, -SHIP_HEIGHT / 2.0 + 50.0,
					   SHIP_WIDTH - 20.0, SHIP_HEIGHT - 80.0)
	draw_rect(deck, DECK_COLOR)
	for i in range(5):
		var tx: float = deck.position.x + (deck.size.x / 5.0) * i
		draw_line(Vector2(tx, deck.position.y), Vector2(tx, deck.end.y),
				  Color(0.45, 0.30, 0.18, 0.5), 1.5)

	# Mástil
	draw_circle(Vector2(0, -20.0), 8.0, MAST_COLOR)
	draw_circle(Vector2(0, -20.0), 4.0, Color(0.15, 0.10, 0.05))
	var sail := PackedVector2Array([
		Vector2(0, -80.0), Vector2(40.0, -20.0), Vector2(-40.0, -20.0),
	])
	draw_colored_polygon(sail, Color(0.9, 0.85, 0.75, 0.8))
	draw_polyline(sail, Color(0.6, 0.5, 0.3), 1.5, true)

	# Barriles
	_draw_barrel(Vector2(-40.0, 40.0))
	_draw_barrel(Vector2(-40.0, 65.0))
	_draw_barrel(Vector2(40.0, 40.0))

	# Timón
	draw_circle(Vector2(0, 70.0), 14.0, MAST_COLOR)
	draw_circle(Vector2(0, 70.0), 10.0, DECK_COLOR)
	for angle in [0, 60, 120]:
		var rad: float = deg_to_rad(float(angle))
		var dir := Vector2(cos(rad), sin(rad)) * 14.0
		draw_line(Vector2(0, 70.0) - dir, Vector2(0, 70.0) + dir, MAST_COLOR, 2.0)

	# Label
	draw_string(ThemeDB.fallback_font, Vector2(-50, -SHIP_HEIGHT / 2.0 + 20.0),
		"Cubierta — Lancha", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)

func _draw_barrel(pos: Vector2) -> void:
	draw_circle(pos, 10.0, BARREL_COLOR)
	draw_circle(pos, 10.0, Color(0.25, 0.15, 0.05), false)
	draw_line(pos + Vector2(-10, 0), pos + Vector2(10, 0), Color(0.25, 0.15, 0.05), 1.5)

func disable_camera() -> void:
	if is_instance_valid(_camera):
		_camera.enabled = false

func enable_camera() -> void:
	if is_instance_valid(_camera):
		_camera.enabled = true
		_camera.make_current()

func enter_ship(type: String = "lancha") -> void:
	ship_type = type
	queue_redraw()

func exit_ship() -> void:
	# Reactivar cámara del player al salir
	if is_instance_valid(player):
		var player_cam: Camera2D = player.get_node_or_null("Camera2D")
		if player_cam:
			player_cam.enabled = true
	if joystick:
		joystick.set_enabled(false)
	queue_free()