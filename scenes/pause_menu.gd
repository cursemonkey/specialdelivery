extends PopupMenu

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_P:
		_on_close_button_pressed()

# pause menu
func _on_pause_button_pressed():
	get_tree().paused = true
	show()

# unpause, close menu
func _on_close_button_pressed():
	hide()
	get_tree().paused = false

func _on_closebutton_pressed() -> void:
	_on_close_button_pressed()
