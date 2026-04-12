# Reglas GDScript — Godot 4

## Constantes y valores por defecto

### CORRECTO
```gdscript
var rect: Rect2 = Rect2()
var vec2: Vector2 = Vector2.ZERO
var vec3: Vector3 = Vector3.ZERO
var color: Color = Color.WHITE
var transform: Transform2D = Transform2D.IDENTITY
var basis: Basis = Basis.IDENTITY
var arr: Array = []
var dict: Dictionary = {}
var str_val: String = ""
```

### INCORRECTO — no existen en Godot 4
```gdscript
Rect2.ZERO        # ❌ usar Rect2()
Rect2i.ZERO       # ❌ usar Rect2i()
Transform.IDENTITY # ❌ usar Transform2D.IDENTITY
Color.TRANSPARENT  # ❌ usar Color(0,0,0,0)
```

---

## Tipos y anotaciones

### CORRECTO
```gdscript
var speed: float = 200.0
var health: int = 100
var name: String = "player"
var active: bool = true
var nodes: Array[Node] = []
var items: Array[String] = []
@export var speed: float = 200.0
@onready var label: Label = $Label
```

### INCORRECTO
```gdscript
var speed = 200       # ❌ sin tipo (strict mode)
export var speed = 200 # ❌ sintaxis Godot 3
onready var label = $Label # ❌ sintaxis Godot 3
```

---

## Señales

### CORRECTO
```gdscript
signal health_changed(new_value: int)
signal player_died

# Emitir
health_changed.emit(current_health)
player_died.emit()

# Conectar
health_changed.connect(_on_health_changed)
node.signal_name.connect(func(val): print(val))
```

### INCORRECTO
```gdscript
emit_signal("health_changed", value)  # ❌ Godot 3
connect("health_changed", self, "_on") # ❌ Godot 3
```

---

## Nodos y escenas

### CORRECTO
```gdscript
@onready var sprite: Sprite2D = $Sprite2D
@onready var timer: Timer = $Timer

var scene: PackedScene = preload("res://scenes/player.tscn")
var instance: Node = scene.instantiate()
add_child(instance)

# Buscar nodos
get_node("Panel/VBoxContainer/Label")
get_node_or_null("Panel/Label")
get_tree().get_first_node_in_group("joystick")
```

### INCORRECTO
```gdscript
var sprite = $Sprite    # ❌ sin tipo, sin @onready
instance(scene)         # ❌ Godot 3
.instance()             # ❌ Godot 3
get_node("Label").set_text() # ❌ sin verificar validez
```

---

## Movimiento

### CharacterBody2D
```gdscript
extends CharacterBody2D

func _physics_process(delta: float) -> void:
    var direction: Vector2 = Vector2.ZERO
    direction.x = Input.get_axis("ui_left", "ui_right")
    direction.y = Input.get_axis("ui_up", "ui_down")
    velocity = direction * speed
    move_and_slide()
```

### INCORRECTO
```gdscript
move_and_slide(velocity, Vector2.UP)  # ❌ Godot 3
move_and_collide(velocity * delta)    # ❌ para CharacterBody2D
```

---

## Input

### CORRECTO
```gdscript
Input.get_axis("ui_left", "ui_right")
Input.get_action_strength("ui_right")
Input.is_action_pressed("jump")
Input.is_action_just_pressed("jump")

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_ESCAPE:
            pass

func _unhandled_input(event: InputEvent) -> void:
    pass
```

### INCORRECTO
```gdscript
Input.is_key_pressed(KEY_W)  # ❌ evitar, usar actions
event.scancode               # ❌ Godot 3, usar keycode
```

---

## HTTP / Supabase en este proyecto

### CORRECTO
```gdscript
# Siempre usar supabase_rpc() — NO rpc() que es reservado
var http = SupabaseClient.supabase_rpc("nombre_funcion", params)
var result = await http.request_completed

# Headers correctos
func _get_headers() -> Array:
    return [
        "Content-Type: application/json",
        "apikey: " + ANON_KEY,
        "Authorization: Bearer " + _access_token
    ]
```

### INCORRECTO
```gdscript
SupabaseClient.rpc()  # ❌ rpc es reservado en Godot 4 multiplayer
await supabase.get()  # ❌ no existe
```

---

## Autoloads en este proyecto

```
GameManager     → scripts/game_manager.gd
GameState       → autoloads/GameState.gd   (puente a GameManager)
VoyageManager   → autoloads/VoyageManager.gd
GpsService      → scripts/gps_service.gd
SupabaseClient  → scripts/supabase.gd
TravelEvents    → scripts/travel_events.gd
MapButton       → scripts/map_button.gd
```

### CORRECTO
```gdscript
GameManager.doblones
GameState.get_doblones_onboard()
VoyageManager.start_voyage(destination_id)
GpsService.last_lat
SupabaseClient.supabase_rpc("funcion", params)
```

### INCORRECTO
```gdscript
get_node("/root/GameManager")  # ❌ usar nombre directo
$GameManager                   # ❌ no es hijo de escena
GameManager.new()              # ❌ es autoload, ya existe
```

---

## Touch en Android — patrón establecido

```gdscript
# Los Button nativos NO detectan touch en este proyecto
# Siempre usar detección manual:

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        var safe_offset: float = DisplayServer.get_display_safe_area().position.y
        var adj_pos := Vector2(event.position.x, event.position.y - safe_offset)
        if $Panel/MiBoton.get_global_rect().has_point(adj_pos):
            _on_mi_boton_pressed()
            get_viewport().set_input_as_handled()
```

---

## CanvasLayer

```gdscript
# Layer recomendados en este proyecto:
# 2  — VirtualJoystick
# 10 — VoyageHUD
# 15 — ArrivalMenu
# 20 — (obsoleto: ContextActionButton)
# 25 — MainHud
# 30 — DestinationMenu
# 99 — DebugOverlay

# Panel full screen en CanvasLayer:
func _ready() -> void:
    $Panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    $Panel.offset_left   = 0
    $Panel.offset_top    = 0
    $Panel.offset_right  = 0
    $Panel.offset_bottom = 0
```

---

## _draw() en Android

```gdscript
# get_viewport_rect().size puede ser (0,0) en _ready()
# Calcular en _physics_process cuando size.x > 0:

var _initialized: bool = false

func _physics_process(_delta: float) -> void:
    if _initialized:
        return
    var vp_size: Vector2 = get_viewport_rect().size
    if vp_size.x > 0:
        _map_center = vp_size * 0.5
        _initialized = true
        queue_redraw()
```

---

## Prohibido siempre

```
def           — Python, no GDScript
{}            — bloques C/JS, no GDScript  
Vector3       — juego 2D
pseudo código — solo código real ejecutable
funciones inventadas — solo API real de Godot 4
print() en producción — usar GameState.debug_log()
Rect2.ZERO    — no existe, usar Rect2()
Rect2i.ZERO   — no existe, usar Rect2i()
.instance()   — Godot 3, usar .instantiate()
emit_signal() — Godot 3, usar signal.emit()
connect(str)  — Godot 3, usar signal.connect(callable)
export var    — Godot 3, usar @export var
onready var   — Godot 3, usar @onready var
setget        — Godot 3, usar get/set properties
yield()       — Godot 3, usar await
```