extends Control

func _ready():
	queue_redraw()

func _draw():
	draw_circle(size * 0.5, 22, Color(1,1,1,0.7))