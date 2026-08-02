extends CanvasLayer
## End-of-day ledger: fades in over the game, lists each delivery with its Rizz
## tip broken out, shows the undelivered-package dock (waived at Rizz ≥ 50%), and
## waits for the player to Continue (button or Space/Enter) before the next day.

const FADE_TIME : float = 0.5

@onready var fade         : ColorRect        = $Fade
@onready var panel        : PanelContainer   = $Panel
@onready var rows         : VBoxContainer     = $Panel/Margin/VBox/Scroll/Rows
@onready var summary      : Label            = $Panel/Margin/VBox/Summary
@onready var continue_btn : Button           = $Panel/Margin/VBox/ContinueButton

var _on_continue : Callable = Callable()
var _awaiting    : bool     = false

func _ready() -> void:
	process_mode    = Node.PROCESS_MODE_ALWAYS
	visible         = false
	fade.modulate.a  = 0.0
	panel.modulate.a = 0.0
	continue_btn.pressed.connect(_confirm)

## entries: Array of {name, value, tip}. undelivered: count of picked-up-but-
## -undelivered packages. dock: dollars to be docked (0 if waived). rizz_saved:
## whether Rizz ≥ 50% waived the dock.
func present(entries: Array, undelivered: int, dock: int, rizz_saved: bool, on_continue: Callable) -> void:
	_on_continue = on_continue

	for c in rows.get_children():
		c.queue_free()

	var gross : int = 0
	for e in entries:
		gross += int(e.value) + int(e.tip)
		_add_row(str(e.name), int(e.value), int(e.tip))
	if entries.is_empty():
		var none : Label = Label.new()
		none.text = "No deliveries today."
		none.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
		rows.add_child(none)

	var lines : Array = []
	lines.append("Deliveries: %d      Earned: $%d" % [entries.size(), gross])
	if undelivered > 0:
		if rizz_saved:
			lines.append("Undelivered: %d — dock waived (Rizz ≥ 50%%) ✨" % undelivered)
		else:
			lines.append("Undelivered: %d × $5 = -$%d" % [undelivered, dock])
	summary.text = "\n".join(lines) + "\n" + "Net: $%d" % (gross - dock)

	visible   = true
	_awaiting = true
	var tw : Tween = create_tween().set_parallel(true)
	tw.tween_property(fade,  "modulate:a", 1.0, FADE_TIME)
	tw.tween_property(panel, "modulate:a", 1.0, FADE_TIME)
	continue_btn.grab_focus()

func _add_row(row_name: String, value: int, tip: int) -> void:
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl : Label = Label.new()
	name_lbl.text = row_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var val_lbl : Label = Label.new()
	val_lbl.text = "$%d" % value
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.custom_minimum_size = Vector2(64, 0)
	row.add_child(val_lbl)

	var tip_lbl : Label = Label.new()
	tip_lbl.text = ("+$%d" % tip) if tip > 0 else "—"
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tip_lbl.custom_minimum_size = Vector2(56, 0)
	tip_lbl.add_theme_color_override("font_color",
			Color(0.95, 0.85, 0.2) if tip > 0 else Color(0.5, 0.5, 0.5))
	row.add_child(tip_lbl)

	rows.add_child(row)

func _confirm() -> void:
	if not _awaiting:
		return
	_awaiting = false
	var cb : Callable = _on_continue
	_on_continue = Callable()
	var tw : Tween = create_tween().set_parallel(true)
	tw.tween_property(fade,  "modulate:a", 0.0, FADE_TIME)
	tw.tween_property(panel, "modulate:a", 0.0, FADE_TIME)
	tw.chain().tween_callback(func() -> void:
		visible = false
		if cb.is_valid():
			cb.call()
	)

func _input(event: InputEvent) -> void:
	if not _awaiting:
		return
	if event is InputEventKey and event.pressed \
			and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER):
		get_viewport().set_input_as_handled()
		_confirm()
