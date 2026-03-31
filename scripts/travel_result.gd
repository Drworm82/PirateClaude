extends CanvasLayer

signal closed

func show_result(event: Dictionary) -> void:
    var delta: int = event.get("doblones_delta", 0)
    $Panel/Title.text = event.get("title", "")
    $Panel/Description.text = event.get("description", "")
    
    if delta > 0:
        $Panel/DoblonesLabel.text = "+" + str(delta) + " doblones"
        $Panel/DoblonesLabel.add_theme_color_override(
            "font_color", Color(0.2, 0.9, 0.3))
    elif delta < 0:
        $Panel/DoblonesLabel.text = str(delta) + " doblones"
        $Panel/DoblonesLabel.add_theme_color_override(
            "font_color", Color(0.9, 0.2, 0.2))
    else:
        $Panel/DoblonesLabel.text = "Sin cambios"
    
    $Panel/ContinuarBtn.pressed.connect(
        func(): emit_signal("closed"))
