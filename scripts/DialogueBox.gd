extends CanvasLayer

@onready var label : Label = $Panel/Margin/HBox/TextPanel/TextMargin/DialogueLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open(text: String) -> void:
	label.text = text
	visible = true
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false
