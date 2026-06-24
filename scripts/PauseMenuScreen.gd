extends Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$PanelContainer/HBoxContainer/Resume.pressed.connect(_on_close_button_pressed)
	$PanelContainer/HBoxContainer/Quit.pressed.connect(func(): get_tree().quit())

func _on_pause_button_pressed() -> void:
	visible = true
	get_tree().paused = true

func _on_close_button_pressed() -> void:
	visible = false
	get_tree().paused = false
