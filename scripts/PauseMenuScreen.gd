extends Control

@onready var map_view      : Control     = $MapView
@onready var map_texture   : TextureRect = $MapView/MapPanel/VBox/MapTexture
@onready var player_marker : Label       = $MapView/MapPanel/VBox/MapTexture/PlayerMarker
@onready var settings_view : Control     = $SettingsView
@onready var snap_toggle      : CheckButton = $SettingsView/SettingsPanel/VBox/SnapToggle
@onready var easy_bike_toggle : CheckButton = $SettingsView/SettingsPanel/VBox/EasyBikeToggle
@onready var drops_spin    : SpinBox     = $SettingsView/SettingsPanel/VBox/DropsRow/DropsSpinBox
@onready var pkg_spin      : SpinBox     = $SettingsView/SettingsPanel/VBox/PkgRow/PkgSpinBox
@onready var calendar_button : Button        = $PanelContainer/HBoxContainer/Calendar
@onready var calendar_view   : Control       = $CalendarView
@onready var calendar_month  : Label         = $CalendarView/CalendarPanel/VBox/MonthLabel
@onready var calendar_grid   : GridContainer = $CalendarView/CalendarPanel/VBox/Grid

signal next_day_requested

var player_ref       : Node2D = null
var background_ref   : Node2D = null
var drop_pad_manager : Node   = null

var _pad_markers : Array[Label] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$PanelContainer/HBoxContainer/Resume.pressed.connect(_on_close_button_pressed)
	$PanelContainer/HBoxContainer/Quit.pressed.connect(func(): get_tree().quit())
	$PanelContainer/HBoxContainer/Map.pressed.connect(_on_map_button_pressed)
	$PanelContainer/HBoxContainer/Settings.pressed.connect(_on_settings_button_pressed)
	$PanelContainer/HBoxContainer/NextDay.pressed.connect(_on_next_day_pressed)
	$MapView/MapPanel/VBox/CloseMap.pressed.connect(_on_close_map_pressed)
	$SettingsView/SettingsPanel/VBox/CloseSettings.pressed.connect(_on_close_settings_pressed)
	snap_toggle.toggled.connect(_on_snap_toggled)
	easy_bike_toggle.toggled.connect(_on_easy_bike_toggled)
	drops_spin.value_changed.connect(_on_drops_changed)
	pkg_spin.value_changed.connect(_on_pkg_changed)
	calendar_button.pressed.connect(_on_calendar_button_pressed)
	$CalendarView/CalendarPanel/VBox/CloseCalendar.pressed.connect(_on_close_calendar_pressed)

func _on_pause_button_pressed() -> void:
	visible = true
	get_tree().paused = true

func _on_close_button_pressed() -> void:
	visible = false
	get_tree().paused = false

func _on_next_day_pressed() -> void:
	visible = false
	get_tree().paused = false
	next_day_requested.emit()

func _on_map_button_pressed() -> void:
	_ensure_pad_markers()
	map_view.visible = true
	_update_player_marker()

func _on_close_map_pressed() -> void:
	map_view.visible = false

func _on_settings_button_pressed() -> void:
	snap_toggle.set_pressed_no_signal(GameManager.snap_to_direction)
	easy_bike_toggle.set_pressed_no_signal(GameManager.easy_bike)
	drops_spin.value = GameManager.max_drops_per_day
	pkg_spin.value   = GameManager.max_packages_per_drop
	settings_view.visible = true

func _on_close_settings_pressed() -> void:
	settings_view.visible = false

# ── Calendar ───────────────────────────────────────────────
func _on_calendar_button_pressed() -> void:
	_populate_calendar()
	calendar_view.visible = true

func _on_close_calendar_pressed() -> void:
	calendar_view.visible = false

## Draws the current season as a monthly grid (6-day week), with day-1 aligned
## under its weekday column and today highlighted.
func _populate_calendar() -> void:
	for child in calendar_grid.get_children():
		child.queue_free()

	var date       : Dictionary = GameManager.calendar_date()
	var season     : int        = date.season
	var today      : int        = date.day
	var season_len : int        = Calendar.SEASON_LENGTHS[season]
	var week_size  : int        = GameManager.DAY_NAMES.size()

	calendar_month.text  = "%s — Year %d" % [Calendar.SEASON_NAMES[season], date.year]
	calendar_grid.columns = week_size

	# Weekday header row.
	for i in week_size:
		var head : Label = Label.new()
		head.text = GameManager.DAY_NAMES[i].substr(0, 3)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		head.custom_minimum_size = Vector2(46, 24)
		head.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
		calendar_grid.add_child(head)

	# Blank cells so day 1 sits under the correct weekday.
	var first_abs_day : int = GameManager.day - (today - 1)
	var offset        : int = (first_abs_day - 1) % week_size
	for _i in offset:
		calendar_grid.add_child(_make_blank_cell())

	# One cell per day of the season.
	for d in range(1, season_len + 1):
		calendar_grid.add_child(_make_day_cell(d, d == today))

func _make_blank_cell() -> Control:
	var cell : Control = Control.new()
	cell.custom_minimum_size = Vector2(46, 34)
	return cell

func _make_day_cell(day_num: int, is_today: bool) -> Control:
	var cell : PanelContainer = PanelContainer.new()
	cell.custom_minimum_size = Vector2(46, 34)

	var lbl : Label = Label.new()
	lbl.text = str(day_num)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

	if is_today:
		var sb : StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = Color(1.0, 0.75, 0.2)
		sb.set_corner_radius_all(6)
		cell.add_theme_stylebox_override("panel", sb)
		lbl.add_theme_color_override("font_color", Color(0.12, 0.1, 0.05))

	cell.add_child(lbl)
	return cell

func _on_snap_toggled(pressed: bool) -> void:
	if player_ref != null:
		player_ref.snap_to_direction = pressed
	GameManager.snap_to_direction = pressed
	GameManager.save_game()

func _on_easy_bike_toggled(pressed: bool) -> void:
	GameManager.easy_bike = pressed
	GameManager.save_game()

func _on_drops_changed(value: float) -> void:
	if drop_pad_manager != null:
		drop_pad_manager.max_drops_per_day = int(value)
	GameManager.max_drops_per_day = int(value)
	GameManager.save_game()

func _on_pkg_changed(value: float) -> void:
	if drop_pad_manager != null:
		drop_pad_manager.max_packages_per_drop = int(value)
	GameManager.max_packages_per_drop = int(value)
	GameManager.save_game()

func _process(_delta: float) -> void:
	if map_view.visible:
		_update_player_marker()
		_update_pad_markers()

func _update_player_marker() -> void:
	if player_ref == null or background_ref == null or map_texture.texture == null:
		return
	var tex_size  : Vector2 = map_texture.texture.get_size()
	var rect_size : Vector2 = map_texture.size
	if tex_size.x <= 0.0 or tex_size.y <= 0.0 or rect_size.x <= 0.0 or rect_size.y <= 0.0:
		return
	var fit_scale     : float   = min(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var displayed_size : Vector2 = tex_size * fit_scale
	var img_offset     : Vector2 = (rect_size - displayed_size) / 2.0
	var world_pos       : Vector2 = player_ref.global_position - background_ref.global_position
	var marker_pos      : Vector2 = img_offset + world_pos * fit_scale
	player_marker.position = marker_pos - player_marker.size / 2.0

func _ensure_pad_markers() -> void:
	if not _pad_markers.is_empty() or drop_pad_manager == null:
		return
	for i in drop_pad_manager.get_centroids().size():
		var lbl := Label.new()
		lbl.text = "■"
		lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1, 1.0))
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.custom_minimum_size = Vector2(16, 16)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		map_texture.add_child(lbl)
		_pad_markers.append(lbl)

func _update_pad_markers() -> void:
	if drop_pad_manager == null or background_ref == null or map_texture.texture == null:
		return
	var tex_size  : Vector2 = map_texture.texture.get_size()
	var rect_size : Vector2 = map_texture.size
	if tex_size.x <= 0.0 or rect_size.x <= 0.0:
		return
	var fit_scale     : float   = min(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var displayed_size : Vector2 = tex_size * fit_scale
	var img_offset     : Vector2 = (rect_size - displayed_size) / 2.0

	var packages  : Array[int]     = drop_pad_manager.get_packages()
	var centroids : Array[Vector2] = drop_pad_manager.get_centroids()
	var pulse     : float          = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)

	for i in _pad_markers.size():
		var lbl : Label = _pad_markers[i]
		if i >= packages.size() or packages[i] <= 0:
			lbl.visible = false
			continue
		lbl.visible = true
		var world_pos  : Vector2 = centroids[i] - background_ref.global_position
		var marker_pos : Vector2 = img_offset + world_pos * fit_scale
		lbl.position = marker_pos - lbl.size / 2.0
		lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1, pulse))
