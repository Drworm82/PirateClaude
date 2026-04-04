extends Control

func _ready():
	queue_redraw()

func _draw():
	draw_arc(size * 0.5, 55, 0, TAU, 64, Color(1,1,1,0.3), 3.0)