extends Control

@export var outer_ring: Control
@export var inner_dot: Control

var _enabled: bool = true
var dragging: bool = false
var origin: Vector2 = Vector2.ZERO
var _touch_index: int = -1

const MAX_RADIUS: float = 80.0
const DEAD_ZONE: float = 10.0

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	if outer_ring:
		outer_ring.visible = false
	if inner_dot:
		inner_dot.visible = false

func set_enabled(value: bool) -> void:
	_enabled = value
	if not value:
		dragging = false
		_touch_index = -1
		_reset_input()
		_hide()

func _unhandled_input(event):
	if not _enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			origin = event.position
			_show(origin)
		else:
			dragging = false
			_reset_input()
			_hide()
	elif event is InputEventMouseMotion and dragging and _touch_index == -1:
		_update_direction(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			var context_btn = get_tree().get_first_node_in_group("context_button")
			if context_btn != null and context_btn.visible:
				var btn = context_btn.get_node_or_null("Button")
				if btn != null and btn.visible:
					var btn_rect = btn.get_global_rect()
					if btn_rect.has_point(event.position):
						return
			var dest_menu = get_tree().get_first_node_in_group("destination_menu")
			if dest_menu != null and dest_menu.visible:
				return
			_touch_index = event.index
			dragging = true
			origin = event.position
			_show(origin)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			dragging = false
			_reset_input()
			_hide()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_direction(event.position)

func _update_direction(pos: Vector2) -> void:
	var delta_vec: Vector2 = pos - origin
	var clamped: Vector2 = delta_vec.limit_length(MAX_RADIUS)
	var dir: Vector2 = Vector2.ZERO
	if delta_vec.length() > DEAD_ZONE:
		dir = clamped / MAX_RADIUS
	_apply_input(dir)
	if inner_dot:
		inner_dot.global_position = origin + clamped - inner_dot.size * 0.5

func _apply_input(dir: Vector2) -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")
	if dir.x < -0.3:
		Input.action_press("move_left")
	if dir.x > 0.3:
		Input.action_press("move_right")
	if dir.y < -0.3:
		Input.action_press("move_up")
	if dir.y > 0.3:
		Input.action_press("move_down")

func _reset_input() -> void:
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_up")
	Input.action_release("move_down")

func _show(pos: Vector2) -> void:
	if outer_ring:
		outer_ring.visible = true
		outer_ring.global_position = pos - outer_ring.size * 0.5
	if inner_dot:
		inner_dot.visible = true
		inner_dot.global_position = pos - inner_dot.size * 0.5

func _hide() -> void:
	if outer_ring:
		outer_ring.visible = false
	if inner_dot:
		inner_dot.visible = false