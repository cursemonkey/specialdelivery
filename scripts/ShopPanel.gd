extends CanvasLayer
## Nayra's grocery counter: pick an item to buy, one purchase per slot. Stays
## open after a sale so the player can stock up, and reports why a purchase
## failed (no cash, no free slot) rather than silently doing nothing.
##
## Built in code to match SleepPrompt, so no scene wiring is needed.

signal closed()

const PANEL_BG     : Color = Color(0.12, 0.12, 0.16, 0.96)
const PANEL_BORDER : Color = Color(0.55, 0.60, 0.75)
const TEXT_DIM     : Color = Color(0.72, 0.72, 0.78)
const TEXT_WARN    : Color = Color(0.95, 0.55, 0.45)
const TEXT_GOOD    : Color = Color(0.55, 0.90, 0.60)

var _panel    : PanelContainer
var _rows     : VBoxContainer
var _status   : Label
var _purse    : Label
var _buttons  : Array = []
var _awaiting : bool  = false

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
	title.text = "🧺 Nayra's Groceries"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_purse = Label.new()
	_purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_purse.add_theme_color_override("font_color", TEXT_DIM)
	_purse.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_purse)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows)

	for id in ItemRegistry.SHOP_STOCK:
		var btn : Button = Button.new()
		btn.text = ItemRegistry.shop_label(id)
		btn.custom_minimum_size = Vector2(300, 32)
		btn.pressed.connect(_buy.bind(id))
		_rows.add_child(btn)
		_buttons.append({"id": id, "button": btn})

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
	if not _buttons.is_empty():
		_buttons[0].button.grab_focus()

## Grey out anything the player can't currently afford, and show the free-slot
## count so a full bag is visible before they click.
func _refresh() -> void:
	var free : int = 0
	for s in GameManager.inventory:
		if s == null:
			free += 1
	_purse.text = "Cash: $%d      Bag: %d/%d slots free" \
			% [GameManager.cash, free, GameManager.INVENTORY_SLOTS]
	for entry in _buttons:
		var id  : String = str(entry.id)
		var btn : Button = entry.button
		btn.disabled = GameManager.cash < ItemRegistry.price(id) or free <= 0

func _buy(id: String) -> void:
	if not _awaiting:
		return
	var cost : int = ItemRegistry.price(id)
	if GameManager.cash < cost:
		_say("Not enough cash for that.", TEXT_WARN)
		return
	if not GameManager.has_free_slot():
		_say("Your bag is full.", TEXT_WARN)
		return
	if not GameManager.spend_cash(cost):
		_say("Not enough cash for that.", TEXT_WARN)
		return
	if not GameManager.add_item(id):
		GameManager.refund_cash(cost)   # the sale didn't happen
		_say("Your bag is full.", TEXT_WARN)
		return
	_say("Bought %s. \"Thank you — take care out there.\"" % ItemRegistry.display_name(id), TEXT_GOOD)
	_refresh()

func _say(text: String, color: Color) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", color)

func _close() -> void:
	_awaiting         = false
	visible           = false
	get_tree().paused = false
	closed.emit()

func _input(event: InputEvent) -> void:
	if not _awaiting:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()
