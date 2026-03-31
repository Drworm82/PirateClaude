extends Node

var map_overlay: Node = null

func open_map(dungeon: Node, islands: Array) -> void:
    if map_overlay:
        return
    var scene: PackedScene = preload(
        "res://scenes/map_overlay.tscn")
    map_overlay = scene.instantiate()
    get_tree().root.add_child(map_overlay)
    map_overlay.set_dungeon(dungeon)
    map_overlay.set_known_islands(islands)
    map_overlay.closed.connect(_on_map_closed)

func _on_map_closed() -> void:
    if map_overlay:
        map_overlay.queue_free()
        map_overlay = null
