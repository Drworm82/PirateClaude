extends CharacterBody2D
class_name Player

const SPEED := 200.0

var can_move: bool = true
var bounds_min: Vector2 = Vector2.ZERO
var bounds_max: Vector2 = Vector2(1280, 1280)

func _ready() -> void:
    var texture := load("res://assets/sprites/pirates.webp")
    if texture:
        var sprite := $Sprite2D
        sprite.texture = texture
        sprite.region_enabled = true
        sprite.region_rect = Rect2(711, 832, 205, 332)
        sprite.scale = Vector2(0.25, 0.25)

func _physics_process(_delta: float) -> void:
    if not can_move:
        return

    var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

    velocity = dir * SPEED
    move_and_slide()

    position.x = clamp(position.x, bounds_min.x + 16, bounds_max.x - 16)
    position.y = clamp(position.y, bounds_min.y + 16, bounds_max.y - 16)

    if dir != Vector2.ZERO:
        rotation = dir.angle() + PI / 2.0

func exit_dungeon() -> void:
    can_move = false
    velocity = Vector2.ZERO