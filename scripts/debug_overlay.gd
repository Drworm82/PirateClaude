extends CanvasLayer

@onready var _label: Label = $DebugLabel

func log(msg: String) -> void:
	print(msg)
	if not is_instance_valid(_label):
		return
	var current: String = _label.text
	current += "\n" + msg
	var lines: PackedStringArray = current.split("\n")
	if lines.size() > 8:
		var trimmed: String = ""
		for i in range(lines.size() - 8, lines.size()):
			if trimmed != "":
				trimmed += "\n"
			trimmed += lines[i]
		_label.text = trimmed
	else:
		_label.text = current

func clear() -> void:
	if is_instance_valid(_label):
		_label.text = ""