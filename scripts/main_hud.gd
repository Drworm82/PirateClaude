extends CanvasLayer

signal menu_pressed
signal work_pressed
signal inventory_pressed
signal map_pressed
signal action_pressed

enum ActionState {
	NONE,
	ENTER_ISLAND,
	SAIL,
	VIEW_SHIP,
	BOARD,
}

var _current_state: ActionState = ActionState.NONE
var _btn_action: Button
var input_enabled: bool = true

func _ready() -> void:
	add_to_group("main_hud")
	_btn_action = get_node("BottomBar/BottomBox/BtnAction")
	var safe_top: int = DisplayServer.get_display_safe_area().position.y
	get_node("Header").position.y = safe_top
	set_action_state(ActionState.NONE)

func set_action_state(state: ActionState) -> void:
	_current_state = state
	match state:
		ActionState.NONE:
			_btn_action.text = "—"
			_btn_action.disabled = true
		ActionState.ENTER_ISLAND:
			_btn_action.text = "Entrar"
			_btn_action.disabled = false
		ActionState.SAIL:
			_btn_action.text = "Zarpar"
			_btn_action.disabled = false
		ActionState.VIEW_SHIP:
			_btn_action.text = "Ver barco"
			_btn_action.disabled = false
		ActionState.BOARD:
			_btn_action.text = "Abordar"
			_btn_action.disabled = false

func _on_menu_pressed() -> void:
	menu_pressed.emit()

func _on_work_pressed() -> void:
	work_pressed.emit()

func _on_inventory_pressed() -> void:
	inventory_pressed.emit()

func _on_map_pressed() -> void:
	map_pressed.emit()

func _on_action_pressed() -> void:
	action_pressed.emit(_current_state)


func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if not event is InputEventScreenTouch and not event is InputEventMouseButton:
		return
	var pressed: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = true
		pos = event.position
	if not pressed:
		return

	var btn_menu = get_node("Header/HeaderBox/BtnMenu")
	var btn_work = get_node("Header/HeaderBox/BtnWork")
	var btn_inventory = get_node("BottomBar/BottomBox/BtnInventory")
	var btn_map = get_node("BottomBar/BottomBox/BtnMap")

	if btn_menu.get_global_rect().has_point(pos):
		menu_pressed.emit()
	elif btn_work.get_global_rect().has_point(pos):
		work_pressed.emit()
	elif btn_inventory.get_global_rect().has_point(pos):
		inventory_pressed.emit()
	elif btn_map.get_global_rect().has_point(pos):
		map_pressed.emit()
	elif not _btn_action.disabled and _btn_action.get_global_rect().has_point(pos):
		action_pressed.emit(int(_current_state))


func disable_for_menu() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED


func enable_after_menu() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true