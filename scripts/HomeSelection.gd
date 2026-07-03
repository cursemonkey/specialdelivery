extends CanvasLayer

signal home_selected(home_id: String, price: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$Panel/VBox/Townhouse3Btn.pressed.connect(func(): _pick("Townhouse3", 100000))
	$Panel/VBox/ApartmentsBtn.pressed.connect(func(): _pick("Apartments",  150000))
	$Panel/VBox/House28Btn.pressed.connect(func():    _pick("House28",     300000))
	$Panel/VBox/House10Btn.pressed.connect(func():    _pick("House10",     500000))

func show_selection() -> void:
	visible = true
	get_tree().paused = true

func _pick(home_id: String, price: int) -> void:
	visible = false
	get_tree().paused = false
	home_selected.emit(home_id, price)
