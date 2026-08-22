extends CanvasLayer
## A small list of dialogue choices. Reusable: call open() with a prompt and an
## array of {text, id}, and the chosen id comes back through `chosen`.
## Built in code to match ShopPanel / MortgagePanel.

signal chosen(id: String)
signal dismissed()

const PANEL_BG     : Color = Color(0.12, 0.12, 0.16, 0.96)
const PANEL_BORDER : Color = Color(0.55, 0.60, 0.75)
const TEXT_DIM     : Color = Color(0.72, 0.72, 0.78)

var _panel    : PanelContainer
var _prompt   : Label
var _rows     : VBoxContainer
var _awaiting : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 91
	visible      = false
	_build()

func _build() -> void:
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_border_width_all(2)
	style.border_color = PANEL_BORDER
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox : VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt.custom_minimum_size = Vector2(360, 0)
	vbox.add_child(_prompt)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows)

	var hint : Label = Label.new()
	hint.text = "Esc to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(hint)

## options: Array of {text: String, id: String}
func open(prompt: String, options: Array) -> void:
	_prompt.text = prompt
	for c in _rows.get_children():
		c.queue_free()
	var first : Button = null
	for opt in options:
		var btn : Button = Button.new()
		btn.text = str(opt.get("text", "..."))
		btn.custom_minimum_size = Vector2(360, 32)
		btn.pressed.connect(_choose.bind(str(opt.get("id", ""))))
		_rows.add_child(btn)
		if first == null:
			first = btn
	visible   = true
	_awaiting = true
	get_tree().paused = true
	if first != null:
		first.call_deferred("grab_focus")

func _choose(id: String) -> void:
	if not _awaiting:
		return
	_awaiting = false
	visible   = false
	get_tree().paused = false
	chosen.emit(id)

func close() -> void:
	if not visible:
		return
	_awaiting = false
	visible   = false
	get_tree().paused = false
	dismissed.emit()

func _input(event: InputEvent) -> void:
	if not _awaiting:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
