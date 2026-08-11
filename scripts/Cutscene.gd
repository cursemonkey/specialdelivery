extends CanvasLayer
## Reusable cutscene player. A cutscene is a locale (a title card describing
## where you are) plus a list of lines, each optionally spoken by a registered
## NPC so their portrait shows. It fades in, plays the lines, and fades out —
## driving its own input so it works even while the player is locked out.
##
## Usage:
##     cutscene.play(
##         "Your bedroom",
##         [ {"speaker": "doctor_carrington", "mood": "calm", "text": "..."},
##           {"text": "Narration with no speaker."} ],
##         on_done)
##
## Because it handles its own Space/Enter/E input and runs with
## PROCESS_MODE_ALWAYS, it never depends on Player input being enabled.

signal finished

const FADE_TIME     : float = 0.6
const CHARS_PER_SEC : float = 34.0

@onready var fade      : ColorRect   = $Fade
@onready var locale    : Label       = $Panel/Margin/VBox/LocaleLabel
@onready var body      : Label       = $Panel/Margin/VBox/BodyLabel
@onready var speaker   : Label       = $Panel/Margin/VBox/SpeakerLabel
@onready var hint      : Label       = $Panel/Margin/VBox/HintLabel
@onready var portrait  : TextureRect = $PortraitFrame/VBox/PortraitTexture
@onready var frame     : Control     = $PortraitFrame

var _lines    : Array    = []
var _index    : int      = 0
var _typing   : bool     = false
var _progress : float    = 0.0
var _on_done  : Callable = Callable()
var _active   : bool     = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	fade.modulate.a = 0.0

func is_playing() -> bool:
	return _active

## `lines` entries: {text: String, speaker: String (npc id, optional),
## mood: String (optional)}
func play(locale_text: String, lines: Array, on_done: Callable = Callable()) -> void:
	_lines   = lines
	_index   = 0
	_on_done = on_done
	_active  = true
	locale.text = locale_text
	visible = true
	get_tree().paused = true
	var tw : Tween = create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, FADE_TIME)
	tw.tween_callback(_show_line)

func _show_line() -> void:
	if _index >= _lines.size():
		_finish()
		return
	var line : Dictionary = _lines[_index]
	body.text = str(line.get("text", ""))
	body.visible_characters = 0
	_progress = 0.0
	_typing   = true
	hint.visible = false

	var id : String = str(line.get("speaker", ""))
	if id.is_empty():
		speaker.text = ""
		frame.visible = false
	else:
		var def : NPCDefinition = NPCRegistry.get_definition(id)
		speaker.text = def.display_name if def != null else id
		var tex : Texture2D = null
		if def != null:
			tex = def.portrait_texture(str(line.get("mood", "")))
		portrait.texture = tex
		frame.visible = tex != null

func _process(delta: float) -> void:
	if not _typing:
		return
	_progress = minf(_progress + CHARS_PER_SEC * delta, float(body.text.length()))
	body.visible_characters = int(_progress)
	if body.visible_characters >= body.text.length():
		_typing = false
		hint.visible = true

func _advance() -> void:
	if _typing:
		body.visible_characters = -1
		_typing = false
		hint.visible = true
		return
	_index += 1
	_show_line()

func _finish() -> void:
	_active = false
	var cb : Callable = _on_done
	_on_done = Callable()
	var tw : Tween = create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, FADE_TIME)
	tw.tween_callback(func() -> void:
		visible = false
		get_tree().paused = false
		finished.emit()
		if cb.is_valid():
			cb.call()
	)

func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
		get_viewport().set_input_as_handled()
		_advance()
