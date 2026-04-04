extends Area2D
class_name Boat

signal player_boarded(destination: String)

var player_ref = null

var _prompt_visible: bool = false

func _ready() -> void:
	pass

func set_player_ref(p) -> void:
	player_ref = p

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player_ref):
		return

	if player_ref.global_position.distance_to(global_position) < 80.0:
		if not _prompt_visible:
			_prompt_visible = true
			queue_redraw()
	else:
		if _prompt_visible:
			_prompt_visible = false
			queue_redraw()

func _draw() -> void:
	if _prompt_visible:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-40, -60),
			"E — Abordar",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color.WHITE
		)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_E:
			if _prompt_visible:
				emit_signal("player_boarded", "menu")
