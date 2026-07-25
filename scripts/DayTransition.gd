extends CanvasLayer
## Sleep transition: fades the screen to black, shows a "Continue" prompt, and
## waits for the player (button click or Space/Enter) before the next day is set
## up. Main calls begin(), listens for continue_requested, then calls reveal().

signal continue_requested

const FADE_TIME : float = 0.7

@onready var fade         : ColorRect = $Fade
@onready var prompt       : Control   = $Prompt
@onready var continue_btn : Button    = $Prompt/Panel/Margin/VBox/ContinueButton

var _awaiting : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fade.modulate.a = 0.0
	fade.visible    = false
	prompt.visible  = false
	continue_btn.pressed.connect(_confirm)

## Fade to black, then show the prompt. Resolves via continue_requested.
func begin() -> void:
	fade.visible   = true
	prompt.visible = false
	var tw : Tween = create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		prompt.visible = true
		_awaiting = true
		continue_btn.grab_focus()
	)

## Fade back in to reveal the new day.
func reveal() -> void:
	_awaiting      = false
	prompt.visible = false
	var tw : Tween = create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void: fade.visible = false)

func _confirm() -> void:
	if not _awaiting:
		return
	_awaiting      = false
	prompt.visible = false
	continue_requested.emit()

func _input(event: InputEvent) -> void:
	if not _awaiting:
		return
	if event is InputEventKey and event.pressed \
			and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		get_viewport().set_input_as_handled()
		_confirm()
