# PirateWorld — Context Document

## Stack
- Motor: Godot 4.6.1
- Lenguaje: GDScript
- Editor: VSCode + OpenCode (terminal)
- Base de datos: Supabase (auth anónima + REST API)
- Plataforma objetivo: Android/iOS + PC

---

## Estructura de archivos

### Scripts (`scripts/`)

| Archivo | Descripción |
|---------|-------------|
| `main.gd` | Controlador principal. Gestiona transiciones GPS↔Dungeon↔ShipInterior, viajes, eventos, mapas. View enum: GPS/DUNGEON/SHIP |
| `gps_map.gd` | Vista del océano. Renderiza islas, jugador, travel marker, HUD de doblones/HP. Actualiza Action Button via main.update_action_state() |
| `dungeon.gd` | Vista de isla. Generación procedural, zona de salida, botón contextual "Abordar" cerca del bote |
| `ship_interior.gd` | Vista cubierta del barco durante viaje. _draw() con casco/cubierta/mástil/barriles/timón. Camera2D propia. Player instanciado en escena |
| `player.gd` | Movimiento WASD/joystick, límites de mapa (bounds_max), can_move flag, rotación según dirección. Lee move_left/right/up/down |
| `boat.gd` | Sprite del bote, detección de proximidad, señal de embarque |
| `travel_events.gd` | Generador de eventos aleatorios (tesoro/tormenta/nada) |
| `travel_result.gd` | Overlay de resultado de viaje con título, descripción, delta de doblones |
| `map_overlay.gd` | Sistema de mapas con pestañas (Isla/Océano) y dibujo procedural |
| `map_display.gd` | Canvas de dibujo que delega al overlay |
| `map_button.gd` | Singleton para abrir mapa con tecla M |
| `game_manager.gd` | Estado global del jugador, sync con Supabase, HP del barco, islands_cache, home_island_id |
| `supabase.gd` | Cliente REST, auth anónima, JWT refresh token, método supabase_rpc() para llamar funciones de Supabase |
| `supabase_config.gd` | Credenciales de Supabase (NO committing a git) |
| `island_generator.gd` | Generación procedural de islas con Perlin (reservado para Sprint 16+) |
| `virtual_joystick.gd` | Joystick virtual flotante. Maneja touch y mouse. Inyecta Input actions. Vive en main.tscn |
| `main_hud.gd` | HUD global persistente. Header (≡, título, Trabajar) + BottomBar (Inventario, Action Button, Mapa). Detección manual de touch. Señales: menu_pressed, work_pressed, inventory_pressed, map_pressed, action_pressed. set_action_state(state) para cambiar Action Button contextualmente |
| `debug_overlay.gd` | Overlay global de debug (Layer 99). Método log(msg) accesible via GameState.debug_log(). Muestra últimas 5 líneas |

### Autoloads (`autoloads/`)

| Archivo | Descripción |
|---------|-------------|
| `GameState.gd` | Puente de acceso rápido a GameManager. Expone get_player_id(), get_current_island_id(), get_doblones_onboard(), get_distance_to(), set_current_island_id() |
| `VoyageManager.gd` | Maneja viajes entre islas. Timer en tiempo real con timestamps en Supabase. Signals: voyage_updated, voyage_arrived, voyage_drifting |

### Escenas (`scenes/`)

| Archivo | Descripción |
|---------|-------------|
| `main.tscn` | Escena raíz. Contiene VirtualJoystick, VoyageHUD, MainHud, DebugOverlay |
| `gps_map.tscn` | Vista océano. GPSMap (Node2D con _draw()). Detecta proximidad a islas, actualiza Action Button via main.update_action_state() |
| `dungeon.tscn` | Vista isla con TileMap, Player, Boat. Detecta proximidad al Boat, actualiza Action Button. Deshabilita Abordar durante viaje activo |
| `ship_interior.tscn` | Node2D + Player instanciado. Cubierta del barco dibujada con _draw(). Camera2D propia |
| `main_hud.tscn` | CanvasLayer Layer 25. Header (top 60px) + BottomBar (bottom 80px). Grupos: main_hud |
| `player.tscn` | Nodo del jugador con sprite y Camera2D |
| `boat.tscn` | Sprite del bote en la orilla sur |
| `destinationmenu.tscn` | CanvasLayer con lista de islas alcanzables desde Supabase. Detección manual de touch |
| `voyagehud.tscn` | CanvasLayer (Layer 10) con timer de viaje y doblones a bordo. Invisible cuando no hay viaje activo |
| `arrival_menu.tscn` | CanvasLayer Layer 15. Opciones: Bajar a isla / Quedarse a bordo / Zarpar |
| `travel_result.tscn` | CanvasLayer con panel de resultado |
| `map_overlay.tscn` | Overlay completo del mapa |
| `virtual_joystick.tscn` | CanvasLayer (Layer 2) → JoystickControl (Control, Full Rect, grupo: joystick) → OuterRing + InnerDot |

### Escenas raíz (`res://`)

| Archivo | Descripción |
|---------|-------------|
| `DestinationMenu.gd` | Script del menú de destinos. extends CanvasLayer. Llama supabase_rpc(get_reachable_islands), detección manual de touch, emite señal menu_closed |

---

## Supabase
- URL: ver `supabase_config.gd`
- Tablas:
  - `players`: id, username, doblones, prestigio, lat_center, lng_center, ship_hp, inventario, equipamiento, isla_semilla, fecha_creacion, ultima_conexion
  - `islands`: id, nombre, lat, lng, tipo, terreno, relieve, costa, faccion, poblacion, recursos, comercio, seed
  - `player_island_knowledge`: player_id, island_id, nivel (1-5)
  - `voyages`: id, player_id, origin_island_id, destination_island_id, ship_type, departure_time, arrival_time, doblones_at_departure, doblones_per_km, distance_km, status (sailing/arrived/drifting)
- Funciones RPC:
  - `get_reachable_islands(origin_id, max_range_km)` — devuelve islas dentro del rango ordenadas por distancia

---

## Autoloads registrados en project.godot
0. `GpsService` → `scripts/gps_service.gd`
1. `SupabaseClient` → `scripts/supabase.gd`
2. `GameManager` → `scripts/game_manager.gd`
3. `TravelEvents` → `scripts/travel_events.gd`
4. `MapButton` → `scripts/map_button.gd`
5. `GameState` → `autoloads/GameState.gd`
6. `VoyageManager` → `autoloads/VoyageManager.gd`

---

## Sprints completados
- Sprint 1: Proyecto base sin errores
- Sprint 2: Dos vistas visibles (GPS + Dungeon)
- Sprint 3: Transición GPS ↔ Dungeon con tecla E
- Sprint 4: Jugador centrado, sin canvas gris
- Sprint 5: Sprite real del bote desde asset pack
- Sprint 6: Movimiento WASD en mapa GPS
- Sprint 7: TileMap configurado, dungeon limpio
- Sprint 8: Bote interactuable en orilla sur (tecla E)
- Sprint 9: Menú de destinos funcional
- Sprint 10: Viaje automático del marcador en GPS
- Sprint 11: Supabase — auth anónima + persistencia
- Sprint 12: HUD doblones + isla base + token persistente
- Sprint 13: Eventos de viaje (tesoro/tormenta/nada)
- Sprint 14: Salud del barco + costo de viaje en doblones
- Sprint 15: Sistema de mapas (tecla M abre overlay, Escape cierra, pestaña Isla muestra mapa local del dungeon, pestaña Océano muestra mapa global con nombres de islas)
- Sprint 16: Menú de destinos mejorado con nombres de islas, contexto de viaje, HP del barco visible
- Sprint 17: Barra de progreso del viaje, línea de ruta blanca origen-destino, línea azul de recorrido
- Sprint 18: Export a Android funcional. Joystick virtual flotante en main.tscn
- Sprint 19: Botón contextual táctil. "Entrar" en GPS map, "Abordar" en dungeon
- Sprint 20: Todos los botones táctiles funcionando en Android. Detección manual con get_global_rect().has_point()
- Sprint 21: GPS real en Android via JavaClassWrapper + ActivityThread
- Sprint 22: Verificación GPS real confirmada (19.42, -99.13 CDMX). Isla home anclada a coords GPS reales
- Sprint 23: Polling GPS continuo. Jugador siempre centrado, islas se mueven relativas a posición GPS real
- Sprint 24: Diseño de sistema de conocimiento de islas (5 niveles). Tablas islands y player_island_knowledge creadas
- Sprint 25: Islas cargadas desde Supabase. Isla home creada con coords GPS reales. Jugador centrado sobre isla home. Sin movimiento libre en vista GPS
- Sprint 26: Sistema de viaje entre islas. Menú de destinos desde Supabase (get_reachable_islands RPC). VoyageManager con timer en tiempo real (timestamps en Supabase, persiste si se cierra la app). VoyageHUD con countdown y doblones a bordo. Doblones como combustible consumido gradualmente. Estado a la deriva si se agotan. GameState como puente a GameManager. Detección manual de touch en menú de destinos
- Sprint 27: Menú de llegada a isla destino (ArrivalMenu, CanvasLayer Layer 15). 3 opciones: bajar a isla (→ dungeon.tscn via add_child), quedarse a bordo, zarpar (→ DestinationMenu). Doblones se transfieren al banco solo al llegar a isla base. Fix JWT refresh awaitable. Fix spawn del jugador fuera de exit zone. Fix dungeon anterior eliminado al bajar a nueva isla. DebugOverlay global agregado en main.tscn (Layer 99).
- Sprint 28: Movimiento del bote en GPS durante viaje (interpolación lat/lng con progress). Persistencia de viaje al cerrar app (check_active_voyage llamado desde main._ready() después de initialize()). Fix: VoyageManager usa unix timestamps internamente. Fix: JWT siempre refresca al iniciar. Fix: player_id asignado desde SupabaseClient._user_id en initialize().
- Sprint 29: MainHud global (Layer 25) con Header y BottomBar. Action Button contextual: Entrar/Zarpar/Ver barco/Abordar/Deshabilitado según contexto. Detección manual de touch en MainHud. Eliminados ContextActionButton y SailButton. Fix _draw() en gps_map inicializado en _physics_process cuando viewport tiene tamaño válido. DestinationMenu y ArrivalMenu usan safe area offset para detección de touch en Android.
- Sprint 30: Interior del barco durante viaje (ship_interior.gd + ship_interior.tscn). View enum extendido a GPS/DUNGEON/SHIP. Toggle GPS↔ShipInterior con botón "Ver barco". Fix parpadeo Action Button (dungeon.visible=false en _on_voyage_updated). Fix ghost render ship_interior (Camera2D.enabled=false antes de queue_free y al toggle). Fix dungeon invisible al bajar en isla destino.

---

## Sistema de barcos

| Embarcación | Velocidad | HP | Cañones | Carga | Tripulación | Alcance |
|-------------|-----------|-----|---------|-------|-------------|----------|
| Lancha (inicial) | 5 km/h (9 km/h escape) | bajo | 0 | 1 slot | 1–4 (2 seguros) | ~5 km estricto |
| Catamarán | 35–50 km/h | 120 | 1 par | 3 slots | 1–4 | dinámico |
| Barco mediano | 20 km/h | 200 | 2 pares | 6 slots | 4–8 | dinámico |
| Galeón | 10–15 km/h | alto | máximo | máximo | 8–15 | dinámico |

### Reglas de alcance
- Lancha: límite físico de 5 km. Se hunde si lo supera
- Demás barcos: alcance dinámico limitado por doblones a bordo
- Doblones = combustible. Se consumen gradualmente (doblones_per_km). No se descontar al zarpar
- Sin doblones a mitad del viaje = estado á la deriva (vulnerable a PvP)
- El atacante puede saquear los doblones que queden a bordo
- Reducción de tiempo de viaje: solo con anuncios (monetización principal)

---

## VoyageManager — arquitectura

```gdscript
const SHIP_SPEED_KMH: float = 5.0   # lancha
const SHIP_RANGE_KM: float = 5.0    # lancha
const DOBLONES_PER_KM: int = 2
```

- `start_voyage(destination_island_id)` — crea registro en tabla voyages, guarda timestamps
- `check_active_voyage()` — al iniciar app, recupera viaje activo si existe
- `_tick()` — cada segundo: calcula segundos restantes y doblones consumidos
- `_set_arrived()` — actualiza status en Supabase, actualiza GameState.current_island_id
- `_set_drifting()` — actualiza status en Supabase cuando doblones llegan a 0
- Signals: `voyage_updated(seconds_remaining, doblones_remaining, progress)`, `voyage_arrived(destination_id)`, `voyage_drifting()`

---

## GameState — puente a GameManager

```gdscript
get_player_id() → GameManager.player_id
get_current_island_id() → GameManager.home_island_id
get_current_island_lat() → GameManager.home_lat
get_current_island_lng() → GameManager.home_lng
get_doblones_onboard() → GameManager.doblones
set_current_island_id(id) → GameManager.home_island_id = id
get_distance_to(island_id) → haversine desde isla actual a target (usa islands_cache)
get_island_name(island_id) → nombre de isla desde islands_cache
get_island_coords(island_id) → {lat, lng} desde islands_cache
```

---

## Patrones técnicos establecidos

### Android GPS
```gdscript
JavaClassWrapper → ActivityThread → currentApplication() → getApplicationContext() → getSystemService("location")
```

### Touch en Android
- Los `Button` nativos de Godot NO detectan touch en Android en este proyecto
- Solución: detección manual en `_input()` con `InputEventScreenTouch` + `get_global_rect().has_point(event.position)`
- Aplica a: DestinationMenu, ArrivalMenu, TravelResult, y cualquier botón nuevo

### Supabase auth
- Tokens guardados en `user://auth.cfg` via ConfigFile
- JWT auto-refresh implementado
- `_clear_token()` solo para debug (comentado en producción)

### Autoloads
- No usar `class_name` en Autoloads en Godot 4
- GDScript strict mode: anotaciones de tipo explícitas en todas las variables y funciones

### Safe Area en Android
- DisplayServer.get_display_safe_area().position.y devuelve el offset del notch
- Restar este valor al event.position.y para coordenadas correctas en CanvasLayer
- DestinationMenu y ArrivalMenu usan adj_y = raw_y - 90.0 (margin_top fijo)

### Action Button contextual
- Estado se actualiza desde gps_map.gd y dungeon.gd via main_node.update_action_state(int)
- Durante viaje activo en dungeon: estado NONE (0)
- Estados: 0=NONE, 1=ENTER_ISLAND, 2=SAIL, 3=VIEW_SHIP, 4=BOARD

### _draw() en Android
- get_viewport_rect().size puede ser (0,0) en _ready()
- Solución: calcular _map_center en _physics_process cuando size.x > 0
- Usar _map_initialized: bool para ejecutar solo una vez

### SupabaseClient.supabase_rpc()
- Renombrado de `rpc()` a `supabase_rpc()` porque `rpc` es función reservada del sistema multiplayer de Godot 4
- Patrón: devuelve HTTPRequest, usar `await http.request_completed`

### Camera2D y visibilidad de vistas
- Al ocultar un Node2D que tiene Camera2D activa, siempre hacer `camera.enabled = false` ANTES de `visible = false` o `queue_free()`
- De lo contrario la Camera2D sigue siendo `current` y produce ghost render de esa vista sobre otras
- Al mostrar una vista con Camera2D propia: `camera.enabled = true` + `camera.make_current()`
- Aplica a: ShipInterior al toggle y al destruir

---

## Arquitectura de controles móviles

### VirtualJoystick
- **Ubicación**: solo en `main.tscn`
- **Encontrado por**: `get_tree().get_first_node_in_group("joystick")`
- **Layer**: 2
- `set_enabled(false/true)` para desactivar con menús

---

## Variables principales de GameManager
```gdscript
var player_id: String = ""
var doblones: int = 100
var doblones_onboard: int = 0
var prestigio: int = 0
var home_lat: float = 19.4326
var home_lng: float = -99.1332
var is_authenticated: bool = false
var ship_hp: int = 100
var ship_hp_max: int = 100
var ship_repair_cost: int = 5
var current_island_name: String = "Tu isla"
var home_island_id: String = ""
var islands_cache: Array = []
```

---

## Debug
- `debug_gps: bool` en `gps_map.gd` — muestra coordenadas GPS, estado GpsService, log de GameManager
- Para producción: cambiar a `false`
- `# SupabaseClient._clear_token()` en `game_manager.gd` — descomentar solo para resetear token en desarrollo

---

## Sistema de conocimiento de islas

### Niveles (1-5)
1. Localización
2. Nombre
3. Rasgos físicos
4. Rasgos humanos
5. Economía

### Tabla islands
id, nombre, lat, lng, tipo (normal/hub/zona_segura), terreno, relieve, costa, faccion, poblacion, recursos (text[]), comercio (text[]), seed

### Tabla player_island_knowledge
player_id, island_id, nivel (1-5)

---

## Estado actual de scripts clave

> Actualizar esta sección al final de cada sprint. Permite a Claude entender el estado del código sin necesidad de subir archivos.

### main.gd

**Variables de estado:**
```gdscript
enum View {GPS, DUNGEON, SHIP}
var current_view: View = View.GPS
var gps_map: GPSMap
var current_dungeon: Dungeon
var current_ship_interior: ShipInterior = null
```

**Flujo de vistas:**
- `_setup_gps_view()` — instancia gps_map.tscn, current_view = GPS
- `_enter_ship_interior()` — instancia ship_interior.tscn, oculta gps_map, current_view = SHIP
- `_exit_ship_interior()` — desactiva Camera2D del interior, visible=false, exit_ship() (queue_free), muestra gps_map, current_view = GPS
- `_toggle_ship_view()` — alterna entre GPS y SHIP: desactiva/activa Camera2D del ship_interior en cada toggle

**Funciones críticas:**
```
_on_voyage_updated(seconds, doblones, progress):
  → si current_dungeon visible: current_dungeon.visible = false
  → si no hay ship_interior: _enter_ship_interior()
  → update_action_state(3)

_on_voyage_arrived(destination_id):
  → _exit_ship_interior()
  → instancia arrival_menu.tscn

_on_arrival_go_ashore():
  → queue_free dungeon anterior si existe
  → gps_map.visible = false
  → instancia dungeon.tscn (visible por defecto)
  → current_view = DUNGEON

_on_action_pressed(state):
  → 1: gps_map._on_enter_island()
  → 2: _on_sail_pressed() → instancia destinationmenu.tscn
  → 3: _toggle_ship_view() si hay viaje activo
  → 4: current_dungeon._on_board_pressed()
```

---

### gps_map.gd

**Guard:** `if not visible: return` en `_physics_process` (línea ~97)

**Lógica Action Button en _physics_process:**
```
si VoyageManager.active_voyage vacío:
  → cerca de isla: update_action_state(1)
  → lejos: update_action_state(2)
sino:
  → update_action_state(3)  # Ver barco
```

**_on_voyage_updated:** interpola _player_lat/_player_lng según progress, llama _place_islands_relative(), queue_redraw()

**Señales emitidas:** `player_entered_island(island_pos)`, `travel_completed`

---

### dungeon.gd

**Guard:** `if not visible: return` en `_physics_process` (línea ~62)

**Lógica Action Button en _physics_process:**
```
si VoyageManager.active_voyage NO vacío: update_action_state(0)
sino si dist al Boat < 80px: update_action_state(4)
sino: update_action_state(0)
```

**_exit_dungeon():** player.exit_dungeon(), emit player_exited_dungeon, queue_free()
**_show_destination_menu():** instancia destinationmenu.tscn via get_tree().root.add_child()
**_on_board_pressed():** llama _show_destination_menu()

---

### ship_interior.gd

**NO tiene guard `if not visible`** — depende de que main.gd desactive su Camera2D.

**_ready():**
- Desactiva Camera2D del Player ($Player/Camera2D)
- Crea Camera2D propia, zoom (1.5, 1.5), make_current()
- joystick.set_enabled(true)
- player.position = Vector2(0, 20), player.can_move = true

**_physics_process:** clamp posición del player dentro del casco (SHIP_WIDTH=120, SHIP_HEIGHT=220)

**enter_ship(type):** guarda ship_type, queue_redraw()

**exit_ship():**
- Reactiva Camera2D del Player
- joystick.set_enabled(false)
- queue_free()

---

### dungeon.gd — estructura de escena
```
dungeon.tscn
  └─ Node2D (Dungeon)
       ├─ TileMap
       ├─ Player (instancia player.tscn)
       │    └─ Camera2D
       └─ Boat (instancia boat.tscn)
```

### ship_interior.tscn — estructura de escena
```
ship_interior.tscn
  └─ Node2D (ShipInterior)
       └─ Player (instancia player.tscn)
            └─ Camera2D  ← se desactiva en _ready(), Camera2D propia se agrega dinámicamente
```

---

## Próximo sprint
**Sprint 31** — Por definir

---

## Plantilla para chat nuevo

```
Estoy desarrollando PirateWorld, RPG pirata en Godot 4.6.1.
Stack: GDScript + Supabase + OpenCode en VSC.
Sprints completados: 1-30.
Último sprint: 30 — Interior del barco durante viaje (ship_interior.gd/tscn). View enum GPS/DUNGEON/SHIP. Toggle GPS↔ShipInterior. Fixes: parpadeo Action Button, ghost render Camera2D, dungeon invisible al desembarcar.
El contexto completo está en PIRATEWORLD_CONTEXT.md
```