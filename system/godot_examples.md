\# Ejemplos válidos GDScript



\## Movimiento básico



extends CharacterBody2D



@export var speed := 200.0



func \_physics\_process(delta):

&#x20;   var direction = Vector2.ZERO



&#x20;   direction.x = Input.get\_action\_strength("ui\_right") - Input.get\_action\_strength("ui\_left")

&#x20;   direction.y = Input.get\_action\_strength("ui\_down") - Input.get\_action\_strength("ui\_up")



&#x20;   velocity = direction.normalized() \* speed

&#x20;   move\_and\_slide()

