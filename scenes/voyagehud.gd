extends CanvasLayer

@onready var timer_label: Label = $HUD/TimerLabel
@onready var doblones_label: Label = $HUD/DoblonesLabel
@onready var ad_button: Label = $HUD/AdButton

func _ready() -> void:
	visible = false
	VoyageManager.voyage_updated.connect(_on_voyage_updated)
	VoyageManager.voyage_arrived.connect(_on_arrived)
	VoyageManager.voyage_drifting.connect(_on_drifting)
	if not VoyageManager.active_voyage.is_empty():
		visible = true

func _on_voyage_updated(seconds_remaining: int, doblones_remaining: int) -> void:
	visible = true
	var minutes: int = seconds_remaining / 60
	var seconds: int = seconds_remaining % 60
	timer_label.text = "Llegada en: %02d:%02d" % [minutes, seconds]
	doblones_label.text = "Doblones a bordo: %d" % doblones_remaining

func _on_arrived() -> void:
	visible = false

func _on_drifting() -> void:
	timer_label.text = "A la deriva!"
	doblones_label.text = "Sin doblones"
	ad_button.visible = false