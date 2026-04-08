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
| `main.gd` | Controlador principal. Gestiona transiciones GPS↔Dungeon, viajes, eventos, mapas. Contiene SailButton para abrir DestinationMenu desde vista GPS |
| `gps_map.gd` | Vista del océano. Renderiza islas, jugador, travel marker, HUD de doblones/HP. Botón contextual "Entrar" cerca de islas |
| `dungeon.gd` | Vista de isla. Generación procedural, zona de salida, botón contextual "Abordar" cerca del bote |
| `player.gd` | Movimiento WASD/joystick, límites de mapa, rotación según dirección |
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
| `context_action_button.gd` | Botón contextual táctil. Aparece/desaparece según proximidad. Layer 20 |

### Autoloads (`autoloads/`)

| Archivo | Descripción |
|---------|-------------|
| `GameState.gd` | Puente de acceso rápido a GameManager. Expone get_player_id(), get_current_island_id(), get_doblones_onboard(), get_distance_to(), set_current_island_id() |
| `VoyageManager.gd` | Maneja viajes entre islas. Timer en tiempo real con timestamps en Supabase. Signals: voyage_updated, voyage_arrived, voyage_drifting |

### Escenas (`scenes/`)

| Archivo | Descripción |
|---------|-------------|
| `main.tscn` | Escena raíz. Contiene VirtualJoystick, SailButton y VoyageHUD |
| `gps_map.tscn` | Vista océano. Contiene ContextActionButton instanciado en runtime |
| `dungeon.tscn` | Vista isla con TileMap, Player, Boat. ContextActionButton instanciado en runtime |
| `player.tscn` | Nodo del jugador con sprite y Camera2D |
| `boat.tscn` | Sprite del bote en la orilla sur |
| `destinationmenu.tscn` | CanvasLayer con lista de islas alcanzables desde Supabase. Detección manual de touch |
| `voyagehud.tscn` | CanvasLayer (Layer 10) con timer de viaje y doblones a bordo. Invisible cuando no hay viaje activo |
| `travel_result.tscn` | CanvasLayer con panel de resultado |
| `map_overlay.tscn` | Overlay completo del mapa |
| `virtual_joystick.tscn` | CanvasLayer (Layer 2) → JoystickControl (Control, Full Rect, grupo: joystick) → OuterRing + InnerDot |
| `context_action_button.tscn` | CanvasLayer (Layer 20) → Button (Bottom Center, 200x60) |

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
- Sprint 27: Menú de llegada a isla destino (ArrivalMenu, CanvasLayer Layer 15). 3 opciones: bajar a isla (→ dungeon.tscn via add_child), quedarse a bordo, zarpar (→ DestinationMenu). Doblones se transfieren al banco solo al llegar a isla base. voyage_arrived emite destination_id. VoyageManager usa unix timestamps internamente. Fix JWT refresh awaitable. Fix spawn del jugador fuera de exit zone. Fix dungeon anterior eliminado al bajar a nueva isla. DebugOverlay global agregado en main.tscn (Layer 99).

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
- Signals: `voyage_updated(seconds_remaining, doblones_remaining)`, `voyage_arrived()`, `voyage_drifting()`

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
- Aplica a: ContextActionButton, DestinationMenu, TravelResult, y cualquier botón nuevo

### Supabase auth
- Tokens guardados en `user://auth.cfg` via ConfigFile
- JWT auto-refresh implementado
- `_clear_token()` solo para debug (comentado en producción)

### Autoloads
- No usar `class_name` en Autoloads en Godot 4
- GDScript strict mode: anotaciones de tipo explícitas en todas las variables y funciones

### SupabaseClient.supabase_rpc()
- Renombrado de `rpc()` a `supabase_rpc()` porque `rpc` es función reservada del sistema multiplayer de Godot 4
- Patrón: devuelve HTTPRequest, usar `await http.request_completed`

---

## Arquitectura de controles móviles

### VirtualJoystick
- **Ubicación**: solo en `main.tscn`
- **Encontrado por**: `get_tree().get_first_node_in_group("joystick")`
- **Layer**: 2
- `set_enabled(false/true)` para desactivar con menús

### ContextActionButton
- **Ubicación**: instanciado en runtime en `gps_map.gd` y `dungeon.gd`
- **Layer**: 20
- En GPS map: "Entrar" a menos de 80px de una isla
- En dungeon: "Abordar" a menos de 80px del bote

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

## Próximo sprint
**Sprint 28** — Por definir

---

## Plantilla para chat nuevo

---
Estoy desarrollando PirateWorld, RPG pirata en Godot 4.6.1.
Stack: GDScript + Supabase + OpenCode en VSC.
Sprints completados: 1-27.
Último sprint: 27 — Menú de llegada a isla destino. ArrivalMenu con 3 opciones. Doblones como combustible. Fix JWT refresh. DebugOverlay global.
El contexto completo está en PIRATEWORLD_CONTEXT.md
---