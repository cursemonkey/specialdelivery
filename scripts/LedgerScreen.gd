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

## entries: Array of {name, value, rizz_tip, speed_tip, tip}. undelivered: count
## of picked-up-but-undelivered packages. dock: dollars to be docked (0 if
## waived). rizz_saved: whether Rizz ≥ 50% waived the dock.
func present(entries: Array, undelivered: int, dock: int, rizz_saved: bool, on_continue: Callable) -> void:
	_on_continue = on_continue

	for c in rows.get_children():
		c.queue_free()

	_add_header()

	var gross      : int = 0
	var rizz_total : int = 0
	var spd_total  : int = 0
	for e in entries:
		var rizz_tip  : int = int(e.get("rizz_tip",  0))
		var speed_tip : int = int(e.get("speed_tip", 0))
		gross      += int(e.value) + rizz_tip + speed_tip
		rizz_total += rizz_tip
		spd_total  += speed_tip
		_add_row(str(e.name), int(e.value), rizz_tip, speed_tip)
	if entries.is_empty():
		var none : Label = Label.new()
		none.text = "No deliveries today."
		none.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
		rows.add_child(none)

	var lines : Array = []
	lines.append("Deliveries: %d      Earned: $%d" % [entries.size(), gross])
	lines.append("Tips — Rizz $%d  +  Speed $%d  =  $%d" \
			% [rizz_total, spd_total, rizz_total + spd_total])
	if undelivered > 0:
		if rizz_saved:
			lines.append("Undelivered: %d — dock waived (Rizz ≥ 50%%) ✨" % undelivered)
		else:
			lines.append("Undelivered: %d × $5 = -$%d" % [undelivered, dock])
	lines.append("Net: $%d" % (gross - dock))
	lines.append(_records_line())
	summary.text = "\n".join(lines)

## Lifetime bests, so the player can see today against their record day.
func _records_line() -> String:
	var s : Dictionary = GameManager.stats
	if int(s.days_recorded) <= 0:
		return ""
	return "\nRecords — Earnings $%d (Day %d)   ·   Tips $%d (Day %d)   ·   Deliveries %d (Day %d)" % [
		int(s.best_earnings),   int(s.best_earnings_day),
		int(s.best_tips),       int(s.best_tips_day),
		int(s.best_deliveries), int(s.best_deliveries_day),
	]

## Column captions, so the two tip halves are readable at a glance.
func _add_header() -> void:
	var row : HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dim : Color = Color(0.62, 0.62, 0.68)
	for spec in [["Delivery", 0.0, HORIZONTAL_ALIGNMENT_LEFT],
				 ["Pay", 64.0, HORIZONTAL_ALIGNMENT_RIGHT],
				 ["Rizz", 56.0, HORIZONTAL_ALIGNMENT_RIGHT],
				 ["Speed", 56.0, HORIZONTAL_ALIGNMENT_RIGHT]]:
		var l : Label = Label.new()
		l.text = str(spec[0])
		l.horizontal_alignment = int(spec[2])
		if float(spec[1]) > 0.0:
			l.custom_minimum_size = Vector2(float(spec[1]), 0)
		else:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", dim)
		row.add_child(l)
	rows.add_child(row)

	visible   = true
	_awaiting = true
	var tw : Tween = create_tween().set_parallel(true)
	tw.tween_property(fade,  "modulate:a", 1.0, FADE_TIME)
	tw.tween_property(panel, "modulate:a", 1.0, FADE_TIME)
	continue_btn.grab_focus()

## One delivery: base pay, then the Rizz and Speed halves of the tip in their
## own columns. Either half shows "—" when it earned nothing, so a slow drop
## with no Rizz reads as a plain $0.00 tip.
func _add_row(row_name: String, value: int, rizz_tip: int, speed_tip: int) -> void:
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

	row.add_child(_tip_label(rizz_tip,  Color(0.95, 0.85, 0.2)))   # Rizz — gold
	row.add_child(_tip_label(speed_tip, Color(0.45, 0.80, 1.0)))   # Speed — blue

	rows.add_child(row)

func _tip_label(amount: int, color: Color) -> Label:
	var l : Label = Label.new()
	l.text = ("+$%d" % amount) if amount > 0 else "—"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size  = Vector2(56, 0)
	l.add_theme_color_override("font_color", color if amount > 0 else Color(0.5, 0.5, 0.5))
	return l

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
