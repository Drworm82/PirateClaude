extends Node

enum EventType {TREASURE, STORM, NOTHING}

func generate_event() -> Dictionary:
    var roll := randi() % 100
    if roll < 30:
        var doblones := randi_range(10, 50)
        return {
            "type": EventType.TREASURE,
            "title": "Tesoro encontrado",
            "description": "Encontraste un cofre flotante\ncon " + str(doblones) + " doblones.",
            "doblones_delta": doblones
        }
    elif roll < 55:
        var damage := randi_range(5, 20)
        return {
            "type": EventType.STORM,
            "title": "Tormenta en el mar",
            "description": "Una tormenta golpeó tu barco.\nPerdiste " + str(damage) + " doblones en reparaciones.",
            "doblones_delta": -damage
        }
    else:
        return {
            "type": EventType.NOTHING,
            "title": "Viaje sin novedad",
            "description": "Llegaste a tu destino\nsin contratiempos.",
            "doblones_delta": 0
        }
