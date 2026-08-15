extends CanvasLayer
## Sleep-duration picker shown at the bed: 1–8 hours, each button previewing the
## wake time and the recovery it buys (12.5% of HP and energy per hour, so 8
## hours is a guaranteed full restore).
##
## Built in code rather than as a .tscn so it can be added by Main without any
## scene wiring, and styled to match the game's other panels.

signal chosen(hours: int)
signal cancelled()

const PANEL_BG     : Color = Color(0.12, 0.12, 0.16, 0.96)
const PANEL_BORDER : Color = Color(0.55, 0.60, 0.75)
const TEXT_DIM     : Color = Color(0.72, 0.72, 0.78)

var _dim     : ColorRect
var _panel   : PanelContainer
var _grid    : GridContainer
var _detail  : Label
var _awaiting : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer        = 90
	visible      = false
	_build()

func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

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
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	var title : Label = Label.new()
	title.text = "😴 How long will you sleep?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	vbox.add_child(_grid)

	for h in range(TimeManager.SLEEP_MIN_HOURS, TimeManager.SLEEP_MAX_HOURS + 1):
		var btn : Button = Button.new()
		btn.text = "%dh" % h
		btn.custom_minimum_size = Vector2(56, 34)
		btn.focus_entered.connect(_update_detail.bind(h))
		btn.mouse_entered.connect(_update_detail.bind(h))
		btn.pressed.connect(_pick.bind(h))
		_grid.add_child(btn)

	_detail = Label.new()
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(_detail)

	var hint : Label = Label.new()
	hint.text = "Esc to cancel"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", TEXT_DIM)
	vbox.add_child(hint)

## Preview line for `hours`: when the player wakes, and how much they recover.
## Recovery is reported against what's actually missing, so it never promises
## more than the bars can show.
func _update_detail(hours: int) -> void:
	var frac  : float = float(hours) * TimeManager.SLEEP_RECOVERY_PER_HR
	var wake  : String = TimeManager.label_for_hour(TimeManager.wake_hour(float(hours)))
	var pct   : int    = int(round(frac * 100.0))
	var rolls : String = "  ·  next day" if TimeManager.sleep_crosses_midnight(float(hours)) else ""
	_detail.text = "Wake at %s   ·   +%d%% HP & Energy%s" % [wake, pct, rolls]

func open() -> void:
	visible   = true
	_awaiting = true
	get_tree().paused = true
	var first : Button = _grid.get_child(0)
	first.grab_focus()
	_update_detail(TimeManager.SLEEP_MIN_HOURS)

func _pick(hours: int) -> void:
	if not _awaiting:
		return
	_close()
	chosen.emit(hours)

func _cancel() -> void:
	if not _awaiting:
		return
	_close()
	cancelled.emit()

func _close() -> void:
	_awaiting         = false
	visible           = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if not _awaiting:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cancel()
