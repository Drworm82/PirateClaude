extends CanvasLayer

@onready var _label: Label = $DebugLabel

func log(msg: String) -> void:
	print(msg)
	if not is_instance_valid(_label):
		return
	_label.text += "\n" + msg
	var lines: PackedStringArray = _label.text.split("\n")
	if lines.size() > 5:
		var trimmed: PackedStringArray = lines.slice(lines.size() - 5)
		_label.text = "\n".join(trimmed)

func clear() -> void:
	if is_instance_valid(_label):
		_label.text = ""
