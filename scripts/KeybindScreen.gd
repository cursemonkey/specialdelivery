extends CanvasLayer
## The controls page: every rebindable action, the key it is on, and a way to
## change it. Reached from Settings in the pause menu.
##
## Built in code to match ShopPanel and SleepPrompt, so no scene wiring is
## needed — the row list comes straight from InputActions.ROWS, so adding a
## rebindable action means editing that table and nothing here.
##
## Rebinding: click a key button, the row goes into listening mode, and the
## next key pressed is taken. Esc cancels the capture rather than binding Esc,
## since a player who has half-bound something needs a way out. A key already
## used by another action is refused with a message naming the clash, so the
## player can't quietly create a key that does two things.

signal closed()

const PANEL_BG     : Color = Color(0.12, 0.12, 0.16, 0.96)
const PANEL_BORDER : Color = Color(0.55, 0.60, 0.75)
const TEXT_DIM     : Color = Color(0.72, 0.72, 0.78)
const TEXT_WARN    : Color = Color(0.95, 0.55, 0.45)
const TEXT_GOOD    : Color = Color(0.55, 0.90, 0.60)
const HEADING_COL  : Color = Color(0.85, 0.80, 0.55)
const LISTEN_COL   : Color = Color(1.0, 0.85, 0.35)

## How long a warning or confirmation stays up.
const STATUS_TIME : float = 2.6

var _panel   : PanelContainer
var _rows    : VBoxContainer
var _status  : Label
## action -> its key Button, so a rebind can refresh just that row.
var _buttons : Dictionary = {}
## The action currently waiting for a key, or "" when not listening.
var _listening : String = ""
var _status_timer : float = 0.0

func _ready() -> void:
	layer = 130
	process_mode = Node.PROCESS_MODE_ALWAYS   # usable while the game is paused
	visible = false
	_build()
	InputActions.bindings_changed.connect(_refresh_all)

func _build() -> void:
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -230.0
	_panel.offset_top = -235.0
	_panel.offset_right = 230.0
	_panel.offset_bottom = 235.0
	var style : StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var outer : VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	_panel.add_child(outer)

	var title : Label = Label.new()
	title.text = "Keyboard Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)

	var hint : Label = Label.new()
	hint.text = "Click a key to change it. Esc cancels."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	outer.add_child(hint)

	# The list scrolls, so more actions can be added without resizing the panel.
	var scroll : ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 3)
	scroll.add_child(_rows)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 11)
	_status.custom_minimum_size = Vector2(0, 16)
	outer.add_child(_status)

	var buttons : HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	outer.add_child(buttons)

	var reset : Button = Button.new()
	reset.text = "Reset All"
	reset.pressed.connect(_on_reset_all)
	buttons.add_child(reset)

	var close : Button = Button.new()
	close.text = "Close"
	close.pressed.connect(_on_close)
	buttons.add_child(close)

	_populate()

## One row per entry in InputActions.ROWS: headings as plain labels, actions as
## a name and a key button.
func _populate() -> void:
	for child in _rows.get_children():
		child.queue_free()
	_buttons.clear()
	for row in InputActions.ROWS:
		if row.has("heading"):
			_add_heading(str(row["heading"]))
			continue
		_add_action_row(str(row["action"]), str(row["label"]))

func _add_heading(text: String) -> void:
	var spacer : Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_rows.add_child(spacer)
	var label : Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", HEADING_COL)
	_rows.add_child(label)

func _add_action_row(action: String, label_text: String) -> void:
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_rows.add_child(row)

	var name_label : Label = Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var key_button : Button = Button.new()
	key_button.custom_minimum_size = Vector2(150, 0)
	key_button.text = InputActions.display_for(action)
	key_button.pressed.connect(_on_key_button_pressed.bind(action))
	row.add_child(key_button)
	_buttons[action] = key_button

	# Per-row reset, only meaningful once the row has been changed.
	var undo : Button = Button.new()
	undo.text = "↺"
	undo.tooltip_text = "Reset to default"
	undo.custom_minimum_size = Vector2(28, 0)
	undo.pressed.connect(_on_reset_one.bind(action))
	row.add_child(undo)

func _on_key_button_pressed(action: String) -> void:
	_listening = action
	var button : Button = _buttons.get(action)
	if button != null:
		button.text = "Press a key…"
		button.add_theme_color_override("font_color", LISTEN_COL)
	_set_status("Listening for a key — Esc to cancel.", TEXT_DIM)

## While listening, swallow the next key and bind it.
func _input(event: InputEvent) -> void:
	if not visible or _listening == "":
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var action : String = _listening
	if event.keycode == KEY_ESCAPE:
		_stop_listening()
		_set_status("Cancelled.", TEXT_DIM)
		return
	var clash : String = InputActions.conflict_for(action, event)
	if clash != "":
		_stop_listening()
		_set_status("Already used by \"%s\"." % InputActions.label_for(clash), TEXT_WARN)
		return
	if not InputActions.set_binding(action, event):
		_stop_listening()
		_set_status("That key can't be used.", TEXT_WARN)
		return
	_stop_listening()
	_set_status("%s set to %s." % [InputActions.label_for(action), InputActions.display_for(action)], TEXT_GOOD)

func _stop_listening() -> void:
	var action : String = _listening
	_listening = ""
	var button : Button = _buttons.get(action)
	if button != null:
		button.remove_theme_color_override("font_color")
	_refresh_all()

## Repaint every key cell from the InputMap.
func _refresh_all() -> void:
	for action in _buttons.keys():
		var button : Button = _buttons[action]
		if not is_instance_valid(button):
			continue
		if action == _listening:
			continue
		button.text = InputActions.display_for(action)
		# A changed row is worth spotting at a glance.
		if InputActions.is_default(action):
			button.remove_theme_color_override("font_color")
		else:
			button.add_theme_color_override("font_color", TEXT_GOOD)

func _on_reset_one(action: String) -> void:
	InputActions.reset_action(action)
	_set_status("%s reset to %s." % [InputActions.label_for(action), InputActions.display_for(action)], TEXT_DIM)

func _on_reset_all() -> void:
	InputActions.reset_all()
	_set_status("All controls reset to defaults.", TEXT_DIM)

func _set_status(text: String, colour: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", colour)
	_status_timer = STATUS_TIME

func _process(delta: float) -> void:
	if _status_timer <= 0.0:
		return
	_status_timer -= delta
	if _status_timer <= 0.0:
		_status.text = ""

func open() -> void:
	visible = true
	_stop_listening()
	_set_status("", TEXT_DIM)
	_status.text = ""

func _on_close() -> void:
	close()

func close() -> void:
	_listening = ""
	visible = false
	closed.emit()

## Esc closes the page when not mid-capture. Handled here rather than in
## _input so a capture gets first refusal on the key.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _listening != "":
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
