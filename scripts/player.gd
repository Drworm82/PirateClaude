extends CharacterBody2D
class_name Player

const SPEED := 200.0
var can_move: bool = true

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

func exit_dungeon() -> void:
	can_move = false
	velocity = Vector2.ZERO
