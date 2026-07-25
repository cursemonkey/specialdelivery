extends CanvasLayer

@onready var panel       : Control = $Panel
@onready var start_button: Button  = $Panel/StartButton
@onready var load_button : Button  = $Panel/LoadButton

var save_slot_panel : Node = null   # set by Main

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	load_button.pressed.connect(_on_load)
	_check_save()

func _check_save() -> void:
	load_button.visible = _any_slot_has_save()

func _any_slot_has_save() -> bool:
	for slot in range(1, GameManager.SAVE_SLOT_COUNT + 1):
		if GameManager.get_slot_info(slot).get("exists", false):
			return true
	return false

func show_title() -> void:
	visible = true
	_check_save()

func hide_title() -> void:
	visible = false

func _on_start() -> void:
	if save_slot_panel == null:
		return
	save_slot_panel.open_panel(save_slot_panel.Mode.NEW, _on_new_slot_chosen)

func _on_load() -> void:
	if save_slot_panel == null:
		return
	save_slot_panel.open_panel(save_slot_panel.Mode.LOAD, _on_load_slot_chosen)

func _on_new_slot_chosen(slot: int) -> void:
	hide_title()
	get_tree().get_first_node_in_group("main").start_game(slot)

func _on_load_slot_chosen(slot: int) -> void:
	hide_title()
	get_tree().get_first_node_in_group("main").continue_game(slot)
