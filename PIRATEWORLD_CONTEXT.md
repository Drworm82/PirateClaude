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
| `gps_map.gd` | Vista del océano. Renderiza islas, jugador, travel marker, HUD de doblones/HP |
| `dungeon.gd` | Vista de isla. Generación procedural, zona de salida, interacción con bote |
| `player.gd` | Movimiento WASD, límites de mapa, interacción con E |
| `boat.gd` | Sprite del bote, embarque del jugador, señal de destino seleccionado |
| `destination_menu.gd` | UI de selección de destino con 3 botones |
| `travel_events.gd` | Generador de eventos aleatorios (tesoro/tormenta/nada) |
| `travel_result.gd` | Overlay de resultado de viaje con título, descripción, delta de doblones |
| `map_overlay.gd` | Sistema de mapas con pestañas (Isla/Océano) y dibujo procedural |
| `map_display.gd` | Canvas de dibujo que delega al overlay |
| `map_button.gd` | Singleton para abrir mapa con tecla M |
| `game_manager.gd` | Estado global del jugador, sync con Supabase, HP del barco |
| `supabase.gd` | Cliente REST, auth anónima, JWT refresh token |
| `supabase_config.gd` | Credenciales de Supabase (NO committing a git) |
| `island_generator.gd` | Generación procedural de islas con Perlin (reservado para Sprint 16+) |

### Escenas (`scenes/`)

| Archivo | Descripción |
|---------|-------------|
| `main.tscn` | Escena raíz del juego |
| `gps_map.tscn` | Vista oceano con GPSMap |
| `dungeon.tscn` | Vista isla con TileMap, Player, Boat, Dungeon |
| `player.tscn` | Nodo del jugador con sprite y Camera2D |
| `boat.tscn` | Sprite del bote en la orilla sur |
| `destination_menu.tscn` | Panel con 3 botones de destino |
| `travel_result.tscn` | CanvasLayer con panel de resultado |
| `map_overlay.tscn` | Overlay completo del mapa |

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

---

## Sistema de islas (coordenadas en gps_map.gd)

| Nombre | Posición (x, y) |
|--------|------------------|
| Tu isla (home) | (640, 360) |
| Isla Enana | (200, 150) |
| Isla del Cocinero | (500, 350) |
| Isla Drum Jr. | (800, 200) |

---

## Destinos para viaje (en main.gd)

| Destino | Costo (doblones) |
|---------|------------------|
| isla_norte | 10 |
| isla_este | 15 |
| puerto_neutral | 20 |

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
**Sprint 16** — Nombres de islas con guiños a One Piece + menú de destinos mejorado con contexto (de dónde sales, hacia dónde vas, costo en doblones)

---

## Plantilla para chat nuevo

---
Estoy desarrollando PirateWorld, RPG pirata en Godot 4.6.1.
Stack: GDScript + Supabase + OpenCode en VSC.
Sprints completados: 1-15.
Último sprint: 15 — sistema de mapas (tecla M abre/cierra, Escape cierra, pestañas Isla/Océano).
Próximo: Sprint 16 — menú de destinos mejorado con nombres
de islas parodia de One Piece y contexto del viaje.
El contexto completo está en PIRATEWORLD_CONTEXT.md
---
