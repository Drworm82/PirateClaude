extends CharacterBody2D

@export var speed := 200.0

var bounds_max: Vector2 = Vector2.ZERO  # límite del dungeon, asignado por dungeon.gd
var can_move: bool = true               # desactivado durante menús

func _physics_process(delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction := Vector2.ZERO
	# Joystick virtual (Android) — move_left/right/up/down
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	# Teclado PC — ui_left/right/up/down como fallback
	if direction == Vector2.ZERO:
		direction.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
		direction.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	velocity = direction.normalized() * speed
	move_and_slide()

	# Limitar posición dentro del dungeon si bounds_max está definido
	if bounds_max != Vector2.ZERO:
		position.x = clamp(position.x, 0.0, bounds_max.x)
		position.y = clamp(position.y, 0.0, bounds_max.y)

func exit_dungeon() -> void:
	pass