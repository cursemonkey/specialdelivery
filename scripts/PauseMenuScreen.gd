extends Control

@onready var map_view      : Control     = $MapView
@onready var map_texture   : TextureRect = $MapView/MapPanel/VBox/MapTexture
@onready var player_marker : Label       = $MapView/MapPanel/VBox/MapTexture/PlayerMarker
@onready var settings_view : Control     = $SettingsView
@onready var snap_toggle      : CheckButton = $SettingsView/SettingsPanel/VBox/SnapToggle
@onready var easy_bike_toggle : CheckButton = $SettingsView/SettingsPanel/VBox/EasyBikeToggle
@onready var drops_spin    : SpinBox     = $SettingsView/SettingsPanel/VBox/DropsRow/DropsSpinBox
@onready var pkg_spin      : SpinBox     = $SettingsView/SettingsPanel/VBox/PkgRow/PkgSpinBox
@onready var scale_slider  : HSlider     = $SettingsView/SettingsPanel/VBox/ScaleRow/ScaleSlider
@onready var scale_value   : Label       = $SettingsView/SettingsPanel/VBox/ScaleRow/ScaleValue
@onready var status_button   : Button        = $PanelContainer/HBoxContainer/Status
@onready var status_view     : Control       = $StatusView
@onready var friends_button  : Button        = $PanelContainer/HBoxContainer/Friends
@onready var friends_view    : Control       = $FriendsView
@onready var calendar_button : Button        = $PanelContainer/HBoxContainer/Calendar
@onready var calendar_view   : Control       = $CalendarView
@onready var calendar_month  : Label         = $CalendarView/CalendarPanel/VBox/MonthLabel
@onready var calendar_grid   : GridContainer = $CalendarView/CalendarPanel/VBox/Grid

signal next_day_requested

var player_ref       : Node2D = null
var background_ref   : Node2D = null
var drop_pad_manager : Node   = null
var save_slot_panel  : Node   = null

var _pad_markers  : Array[Label] = []
var _npc_markers  : Array        = []   # [{npc: RegularNPC, dot: Control}]
var _home_marker  : Control      = null
var home_position : Vector2      = Vector2.ZERO   # set by Main once a home is chosen
var has_home      : bool         = false
var _selected     : int          = -1     # index into _npc_markers, -1 = none
var _name_label   : Label        = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$PanelContainer/HBoxContainer/Resume.pressed.connect(_on_close_button_pressed)
	$PanelContainer/HBoxContainer/Quit.pressed.connect(func(): get_tree().quit())
	$PanelContainer/HBoxContainer/Map.pressed.connect(_on_map_button_pressed)
	$PanelContainer/HBoxContainer/Settings.pressed.connect(_on_settings_button_pressed)
	$PanelContainer/HBoxContainer/NextDay.pressed.connect(_on_next_day_pressed)
	$PanelContainer/HBoxContainer/Save.pressed.connect(_on_save_pressed)
	$MapView/MapPanel/VBox/CloseMap.pressed.connect(_on_close_map_pressed)
	$SettingsView/SettingsPanel/VBox/CloseSettings.pressed.connect(_on_close_settings_pressed)
	snap_toggle.toggled.connect(_on_snap_toggled)
	easy_bike_toggle.toggled.connect(_on_easy_bike_toggled)
	drops_spin.value_changed.connect(_on_drops_changed)
	pkg_spin.value_changed.connect(_on_pkg_changed)
	scale_slider.value_changed.connect(_on_sprite_scale_changed)
	status_button.pressed.connect(_on_status_button_pressed)
	friends_button.pressed.connect(_on_friends_button_pressed)
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

func _on_save_pressed() -> void:
	if save_slot_panel == null:
		return
	save_slot_panel.open_panel(save_slot_panel.Mode.SAVE, _on_save_slot_chosen)

func _on_save_slot_chosen(slot: int) -> void:
	GameManager.save_game(slot)
	GameManager.show_message("💾 Saved to Slot %d!" % slot)

func _on_map_button_pressed() -> void:
	_ensure_pad_markers()
	_ensure_home_marker()
	_ensure_npc_markers()
	map_view.visible = true
	_update_player_marker()
	_update_home_marker()
	_update_npc_markers()

func _on_close_map_pressed() -> void:
	map_view.visible = false
	_select_marker(-1)

func _on_settings_button_pressed() -> void:
	snap_toggle.set_pressed_no_signal(GameManager.snap_to_direction)
	easy_bike_toggle.set_pressed_no_signal(GameManager.easy_bike)
	drops_spin.value = GameManager.max_drops_per_day
	pkg_spin.value   = GameManager.max_packages_per_drop
	scale_slider.set_value_no_signal(GameManager.sprite_scale)
	scale_value.text = "%.2f" % GameManager.sprite_scale
	settings_view.visible = true

func _on_close_settings_pressed() -> void:
	settings_view.visible = false

# ── Status ────────────────────────────────────────
## Player + bike read-out. The screen refreshes itself from GameManager.
func _on_status_button_pressed() -> void:
	status_view.open()

# ── Friends ────────────────────────────────────
## Friendship read-out, one row of hearts per villager. The screen refreshes
## itself from GameManager.
func _on_friends_button_pressed() -> void:
	friends_view.open()

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
	GameManager.save_settings()

func _on_easy_bike_toggled(pressed: bool) -> void:
	GameManager.easy_bike = pressed
	GameManager.save_settings()

func _on_drops_changed(value: float) -> void:
	if drop_pad_manager != null:
		drop_pad_manager.max_drops_per_day = int(value)
	GameManager.max_drops_per_day = int(value)
	GameManager.save_settings()

## One dial for the whole cast: the player and every NPC re-scale live.
func _on_sprite_scale_changed(value: float) -> void:
	GameManager.set_sprite_scale(value)
	scale_value.text = "%.2f" % GameManager.sprite_scale
	GameManager.save_settings()

func _on_pkg_changed(value: float) -> void:
	if drop_pad_manager != null:
		drop_pad_manager.max_packages_per_drop = int(value)
	GameManager.max_packages_per_drop = int(value)
	GameManager.save_settings()

## Floating caption that names the selected marker. Sits above the dot.
func _ensure_name_label() -> void:
	if _name_label != null:
		return
	_name_label = Label.new()
	_name_label.visible = false
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_color", Color(1, 0.95, 0.75))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.add_theme_font_size_override("font_size", 13)
	map_texture.add_child(_name_label)

func _selected_dot() -> Control:
	if _selected < 0 or _selected >= _npc_markers.size():
		return null
	return _npc_markers[_selected].dot

## Clicking a marker selects it (and clicking it again clears the selection).
func _on_marker_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed 			and event.button_index == MOUSE_BUTTON_LEFT:
		_select_marker(index if _selected != index else -1)

func _select_marker(index: int) -> void:
	var old : Control = _selected_dot()
	_selected = index
	if old != null:
		old.queue_redraw()
	var cur : Control = _selected_dot()
	if cur != null:
		cur.queue_redraw()
	_update_name_label()

## Step to the next/previous marker that's actually on the map, wrapping around.
func _cycle_marker(step: int) -> void:
	var visible_idx : Array = []
	for i in _npc_markers.size():
		if _npc_markers[i].dot.visible:
			visible_idx.append(i)
	if visible_idx.is_empty():
		return
	var pos : int = visible_idx.find(_selected)
	if pos == -1:
		pos = 0 if step > 0 else visible_idx.size() - 1
	else:
		pos = wrapi(pos + step, 0, visible_idx.size())
	_select_marker(visible_idx[pos])

func _update_name_label() -> void:
	if _name_label == null:
		return
	var dot : Control = _selected_dot()
	if dot == null or not dot.visible:
		_name_label.visible = false
		return
	var npc : Node = _npc_markers[_selected].npc
	if not is_instance_valid(npc):
		_name_label.visible = false
		return
	_name_label.text    = npc.display_label()
	_name_label.visible = true
	_name_label.reset_size()
	# Centre the caption over the dot, just above it.
	_name_label.position = dot.position 			+ Vector2(dot.size.x * 0.5 - _name_label.size.x * 0.5, -_name_label.size.y - 2.0)

## While the map is open, arrow keys / WASD step through the NPC markers.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Status is a plain read-out: ESC just closes it, like its Close button.
	if status_view.visible:
		if event is InputEventKey and event.pressed and not event.echo \
				and event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			status_view.close()
		return
	if not map_view.visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var step : int = 0
	match event.keycode:
		KEY_RIGHT, KEY_D, KEY_DOWN, KEY_S: step = 1
		KEY_LEFT,  KEY_A, KEY_UP,   KEY_W: step = -1
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_select_marker(-1)
			_on_close_map_pressed()
			return
		_: return
	get_viewport().set_input_as_handled()
	_cycle_marker(step)

func _process(_delta: float) -> void:
	if map_view.visible:
		_update_player_marker()
		_update_pad_markers()
		_update_home_marker()
		_update_npc_markers()
		_update_name_label()

# ── Home marker ────────────────────────────────────────────
# Drawn with primitives rather than an emoji glyph: the default font has no
# colour-emoji coverage, so "🏠" renders blank.
func _ensure_home_marker() -> void:
	if _home_marker != null:
		return
	_home_marker = Control.new()
	_home_marker.custom_minimum_size = Vector2(18, 18)
	_home_marker.size = Vector2(18, 18)
	_home_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_marker.draw.connect(_draw_home_icon)
	map_texture.add_child(_home_marker)

func _draw_home_icon() -> void:
	var c    : Control = _home_marker
	var w    : float   = c.size.x
	var h    : float   = c.size.y
	var roof : Color   = Color(0.85, 0.25, 0.2)
	var wall : Color   = Color(0.98, 0.95, 0.88)
	var line : Color   = Color(0.15, 0.1, 0.08)
	# Body
	c.draw_rect(Rect2(w * 0.22, h * 0.45, w * 0.56, h * 0.45), wall)
	c.draw_rect(Rect2(w * 0.22, h * 0.45, w * 0.56, h * 0.45), line, false, 1.0)
	# Roof
	var pts : PackedVector2Array = PackedVector2Array([
		Vector2(w * 0.10, h * 0.48),
		Vector2(w * 0.50, h * 0.12),
		Vector2(w * 0.90, h * 0.48),
	])
	c.draw_colored_polygon(pts, roof)
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), line, 1.0)
	# Door
	c.draw_rect(Rect2(w * 0.42, h * 0.62, w * 0.16, h * 0.28), line)

func _update_home_marker() -> void:
	if _home_marker == null:
		return
	if not has_home or background_ref == null or map_texture.texture == null:
		_home_marker.visible = false
		return
	var tex_size  : Vector2 = map_texture.texture.get_size()
	var rect_size : Vector2 = map_texture.size
	if tex_size.x <= 0.0 or rect_size.x <= 0.0:
		_home_marker.visible = false
		return
	_home_marker.visible = true
	var fit_scale      : float   = min(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var displayed_size : Vector2 = tex_size * fit_scale
	var img_offset     : Vector2 = (rect_size - displayed_size) / 2.0
	var world_pos      : Vector2 = home_position - background_ref.global_position
	_home_marker.position = img_offset + world_pos * fit_scale - _home_marker.size / 2.0
	_home_marker.queue_redraw()

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

# ── NPC markers ────────────────────────────────────────────
# One circular dot per named NPC, tinted with that NPC's shirt colour. NPCs who
# are indoors are shown at their building's door; NPCs away from town are hidden.
const NPC_DOT_SIZE : float = 12.0

func _ensure_npc_markers() -> void:
	if not _npc_markers.is_empty():
		return
	for npc in get_tree().get_nodes_in_group("regular_npc"):
		var dot : Control = Control.new()
		dot.custom_minimum_size = Vector2(NPC_DOT_SIZE, NPC_DOT_SIZE)
		dot.size = Vector2(NPC_DOT_SIZE, NPC_DOT_SIZE)
		dot.mouse_filter = Control.MOUSE_FILTER_STOP   # clickable
		var tint : Color = Color(0.9, 0.9, 0.9)
		if npc.definition != null:
			tint = npc.definition.shirt_color
		dot.draw.connect(_draw_npc_dot.bind(dot, tint))
		var index : int = _npc_markers.size()
		dot.gui_input.connect(_on_marker_input.bind(index))
		map_texture.add_child(dot)
		_npc_markers.append({"npc": npc, "dot": dot})
	_ensure_name_label()

func _draw_npc_dot(dot: Control, tint: Color) -> void:
	var c : Vector2 = dot.size * 0.5
	var r : float   = dot.size.x * 0.5
	dot.draw_circle(c, r, Color(0, 0, 0, 0.55))          # outline/shadow
	dot.draw_circle(c, r - 1.5, tint)                     # body
	dot.draw_circle(c - Vector2(0, r * 0.3), r * 0.28, Color(1, 1, 1, 0.5))   # highlight
	# Selected marker gets a bright ring so it stands out from the cluster.
	if _selected_dot() == dot:
		dot.draw_arc(c, r + 2.5, 0.0, TAU, 20, Color(1.0, 0.95, 0.5), 2.0)

func _update_npc_markers() -> void:
	if background_ref == null or map_texture.texture == null:
		return
	var tex_size  : Vector2 = map_texture.texture.get_size()
	var rect_size : Vector2 = map_texture.size
	if tex_size.x <= 0.0 or rect_size.x <= 0.0:
		return
	var fit_scale      : float   = min(rect_size.x / tex_size.x, rect_size.y / tex_size.y)
	var displayed_size : Vector2 = tex_size * fit_scale
	var img_offset     : Vector2 = (rect_size - displayed_size) / 2.0

	# Several NPCs are often in the same building (Elsie and Spider share a home;
	# Elsie's hospital shifts overlap Doctor Carrington's). Group markers by the
	# spot they resolve to so they can be fanned out instead of stacking.
	var groups : Dictionary = {}   # rounded world pos -> [entries]
	for entry in _npc_markers:
		var npc : Node = entry.npc
		if not is_instance_valid(npc):
			entry.dot.visible = false
			continue
		var info : Dictionary = npc.map_marker_position()
		if not info.valid:
			entry.dot.visible = false
			continue
		entry["info"] = info
		var key : Vector2i = Vector2i(info.position.round())
		if not groups.has(key):
			groups[key] = []
		groups[key].append(entry)

	for key in groups:
		var members : Array = groups[key]
		for i in members.size():
			var entry : Dictionary = members[i]
			var dot   : Control    = entry.dot
			var info  : Dictionary = entry.info
			dot.visible = true
			var world_pos : Vector2 = info.position - background_ref.global_position
			var base      : Vector2 = img_offset + world_pos * fit_scale - dot.size / 2.0
			# Indoors markers sit slightly above the door so they read as "in here".
			if info.indoors:
				base.y -= NPC_DOT_SIZE * 0.5
			dot.position = base + _fan_offset(i, members.size())
			dot.queue_redraw()

## Spread co-located markers so each stays visible: a single NPC sits centred,
## two or more fan out evenly around the shared point.
func _fan_offset(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	var radius : float = NPC_DOT_SIZE * 0.62
	var angle  : float = TAU * float(index) / float(count) - PI * 0.5
	return Vector2(cos(angle), sin(angle)) * radius

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
