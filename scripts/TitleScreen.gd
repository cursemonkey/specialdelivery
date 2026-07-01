extends CanvasLayer

@onready var panel       : Control = $Panel
@onready var start_button: Button  = $Panel/StartButton
@onready var load_button : Button  = $Panel/LoadButton

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	load_button.pressed.connect(_on_load)
	_check_save()

func _check_save() -> void:
	if not FileAccess.file_exists("user://save.json"):
		return
	var file : FileAccess = FileAccess.open("user://save.json", FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not parsed is Dictionary:
		return
	var saved_day  : int = int(parsed.get("day",  1))
	var saved_cash : int = int(parsed.get("cash", 0))
	load_button.text    = "Continue — Day %d  $%d 💾" % [saved_day, saved_cash]
	load_button.visible = true

func show_title() -> void:
	visible = true
	_check_save()

func hide_title() -> void:
	visible = false

func _on_start() -> void:
	hide_title()
	get_tree().get_first_node_in_group("main").start_game()

func _on_load() -> void:
	hide_title()
	get_tree().get_first_node_in_group("main").continue_game()
