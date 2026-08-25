extends CanvasLayer
## A shop counter: pick something to buy, one purchase per slot. Stays open
## after a sale so the player can stock up, and reports why a purchase failed
## (no cash, no free slot) rather than silently doing nothing.
##
## Serves both counters. open() takes the shop to display:
##   • Nayra's groceries — consumables that fill inventory slots
##   • Aidan's garage    — materials, plus one-off vehicle upgrades that go
##     onto the bike rather than into the bag
##
## Built in code to match SleepPrompt, so no scene wiring is needed.

signal closed()

## Which counter is open.
const GROCERY : String = "grocery"
const GARAGE  : String = "garage"

## Aidan's one-off upgrades. Each is bought once, costs cash, and modifies the
## vehicle instead of taking an inventory slot:
##   id      — stable key
##   label   — button text
##   price   — dollars
##   sold    — Callable returning true once the player already owns it
##   buy     — Callable applying the purchase
##   note    — confirmation line
const UPGRADE_STORAGE : String = "storage"
const UPGRADE_SCOOTER : String = "scooter"

const PANEL_BG     : Color = Color(0.12, 0.12, 0.16, 0.96)
const PANEL_BORDER : Color = Color(0.55, 0.60, 0.75)
const TEXT_DIM     : Color = Color(0.72, 0.72, 0.78)
const TEXT_WARN    : Color = Color(0.95, 0.55, 0.45)
const TEXT_GOOD    : Color = Color(0.55, 0.90, 0.60)

var _panel    : PanelContainer
var _title    : Label
var _shop     : String = GROCERY
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

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)

	_purse = Label.new()
	_purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_purse.add_theme_color_override("font_color", TEXT_DIM)
	_purse.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_purse)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	vbox.add_child(_rows)

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

## Open a counter. `shop` is GROCERY or GARAGE; the stock list is rebuilt each
## time so sold-out upgrades disappear on the next visit.
func open(shop: String = GROCERY) -> void:
	_shop     = shop
	visible   = true
	_awaiting = true
	get_tree().paused = true
	_status.text = ""
	_title.text  = "🧺 Nayra's Groceries" if shop == GROCERY else "🔧 Aidan's Garage"
	_build_rows()
	_refresh()
	if not _buttons.is_empty():
		_buttons[0].button.grab_focus()

## Item ids this counter stocks.
func _stock() -> Array:
	return ItemRegistry.GARAGE_STOCK if _shop == GARAGE else ItemRegistry.SHOP_STOCK

## The upgrades on offer here, minus any the player already owns.
func _upgrades() -> Array:
	if _shop != GARAGE:
		return []
	var out : Array = []
	var gm : Node = GameManager
	out.append({
		"id":    UPGRADE_STORAGE,
		"label": "📦 Storage Upgrade — $500  (+%d packages)" % gm.STORAGE_UPGRADE_SLOTS,
		"price": 500,
	})
	# One scooter is enough; it vanishes from the list once bought.
	if not gm.has_scooter():
		out.append({
			"id":    UPGRADE_SCOOTER,
			"label": "🛵 Scooter — $15,000  (+1 package, faster)",
			"price": 15000,
		})
	return out

## Rebuild the buttons for the current shop.
func _build_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()
	_buttons.clear()
	for id in _stock():
		var btn : Button = Button.new()
		btn.text = ItemRegistry.shop_label(id)
		btn.custom_minimum_size = Vector2(320, 32)
		btn.pressed.connect(_buy.bind(id))
		_rows.add_child(btn)
		_buttons.append({"id": id, "button": btn, "upgrade": false, "price": ItemRegistry.price(id)})
	for u in _upgrades():
		var ub : Button = Button.new()
		ub.text = str(u.label)
		ub.custom_minimum_size = Vector2(320, 32)
		ub.pressed.connect(_buy_upgrade.bind(str(u.id)))
		_rows.add_child(ub)
		_buttons.append({"id": str(u.id), "button": ub, "upgrade": true, "price": int(u.price)})

## Grey out anything the player can't currently afford, and show the free-slot
## count so a full bag is visible before they click. Upgrades don't need a slot,
## so they're gated on cash alone.
func _refresh() -> void:
	var free : int = 0
	for s in GameManager.inventory:
		if s == null:
			free += 1
	_purse.text = "Cash: $%d      Bag: %d/%d slots free      %s: %d/%d packages" 			% [GameManager.cash, free, GameManager.INVENTORY_SLOTS,
			   GameManager.vehicle_name(), GameManager.packages, GameManager.bike_max_packages]
	for entry in _buttons:
		var btn : Button = entry.button
		var afford : bool = GameManager.cash >= int(entry.price)
		if bool(entry.upgrade):
			btn.disabled = not afford
		else:
			var id : String = str(entry.id)
			btn.disabled = not afford 					or GameManager.room_for(id) < ItemRegistry.portions(id)

func _buy(id: String) -> void:
	if not _awaiting:
		return
	var cost : int = ItemRegistry.price(id)
	if GameManager.cash < cost:
		_say("Not enough cash for that.", TEXT_WARN)
		return
	# Stacking means a bag with no empty slot may still have room in a partial
	# stack of this item, so ask about this item rather than about free slots.
	if GameManager.room_for(id) < ItemRegistry.portions(id):
		_say("No room in your bag for that.", TEXT_WARN)
		return
	if not GameManager.spend_cash(cost):
		_say("Not enough cash for that.", TEXT_WARN)
		return
	if not GameManager.add_item(id):
		GameManager.refund_cash(cost)   # the sale didn't happen
		_say("No room in your bag for that.", TEXT_WARN)
		return
	_say("Bought %s. %s" % [ItemRegistry.display_name(id), _thanks()], TEXT_GOOD)
	_refresh()

## Vehicle upgrades: cash only, applied straight to the bike. The row list is
## rebuilt afterwards so a one-off purchase disappears.
func _buy_upgrade(id: String) -> void:
	if not _awaiting:
		return
	var price : int = 0
	for entry in _buttons:
		if str(entry.id) == id and bool(entry.upgrade):
			price = int(entry.price)
	if GameManager.cash < price:
		_say("Not enough cash for that.", TEXT_WARN)
		return
	if not GameManager.spend_cash(price):
		_say("Not enough cash for that.", TEXT_WARN)
		return
	match id:
		UPGRADE_STORAGE:
			GameManager.add_storage_upgrade()
			_say("Fitted a bigger rack — %d packages now. \"That'll hold.\"" 					% GameManager.bike_max_packages, TEXT_GOOD)
		UPGRADE_SCOOTER:
			GameManager.grant_scooter()
			_say("Bought the scooter — %d packages, and quicker. \"Treat her right.\"" 					% GameManager.bike_max_packages, TEXT_GOOD)
		_:
			GameManager.refund_cash(price)
			_say("Aidan doesn't stock that.", TEXT_WARN)
			return
	_build_rows()
	_refresh()

## Shopkeeper's parting line, per counter.
func _thanks() -> String:
	return "\"Nice one.\"" if _shop == GARAGE else "\"Thank you — take care out there.\""

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
