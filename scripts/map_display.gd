extends Control

var overlay_ref: Node = null

func _draw() -> void:
    if overlay_ref:
        overlay_ref._on_map_draw(self, size)
