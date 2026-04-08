extends CanvasLayer

var _label: Label

func _ready() -> void:
	_label = get_node("DebugLabel")
	_label.text = ""

func log(msg: String) -> void:
	print(msg)
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
	_label.text = ""