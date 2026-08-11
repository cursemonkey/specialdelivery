extends CanvasLayer

const CHARS_PER_SEC   : float = 14.4
const FAST_MULTIPLIER : float = 3.0

@onready var label          : Label       = $Panel/Margin/DialogueLabel
@onready var portrait_frame : Control     = $PortraitFrame
@onready var portrait_rect  : TextureRect = $PortraitFrame/VBox/PortraitTexture
@onready var name_label     : Label       = $PortraitFrame/VBox/NameLabel

var _blocks        : Array    = []   # each: {text: String, portrait: Texture2D}
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
		return _blocks[_block_index].get("text", "")
	return ""

func _current_portrait() -> Texture2D:
	if _block_index < _blocks.size():
		return _blocks[_block_index].get("portrait", null)
	return null

func _current_speaker() -> String:
	if _block_index < _blocks.size():
		return str(_blocks[_block_index].get("speaker", ""))
	return ""

# Simple form: a String or Array of Strings, one portrait for every block.
func open(texts: Variant, on_finish: Callable = Callable(), portrait: Texture2D = null, speaker: String = "") -> void:
	var arr : Array = [texts] if texts is String else texts
	var blocks : Array = []
	for t in arr:
		blocks.append({"text": str(t), "portrait": portrait, "speaker": speaker})
	open_blocks(blocks, on_finish)

# Rich form: each block is {text: String, portrait: Texture2D}, so the portrait
# can change per line (emotion-driven dialogue).
func open_blocks(blocks: Array, on_finish: Callable = Callable()) -> void:
	_on_finish   = on_finish
	_blocks      = blocks
	_block_index = 0
	_start_block()
	visible = true
	get_tree().paused = true

func set_portrait(portrait: Texture2D, speaker_name: String = "") -> void:
	portrait_rect.texture  = portrait
	name_label.text        = speaker_name
	name_label.visible     = not speaker_name.is_empty()
	portrait_frame.visible = portrait != null or not speaker_name.is_empty()

func _start_block() -> void:
	_char_progress           = 0.0
	typing                   = true
	label.text               = _current_text()
	label.visible_characters = 0
	set_portrait(_current_portrait(), _current_speaker())

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
