extends CanvasLayer

const CHARS_PER_SEC   : float = 14.4
const FAST_MULTIPLIER : float = 3.0

@onready var label          : Label       = $Panel/Margin/DialogueLabel
@onready var portrait_frame : Control     = $PortraitFrame
@onready var portrait_rect  : TextureRect = $PortraitFrame/PortraitTexture

var _blocks        : Array    = []
var _block_index   : int      = 0
var _char_progress : float    = 0.0
var _on_finish     : Callable = Callable()
var typing         : bool     = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func _process(delta: float) -> void:
	if not typing:
		return
	var speed : float = CHARS_PER_SEC * (FAST_MULTIPLIER if Input.is_key_pressed(KEY_SPACE) else 1.0)
	_char_progress = minf(_char_progress + speed * delta, float(_current_text().length()))
	label.visible_characters = int(_char_progress)
	if label.visible_characters >= _current_text().length():
		typing = false

func _current_text() -> String:
	if _block_index < _blocks.size():
		return _blocks[_block_index]
	return ""

# Accepts a String or Array of Strings. Optional callback fires when all blocks
# are done. `portrait` shows the speaker's art on the right; null hides the slot.
func open(texts: Variant, on_finish: Callable = Callable(), portrait: Texture2D = null) -> void:
	_on_finish   = on_finish
	_blocks      = [texts] if texts is String else texts
	_block_index = 0
	set_portrait(portrait)
	_start_block()
	visible = true
	get_tree().paused = true

func set_portrait(portrait: Texture2D) -> void:
	portrait_rect.texture = portrait
	portrait_frame.visible = portrait != null

func _start_block() -> void:
	_char_progress           = 0.0
	typing                   = true
	label.text               = _current_text()
	label.visible_characters = 0

# E or Space: skip typing → reveal block, advance to next block, or close.
func advance() -> void:
	if typing:
		_char_progress           = float(_current_text().length())
		label.visible_characters = -1
		typing                   = false
	elif _block_index + 1 < _blocks.size():
		_block_index += 1
		_start_block()
	else:
		var cb := _on_finish
		_on_finish = Callable()
		close()
		if cb.is_valid():
			cb.call()

func close() -> void:
	visible                  = false
	label.visible_characters = -1
	typing                   = false
	_on_finish               = Callable()
	portrait_frame.visible   = false
	get_tree().paused        = false
