extends CanvasLayer

signal start_pressed()


#@onready var panel : Control = $Panel

#func _ready() -> void:
#	$Panel/VBox/StartButton.pressed.connect(_on_start)

#new lines

@onready var panel: Control = $Panel
@onready var start_button: Button = $Panel/StartButton   # ← drag & drop from scene tree!

func _ready() -> void:
	start_button.pressed.connect(_on_start)


func show_title() -> void:
	visible = true

func hide_title() -> void:
	visible = false

func _on_start() -> void:
	hide_title()
	# Tell Main to begin
	get_tree().get_first_node_in_group("main").start_game()
