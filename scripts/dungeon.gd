extends Node2D
class_name Dungeon

signal player_exited_dungeon
signal destination_chosen(destination: String)

@onready var player = $Player
var joystick = null

const OCEAN_COLOR := Color(0.102, 0.227, 0.361)
const LAND_COLOR := Color(0.176, 0.416, 0.31)
const EXIT_ZONE_COLOR := Color(0.957, 0.635, 0.38)

const TILE_SIZE := 32
const ISLAND_SIZE_TILES := 20
const DUNGEON_WIDTH := 40
const DUNGEON_HEIGHT := 40

var island_seed: int = 0
var island_pos: Vector2 = Vector2.ZERO
var land_rect: Rect2
var exit_zone_rect: Rect2
var destination_menu: DestinationMenu = null
var context_button = null

func _ready() -> void:
	land_rect = Rect2(
		(DUNGEON_WIDTH - ISLAND_SIZE_TILES) / 2.0 * TILE_SIZE,
		(DUNGEON_HEIGHT - ISLAND_SIZE_TILES) / 2.0 * TILE_SIZE,
		ISLAND_SIZE_TILES * TILE_SIZE,
		ISLAND_SIZE_TILES * TILE_SIZE
	)
	exit_zone_rect = Rect2(
		(DUNGEON_WIDTH / 2.0 - 4) * TILE_SIZE,
		(DUNGEON_HEIGHT - 3) * TILE_SIZE,
		8 * TILE_SIZE,
		2 * TILE_SIZE
	)

	_center_camera()

	await get_tree().process_frame
	var cam: Camera2D = $Player/Camera2D
	cam.reset_smoothing()
	cam.force_update_scroll()

	$TileMap.clear()
	$Boat.player_boarded.connect(_on_player_boarded)
	$Boat.set_player_ref(player)

	joystick = get_tree().get_first_node_in_group("joystick")

	var btn_scene: PackedScene = preload("res://scenes/context_action_button.tscn")
	context_button = btn_scene.instantiate()
	add_child(context_button)
	context_button.action_pressed.connect(_on_context_pressed)
	context_button.process_mode = Node.PROCESS_MODE_DISABLED

	if joystick:
		joystick.set_enabled(true)

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return

	var exit_center := Vector2(
		DUNGEON_WIDTH * TILE_SIZE / 2.0,
		(DUNGEON_HEIGHT - 2) * TILE_SIZE
	)

	if player.global_position.distance_to(exit_center) < 120.0:
		_exit_dungeon()
		return

	if is_instance_valid($Boat) and context_button != null:
		var dist: float = player.global_position.distance_to($Boat.global_position)
		if dist < 80.0:
			context_button.process_mode = Node.PROCESS_MODE_ALWAYS
			context_button.show_action("Abordar")
		else:
			context_button.process_mode = Node.PROCESS_MODE_DISABLED
			context_button.hide_action()

func _draw() -> void:
	var dungeon_rect := Rect2(0, 0, DUNGEON_WIDTH * TILE_SIZE, DUNGEON_HEIGHT * TILE_SIZE)
	draw_rect(dungeon_rect, OCEAN_COLOR)
	draw_rect(land_rect, LAND_COLOR)
	draw_rect(exit_zone_rect, EXIT_ZONE_COLOR)

func setup(p_seed: int, pos: Vector2) -> void:
	island_seed = p_seed
	island_pos = pos

func _center_camera() -> void:
	var land_center := land_rect.position + land_rect.size / 2.0
	player.position = land_center
	player.bounds_max = Vector2(
		DUNGEON_WIDTH * TILE_SIZE,
		DUNGEON_HEIGHT * TILE_SIZE
	)

func _on_player_boarded(_destination: String) -> void:
	_show_destination_menu()

func _on_context_pressed() -> void:
	_show_destination_menu()

func _show_destination_menu() -> void:
	if GameManager.ship_hp <= 0:
		return

	context_button.hide_action()

	var menu_scene: PackedScene = preload("res://scenes/destination_menu.tscn")
	destination_menu = menu_scene.instantiate()
	add_child(destination_menu)
	destination_menu.setup(GameManager.current_island_name)
	destination_menu.destination_selected.connect(_on_destination_selected)
	destination_menu.cancelled.connect(_on_destination_cancelled)

	player.can_move = false
	if joystick:
		joystick.set_enabled(false)

func _on_destination_selected(destination: String) -> void:
	if destination_menu:
		destination_menu.queue_free()
		destination_menu = null
	player.can_move = true
	if joystick:
		joystick.set_enabled(true)
	emit_signal("destination_chosen", destination)
	emit_signal("player_exited_dungeon")

func _on_destination_cancelled() -> void:
	if destination_menu:
		destination_menu.queue_free()
		destination_menu = null
	player.can_move = true
	if joystick:
		joystick.set_enabled(true)

func _exit_dungeon() -> void:
	player.exit_dungeon()
	emit_signal("player_exited_dungeon")
	queue_free()
