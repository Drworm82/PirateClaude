extends Node2D
class_name Dungeon

signal player_exited_dungeon

@onready var player: Player = $Player
@onready var camera: Camera2D = $Camera2D
@onready var exit_zone: Area2D = $ExitZone
@onready var exit_zone_shape: CollisionShape2D = $ExitZone/CollisionShape2D

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
	
	_set_exit_zone_shape()
	exit_zone.body_entered.connect(_on_exit_zone_body_entered)

func _draw() -> void:
	var dungeon_rect := Rect2(0, 0, DUNGEON_WIDTH * TILE_SIZE, DUNGEON_HEIGHT * TILE_SIZE)
	draw_rect(dungeon_rect, OCEAN_COLOR)
	draw_rect(land_rect, LAND_COLOR)
	draw_rect(exit_zone_rect, EXIT_ZONE_COLOR)

func setup(p_seed: int, pos: Vector2) -> void:
	island_seed = p_seed
	island_pos = pos
	_center_camera()

func _set_exit_zone_shape() -> void:
	if exit_zone_shape:
		exit_zone_shape.shape.size = Vector2(200, 40)
		exit_zone_shape.position = exit_zone_rect.position + exit_zone_rect.size / 2.0

func _center_camera() -> void:
	if camera:
		camera.position = Vector2(DUNGEON_WIDTH, DUNGEON_HEIGHT) * TILE_SIZE / 2.0

func _on_exit_zone_body_entered(body: Node2D) -> void:
	if body is Player:
		_exit_dungeon()

func _exit_dungeon() -> void:
	player.exit_dungeon()
	emit_signal("player_exited_dungeon")
	queue_free()
