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
| `main.gd` | Controlador principal. Gestiona transiciones GPS↔Dungeon, viajes, eventos, mapas |
| `gps_map.gd` | Vista del océano. Renderiza islas, jugador, travel marker, HUD de doblones/HP. Botón contextual "Entrar" cerca de islas |
| `dungeon.gd` | Vista de isla. Generación procedural, zona de salida, botón contextual "Abordar" cerca del bote |
| `player.gd` | Movimiento WASD/joystick, límites de mapa, rotación según dirección |
| `boat.gd` | Sprite del bote, detección de proximidad, señal de embarque |
| `destination_menu.gd` | UI de selección de destino con 3 botones. Deshabilita joystick al abrirse |
| `travel_events.gd` | Generador de eventos aleatorios (tesoro/tormenta/nada) |
| `travel_result.gd` | Overlay de resultado de viaje con título, descripción, delta de doblones |
| `map_overlay.gd` | Sistema de mapas con pestañas (Isla/Océano) y dibujo procedural |
| `map_display.gd` | Canvas de dibujo que delega al overlay |
| `map_button.gd` | Singleton para abrir mapa con tecla M |
| `game_manager.gd` | Estado global del jugador, sync con Supabase, HP del barco |
| `supabase.gd` | Cliente REST, auth anónima, JWT refresh token |
| `supabase_config.gd` | Credenciales de Supabase (NO committing a git) |
| `island_generator.gd` | Generación procedural de islas con Perlin (reservado para Sprint 16+) |
| `virtual_joystick.gd` | Joystick virtual flotante. Maneja touch y mouse. Inyecta Input actions. Vive en main.tscn |
| `context_action_button.gd` | Botón contextual táctil. Aparece/desaparece según proximidad. Layer 20 |

### Escenas (`scenes/`)

| Archivo | Descripción |
|---------|-------------|
| `main.tscn` | Escena raíz. Contiene VirtualJoystick (único en el proyecto) |
| `gps_map.tscn` | Vista océano. Contiene ContextActionButton instanciado en runtime |
| `dungeon.tscn` | Vista isla con TileMap, Player, Boat. ContextActionButton instanciado en runtime |
| `player.tscn` | Nodo del jugador con sprite y Camera2D |
| `boat.tscn` | Sprite del bote en la orilla sur |
| `destination_menu.tscn` | CanvasLayer con panel de destinos (Layer 20) |
| `travel_result.tscn` | CanvasLayer con panel de resultado |
| `map_overlay.tscn` | Overlay completo del mapa |
| `virtual_joystick.tscn` | CanvasLayer (Layer 2) → JoystickControl (Control, Full Rect, grupo: joystick) → OuterRing + InnerDot |
| `context_action_button.tscn` | CanvasLayer (Layer 20) → Button (Bottom Center, 200x60) |

### Assets
No hay assets gráficos en el repo actualmente. Sprites reservados para futuro.

---

## Supabase
- URL: ver `supabase_config.gd`
- Tablas:
  - `players`: id, username, doblones, prestigio, lat_center, lng_center, ship_hp, inventario, equipamiento, isla_semilla, fecha_creacion, ultima_conexion
  - `islands`: id, player_id, seed, lat, lng, construcciones, ultima_visita

---

## Autoloads registrados en project.godot
1. `SupabaseClient` → `scripts/supabase.gd`
2. `GameManager` → `scripts/game_manager.gd`
3. `TravelEvents` → `scripts/travel_events.gd`
4. `MapButton` → `scripts/map_button.gd`

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
- Sprint 16: Menú de destinos mejorado con nombres de islas (Isla Enana, Isla del Cocinero, Puerto Loguetown), contexto de viaje (desde/hacia/costo), HP del barco visible, botones deshabilitados sin recursos
- Sprint 17: Barra de progreso del viaje, línea de ruta blanca origen-destino, línea azul de recorrido, texto "Rumbo a: [destino] X%", marcador de destino en el mapa
- Sprint 18: Export a Android funcional. Orientación retrato. Joystick virtual flotante (touch+mouse) en main.tscn. Input Map con move_up/down/left/right/interact.
- Sprint 19: Botón contextual táctil. "Entrar" en GPS map cerca de islas. "Abordar" en dungeon cerca del bote. Joystick único en main.tscn encontrado por grupo. Tecla E sigue funcionando en PC como fallback.

---

## Arquitectura de controles móviles

### VirtualJoystick
- **Ubicación**: solo en `main.tscn` (único en todo el proyecto)
- **Encontrado por**: `get_tree().get_first_node_in_group("joystick")`
- **Layer**: 2 (debajo de todo UI)
- `JoystickControl` en grupo `joystick`
- Usa `_unhandled_input` para no bloquear botones UI
- Inyecta `Input.action_press/release` para move_left/right/up/down
- `set_enabled(false/true)` para desactivar cuando hay menús

### ContextActionButton
- **Ubicación**: instanciado en runtime en `gps_map.gd` y `dungeon.gd`
- **Layer**: 20 (encima de todo)
- Aparece solo cuando el jugador está cerca de un objeto interactuable
- En GPS map: "Entrar" a menos de 80px de una isla
- En dungeon: "Abordar" a menos de 80px del bote
- Cuando aparece: joystick se desactiva para no bloquear el toque
- Señal: `action_pressed`

### Flujo de desactivación del joystick al cambiar de vista
- En `main.gd._on_player_entered_island()`: GPS joystick se desactiva con `set_process_unhandled_input(false)` y `set_process_input(false)`
- En `main.gd._on_player_exited_dungeon()`: GPS joystick se reactiva

---

## Input Map (project.godot)
| Acción | Teclas |
|--------|--------|
| move_up | W, Up |
| move_down | S, Down |
| move_left | A, Left |
| move_right | D, Right |
| interact | E, Space |

---

## Sistema de islas (coordenadas en gps_map.gd)

| Nombre | Posición (x, y) |
|--------|------------------|
| Tu isla (home) | (640, 360) |
| Isla Enana | (200, 150) |
| Isla del Cocinero | (500, 350) |
| Isla Drum Jr. | (800, 200) |

---

## Destinos para viaje (en gps_map.gd, DESTINATIONS)

| Destino | Nombre | Costo (doblones) | Posición |
|---------|--------|-------------------|----------|
| isla_norte | Isla Enana | 10 | (200, 150) |
| isla_este | Isla del Cocinero | 15 | (800, 200) |
| puerto_neutral | Puerto Loguetown | 20 | (640, 600) |

---

## Sistemas implementados

| Sistema | Descripción |
|---------|-------------|
| **Economía** | Doblones como moneda única. Se ganan con tesoros, se pierden en tormentas y viajes. HP del barco cuesta reparaciones |
| **Auth** | Login anónimo con Supabase. JWT + refresh token guardados en `user://auth.cfg`. Auto-renewal si expira |
| **Viaje** | Al salir del dungeon y elegir destino, marcador viaja automáticamente por el mapa GPS a velocidad constante |
| **Eventos de viaje** | Al llegar: 30% tesoro (+10-50 doblones), 25% tormenta (-5-20 doblones + 5-15 daño barco), 45% nada |
| **Salud del barco** | HP del barco (100 max). Tormentas dañan. Si llega a 0, no se puede zarpar. Reparación cuesta 5 doblones por HP |
| **Mapa overlay** | Tecla M abre/cierra overlay. Escape también cierra. Pestaña "Isla" muestra dungeon con jugador y zona de salida. Pestaña "Océano" muestra islas conocidas con nombres |
| **Joystick virtual** | Único en main.tscn. Flotante, aparece al tocar. Funciona en Android (touch) y PC (mouse). Se deshabilita con menús |
| **Botón contextual** | Táctil, aparece cerca de objetos interactuables. "Entrar" en GPS, "Abordar" en dungeon |

---

## Variables principales de GameManager
```gdscript
var player_id: String = ""
var doblones: int = 100
var prestigio: int = 0
var home_lat: float = 19.4326
var home_lng: float = -99.1332
var is_authenticated: bool = false
var ship_hp: int = 100
var ship_hp_max: int = 100
var ship_repair_cost: int = 5
var current_island_name: String = "Tu isla"
```

---

## Variables principales de SupabaseClient
```gdscript
var _access_token: String = ""
var _user_id: String = ""
var _refresh_token: String = ""
```

---

## Próximo sprint
**Sprint 20** — Pruebas en Android con GPS real

---

## Plantilla para chat nuevo

---
Estoy desarrollando PirateWorld, RPG pirata en Godot 4.6.1.
Stack: GDScript + Supabase + OpenCode en VSC.
Sprints completados: 1-19.
Último sprint: 19 — botón contextual táctil (Entrar/Abordar) + joystick único en main.tscn.
En proceso: Sprint 20 — pruebas en Android con GPS real.
El contexto completo está en PIRATEWORLD_CONTEXT.md
---