extends CanvasLayer
## Shared slot picker used for New Game, Continue, and manual Save from the
## pause menu. Callers pass a mode and a callback; this panel never performs
## the load/reset/save itself — it only resolves which slot was chosen
## (asking to confirm overwrite when needed) and hands that back.

enum Mode { NEW, LOAD, SAVE }

const MONTHS : Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
		"Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

const SCROLL_STEP : float = 60.0   # px per Up/Down key press

@onready var title_label     : Label           = $Panel/Margin/VBox/TitleLabel
@onready var slot_scroll     : ScrollContainer = $Panel/Margin/VBox/SlotScroll
@onready var close_btn       : Button          = $Panel/Margin/VBox/CloseBtn
@onready var overwrite_panel : PanelContainer  = $OverwriteConfirm
@onready var overwrite_label : Label           = $OverwriteConfirm/Margin/VBox/MessageLabel
@onready var overwrite_yes   : Button          = $OverwriteConfirm/Margin/VBox/HBox/YesBtn
@onready var overwrite_no    : Button          = $OverwriteConfirm/Margin/VBox/HBox/NoBtn

var _slot_buttons  : Array[Button] = []
var _mode          : int           = Mode.LOAD
var _on_chosen     : Callable      = Callable()
var _pending_slot  : int           = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	overwrite_panel.visible = false
	for i in GameManager.SAVE_SLOT_COUNT:
		var btn : Button = get_node("Panel/Margin/VBox/SlotScroll/SlotList/Slot%dBtn" % (i + 1))
		_slot_buttons.append(btn)
		btn.pressed.connect(_on_slot_pressed.bind(i + 1))
	close_btn.pressed.connect(close_panel)
	overwrite_yes.pressed.connect(_on_overwrite_confirmed)
	overwrite_no.pressed.connect(_on_overwrite_cancelled)

func _unhandled_input(event: InputEvent) -> void:
	if not visible or overwrite_panel.visible:
		return
	if event.is_action_pressed("move_up"):
		slot_scroll.scroll_vertical -= int(SCROLL_STEP)
	elif event.is_action_pressed("move_down"):
		slot_scroll.scroll_vertical += int(SCROLL_STEP)

func open_panel(mode: int, on_chosen: Callable) -> void:
	_mode      = mode
	_on_chosen = on_chosen
	overwrite_panel.visible = false
	match mode:
		Mode.NEW:  title_label.text = "New Game — Choose a Slot"
		Mode.LOAD: title_label.text = "Continue — Choose a Slot"
		Mode.SAVE: title_label.text = "Save Game — Choose a Slot"
	_refresh_slots()
	visible = true

func close_panel() -> void:
	visible = false
	overwrite_panel.visible = false

func _refresh_slots() -> void:
	for i in _slot_buttons.size():
		var slot : int        = i + 1
		var info : Dictionary = GameManager.get_slot_info(slot)
		var btn  : Button      = _slot_buttons[i]
		if info.get("exists", false):
			btn.text = "%s — Day %d · $%d\n%s" % [
				str(info.get("slot_name", "Slot %d" % slot)),
				int(info.get("day", 1)),
				int(info.get("cash", 0)),
				_format_timestamp(int(info.get("timestamp", 0))),
			]
			btn.disabled = false
		else:
			btn.text     = "Slot %d — Empty" % slot
			btn.disabled = (_mode == Mode.LOAD)

func _on_slot_pressed(slot: int) -> void:
	var info : Dictionary = GameManager.get_slot_info(slot)
	if info.get("exists", false) and _mode != Mode.LOAD:
		_pending_slot = slot
		var verb : String = "start a new game" if _mode == Mode.NEW else "overwrite the save"
		overwrite_label.text = "Slot %d already has a save. Overwrite it and %s?" % [slot, verb]
		overwrite_panel.visible = true
		return
	_choose(slot)

func _on_overwrite_confirmed() -> void:
	overwrite_panel.visible = false
	_choose(_pending_slot)

func _on_overwrite_cancelled() -> void:
	overwrite_panel.visible = false
	_pending_slot = -1

func _choose(slot: int) -> void:
	var callback : Callable = _on_chosen
	close_panel()
	if callback.is_valid():
		callback.call(slot)

func _format_timestamp(ts: int) -> String:
	if ts <= 0:
		return "no date yet"
	var d       : Dictionary = Time.get_datetime_dict_from_unix_time(ts)
	var hour12  : int        = int(d.hour) % 12
	if hour12 == 0:
		hour12 = 12
	var ampm : String = "AM" if int(d.hour) < 12 else "PM"
	return "%s %d, %d  %d:%02d %s" % [MONTHS[int(d.month) - 1], int(d.day), int(d.year), hour12, int(d.minute), ampm]
