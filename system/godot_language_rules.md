# GDScript Godot 4 - Reglas del Lenguaje

## Estructura obligatoria

- Todo script debe empezar con:
  extends CharacterBody2D o Node2D

## Sintaxis

- Usar `func`, nunca `def`
- No usar `{}` (usar indentación)
- No usar `;`
- No usar sintaxis de C++, Java o Python

## Tipos

- Usar Vector2 en 2D
- No usar Vector3 en juegos 2D

## Movimiento correcto

- Usar variable `velocity`
- Usar `move_and_slide()`
- No inventar funciones de movimiento

## Input

- Usar Input.get_action_strength()
- No usar eventos tipo KEY_DOWN manuales

## Variables

- Usar `var` o `@export var`
- No usar `global`

## Funciones válidas

- func _ready():
- func _process(delta):
- func _physics_process(delta):

## Errores prohibidos

El código es inválido si contiene:

- "def "
- "{"
- "}"
- "Vector3"
- "KEY_"
- "global "

## Reglas finales

- Código debe ser ejecutable en Godot 4
- No pseudo código
- No estructuras JSON dentro del código