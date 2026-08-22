extends CanvasLayer
## Jimmy Henderson's mortgage counter: put any amount up to what you can afford
## against the balance. Built in code to match ShopPanel / SleepPrompt, so no
## scene wiring is needed.

signal closed()

const PANEL_BG     : Color = Color(0.12, 0.12, 0.16, 0.96)
const PANEL_BORDER : Color = Color(0.55, 0.60, 0.75)
const TEXT_DIM     : Color = Color(0.72, 0.72, 0.78)
const TEXT_WARN    : Color = Color(0.95, 0.55, 0.45)
const TEXT_GOOD    : Color = Color(0.55, 0.90, 0.60)

var _panel    : PanelContainer
var _balance  : Label
var _status   : Label
var _amount   : SpinBox
var _pay_btn  : Button
var _all_btn  : Button
var _awaiting : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 90
	visible      = false
	_build()

func _build() -> void:
	var dim : ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
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

	var title : Label = Label.new()
	title.text = "🏦 Mortgage Payment"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_balance = Label.new()
	_balance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_balance.add_theme_color_override("font_color", TEXT_DIM)
	_balance.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_balance)

	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var amt_lbl : Label = Label.new()
	amt_lbl.text = "Amount $"
	row.add_child(amt_lbl)

	_amount = SpinBox.new()
	_amount.min_value = 0
	_amount.max_value = 0        # set per-open from what's affordable
	_amount.step      = 1
	_amount.rounded   = true
	_amount.custom_minimum_size = Vector2(150, 0)
	row.add_child(_amount)

	_all_btn = Button.new()
	_all_btn.text = "Max"
	_all_btn.pressed.connect(_use_max)
	row.add_child(_all_btn)

	_pay_btn = Button.new()
	_pay_btn.text = "Make Payment"
	_pay_btn.custom_minimum_size = Vector2(300, 32)
	_pay_btn.pressed.connect(_pay)
	vbox.add_child(_pay_btn)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_status)

	var hint : Label = Label.new()
	hint.text = "Esc to close"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(hint)

func open() -> void:
	visible   = true
	_awaiting = true
	get_tree().paused = true
	_status.text = ""
	_refresh()
	_amount.get_line_edit().grab_focus()

func _refresh() -> void:
	var max_pay : int = GameManager.max_mortgage_payment()
	_balance.text = "Owing: $%d      Cash: $%d" % [GameManager.mortgage, GameManager.cash]
	_amount.max_value = max_pay
	if _amount.value > max_pay:
		_amount.value = max_pay
	var can_pay : bool = max_pay > 0
	_amount.editable  = can_pay
	_pay_btn.disabled = not can_pay
	_all_btn.disabled = not can_pay
	if GameManager.mortgage <= 0:
		_balance.text = "Your mortgage is paid off!"
	elif GameManager.cash <= 0:
		_say("Come back when you've got some cash.", TEXT_WARN)

func _use_max() -> void:
	_amount.value = GameManager.max_mortgage_payment()

func _pay() -> void:
	if not _awaiting:
		return
	var want : int = int(_amount.value)
	if want <= 0:
		_say("Enter an amount first.", TEXT_WARN)
		return
	var paid : int = GameManager.pay_mortgage(want)
	if paid <= 0:
		_say("That payment couldn't go through.", TEXT_WARN)
		return
	if GameManager.mortgage <= 0:
		_say("Paid $%d — that's your mortgage cleared! Congratulations!" % paid, TEXT_GOOD)
		GameManager.show_message("🎉 Mortgage paid off! The house is yours.", 5.0)
	else:
		_say("Paid $%d. $%d to go." % [paid, GameManager.mortgage], TEXT_GOOD)
	_amount.value = 0
	_refresh()

func _say(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)

func close() -> void:
	if not visible:
		return
	_awaiting = false
	visible   = false
	get_tree().paused = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if not _awaiting:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()
