extends CharacterBody2D
class_name Player

const SPEED := 200.0
var can_move: bool = true
var bounds_min: Vector2 = Vector2.ZERO
var bounds_max: Vector2 = Vector2(1280, 1280)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 16.0, Color(0.4, 0.6, 0.9))

func _physics_process(_delta: float) -> void:
	if not can_move:
		return
	var direction := Input.get_vector(
		"move_left", "move_right", "move_up", "move_down"
	)
	velocity = direction * SPEED
	move_and_slide()
	position.x = clamp(position.x, bounds_min.x + 16, bounds_max.x - 16)
	position.y = clamp(position.y, bounds_min.y + 16, bounds_max.y - 16)

func exit_dungeon() -> void:
	can_move = false
	velocity = Vector2.ZERO
