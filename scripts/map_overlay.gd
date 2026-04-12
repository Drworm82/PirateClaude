extends CanvasLayer

signal closed

enum MapMode {LOCAL, GLOBAL}
var current_mode: MapMode = MapMode.LOCAL
var dungeon_ref: Node = null
var known_islands: Array = []

# Rect del botón cerrar para detección manual de touch
var _btn_cerrar_rect: Rect2 = Rect2()
var _safe_area_offset: float = 0.0

func _ready() -> void:
	# Calcular safe area offset (notch Android)
	_safe_area_offset = DisplayServer.get_display_safe_area().position.y

	$Panel/Tabs/BtnIsla.pressed.connect(
		func(): _set_mode(MapMode.LOCAL))
	$Panel/Tabs/BtnOceano.pressed.connect(
		func(): _set_mode(MapMode.GLOBAL))

	# BtnCerrar: NO conectar .pressed — falla en Android
	# Se maneja con detección manual en _input()

	$Panel/MapDisplay.overlay_ref = self

	# Forzar Panel a ocupar toda la pantalla en cualquier orientación
	_fit_panel_to_screen()

func _fit_panel_to_screen() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var panel: Panel = $Panel
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left   = 0
	panel.offset_top    = 0
	panel.offset_right  = 0
	panel.offset_bottom = 0

func _set_mode(mode: MapMode) -> void:
	current_mode = mode
	$Panel/MapDisplay.queue_redraw()

func set_dungeon(dungeon: Node) -> void:
	dungeon_ref = dungeon
	$Panel/Tabs/BtnIsla.disabled = dungeon == null

func set_known_islands(islands: Array) -> void:
	known_islands = islands

# ── Cierre por teclado (PC) ───────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_M:
			_close()
		if event.pressed and event.keycode == KEY_ESCAPE:
			_close()
		return

	# ── Cierre por touch (Android) ────────────────────────────────────────
	if event is InputEventScreenTouch and event.pressed:
		var raw_y: float = event.position.y
		var adj_y: float = raw_y - _safe_area_offset
		var touch_pos := Vector2(event.position.x, adj_y)

		# Calcular rect del botón cerrar en tiempo real
		# (el panel puede haber cambiado de tamaño al rotar)
		var btn: Button = $Panel/BtnCerrar
		if btn.get_global_rect().has_point(Vector2(event.position.x, raw_y)):
			_close()
			get_viewport().set_input_as_handled()

func _close() -> void:
	emit_signal("closed")

# ── Draw callbacks ────────────────────────────────────────────────────────
func _on_map_draw(canvas: Control, size: Vector2) -> void:
	if current_mode == MapMode.LOCAL:
		_draw_local_map(canvas, size)
	else:
		_draw_global_map(canvas, size)

func _draw_local_map(canvas: Control, size: Vector2) -> void:
	if not is_instance_valid(dungeon_ref):
		canvas.draw_rect(Rect2(Vector2.ZERO, size), Color(0.102, 0.227, 0.361))
		canvas.draw_string(
			ThemeDB.fallback_font,
			size * 0.5 - Vector2(60, 0),
			"Fuera de isla", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE
		)
		return

	var dungeon_w: int = dungeon_ref.DUNGEON_WIDTH
	var dungeon_h: int = dungeon_ref.DUNGEON_HEIGHT
	var tile_size: int = dungeon_ref.TILE_SIZE

	canvas.draw_rect(Rect2(Vector2.ZERO, size),
					 Color(0.102, 0.227, 0.361))

	var land_rect: Rect2 = dungeon_ref.land_rect
	var total_w: float = dungeon_w * tile_size
	var total_h: float = dungeon_h * tile_size

	var land_screen := Rect2(
		land_rect.position.x / total_w * size.x,
		land_rect.position.y / total_h * size.y,
		land_rect.size.x     / total_w * size.x,
		land_rect.size.y     / total_h * size.y
	)
	canvas.draw_rect(land_screen, Color(0.176, 0.416, 0.31))

	if is_instance_valid(dungeon_ref.player):
		var player_pos: Vector2 = dungeon_ref.player.position
		var px: float = player_pos.x / total_w * size.x
		var py: float = player_pos.y / total_h * size.y
		canvas.draw_circle(Vector2(px, py), 6.0, Color(0.4, 0.6, 0.9))

	var exit_rect: Rect2 = dungeon_ref.exit_zone_rect
	var exit_screen := Rect2(
		exit_rect.position.x / total_w * size.x,
		exit_rect.position.y / total_h * size.y,
		exit_rect.size.x     / total_w * size.x,
		exit_rect.size.y     / total_h * size.y
	)
	canvas.draw_rect(exit_screen, Color(0.957, 0.635, 0.38))

func _draw_global_map(canvas: Control, size: Vector2) -> void:
	canvas.draw_rect(Rect2(Vector2.ZERO, size),
					 Color(0.102, 0.227, 0.361))

	if known_islands.is_empty():
		canvas.draw_string(
			ThemeDB.fallback_font,
			size * 0.5 - Vector2(60, 0),
			"Sin islas conocidas", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE
		)
		return

	# Calcular bounding box real de las islas conocidas
	# en vez de asumir 1280x720 fijo
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF

	for island in known_islands:
		var pos: Vector2 = island.get("pos", Vector2.ZERO)
		min_x = min(min_x, pos.x)
		max_x = max(max_x, pos.x)
		min_y = min(min_y, pos.y)
		max_y = max(max_y, pos.y)

	# Padding para que las islas en los bordes no queden cortadas
	var padding: float = 60.0
	var range_x: float = max(max_x - min_x, 1.0)
	var range_y: float = max(max_y - min_y, 1.0)

	for island in known_islands:
		var pos: Vector2 = island.get("pos", Vector2.ZERO)
		var is_home: bool = island.get("is_home", false)

		# Normalizar contra bounding box real, con padding
		var screen_x: float = padding + (pos.x - min_x) / range_x * (size.x - padding * 2)
		var screen_y: float = padding + (pos.y - min_y) / range_y * (size.y - padding * 2)

		var color := Color(0.8, 0.6, 0.2) if is_home \
					 else Color(0.176, 0.416, 0.31)
		var radius: float = 20.0 if is_home else 15.0
		canvas.draw_circle(Vector2(screen_x, screen_y), radius, color)

		var island_name: String = island.get("name", "Isla")
		canvas.draw_string(
			ThemeDB.fallback_font,
			Vector2(screen_x - 20, screen_y - 25),
			island_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color.WHITE
		)