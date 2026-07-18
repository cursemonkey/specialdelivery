extends Control

@onready var map_view      : Control     = $MapView
@onready var map_texture   : TextureRect = $MapView/MapPanel/VBox/MapTexture
@onready var player_marker : Label       = $MapView/MapPanel/VBox/MapTexture/PlayerMarker
@onready var settings_view : Control     = $SettingsView
@onready var snap_toggle      : CheckButton = $SettingsView/SettingsPanel/VBox/SnapToggle
@onready var easy_bike_toggle : CheckButton = $SettingsView/SettingsPanel/VBox/EasyBikeToggle
@onready var drops_spin    : SpinBox     = $SettingsView/SettingsPanel/VBox/DropsRow/DropsSpinBox
@onready var pkg_spin      : SpinBox     = $SettingsView/SettingsPanel/VBox/PkgRow/PkgSpinBox

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
