extends CanvasLayer

signal closed

enum MapMode {LOCAL, GLOBAL}
var current_mode: MapMode = MapMode.LOCAL
var dungeon_ref: Node = null
var known_islands: Array = []

func _ready() -> void:
    $Panel/Tabs/BtnIsla.pressed.connect(
        func(): _set_mode(MapMode.LOCAL))
    $Panel/Tabs/BtnOceano.pressed.connect(
        func(): _set_mode(MapMode.GLOBAL))
    $Panel/BtnCerrar.pressed.connect(
        func(): emit_signal("closed"))
    $Panel/MapDisplay.overlay_ref = self

func _set_mode(mode: MapMode) -> void:
    current_mode = mode
    $Panel/MapDisplay.queue_redraw()

func set_dungeon(dungeon: Node) -> void:
    dungeon_ref = dungeon
    $Panel/Tabs/BtnIsla.disabled = dungeon == null

func set_known_islands(islands: Array) -> void:
    known_islands = islands

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        if event.pressed and event.keycode == KEY_M:
            emit_signal("closed")
        if event.pressed and event.keycode == KEY_ESCAPE:
            emit_signal("closed")

func _on_map_draw(canvas: Control, size: Vector2) -> void:
    if current_mode == MapMode.LOCAL:
        _draw_local_map(canvas, size)
    else:
        _draw_global_map(canvas, size)

func _draw_local_map(canvas: Control, size: Vector2) -> void:
    if not is_instance_valid(dungeon_ref):
        return
    
    var dungeon_w: int = dungeon_ref.DUNGEON_WIDTH
    var dungeon_h: int = dungeon_ref.DUNGEON_HEIGHT
    var tile_size: int = dungeon_ref.TILE_SIZE
    
    canvas.draw_rect(Rect2(Vector2.ZERO, size), 
                     Color(0.102, 0.227, 0.361))
    
    var land_rect: Rect2 = dungeon_ref.land_rect
    var land_screen := Rect2(
        land_rect.position.x / (dungeon_w * tile_size) * size.x,
        land_rect.position.y / (dungeon_h * tile_size) * size.y,
        land_rect.size.x / (dungeon_w * tile_size) * size.x,
        land_rect.size.y / (dungeon_h * tile_size) * size.y
    )
    canvas.draw_rect(land_screen, Color(0.176, 0.416, 0.31))
    
    if is_instance_valid(dungeon_ref.player):
        var player_pos: Vector2 = dungeon_ref.player.position
        var px: float = player_pos.x / (dungeon_w * tile_size) * size.x
        var py: float = player_pos.y / (dungeon_h * tile_size) * size.y
        canvas.draw_circle(Vector2(px, py), 6.0, Color(0.4, 0.6, 0.9))
    
    var exit_rect: Rect2 = dungeon_ref.exit_zone_rect
    var exit_screen := Rect2(
        exit_rect.position.x / (dungeon_w * tile_size) * size.x,
        exit_rect.position.y / (dungeon_h * tile_size) * size.y,
        exit_rect.size.x / (dungeon_w * tile_size) * size.x,
        exit_rect.size.y / (dungeon_h * tile_size) * size.y
    )
    canvas.draw_rect(exit_screen, Color(0.957, 0.635, 0.38))

func _draw_global_map(canvas: Control, size: Vector2) -> void:
    canvas.draw_rect(Rect2(Vector2.ZERO, size),
                     Color(0.102, 0.227, 0.361))
    
    for island in known_islands:
        var pos: Vector2 = island.get("pos", Vector2.ZERO)
        var is_home: bool = island.get("is_home", false)
        var screen_x: float = pos.x / 1280.0 * size.x
        var screen_y: float = pos.y / 720.0 * size.y
        var color := Color(0.8, 0.6, 0.2) if is_home \
                     else Color(0.176, 0.416, 0.31)
        var radius: float = 20.0 if is_home else 15.0
        canvas.draw_circle(Vector2(screen_x, screen_y), 
                           radius, color)
        
        var island_name: String = island.get("name", "Isla")
        canvas.draw_string(
            ThemeDB.fallback_font,
            Vector2(screen_x - 20, screen_y - 22),
            island_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
            Color.WHITE
        )
