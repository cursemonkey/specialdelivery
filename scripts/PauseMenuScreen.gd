extends Control

@onready var map_view      : Control     = $MapView
@onready var map_texture   : TextureRect = $MapView/MapPanel/VBox/MapTexture
@onready var player_marker : Label       = $MapView/MapPanel/VBox/MapTexture/PlayerMarker
@onready var settings_view : Control     = $SettingsView
@onready var snap_toggle   : CheckButton = $SettingsView/SettingsPanel/VBox/SnapToggle

var player_ref     : Node2D = null
var background_ref : Node2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	$PanelContainer/HBoxContainer/Resume.pressed.connect(_on_close_button_pressed)
	$PanelContainer/HBoxContainer/Quit.pressed.connect(func(): get_tree().quit())
	$PanelContainer/HBoxContainer/Map.pressed.connect(_on_map_button_pressed)
	$PanelContainer/HBoxContainer/Settings.pressed.connect(_on_settings_button_pressed)
	$MapView/MapPanel/VBox/CloseMap.pressed.connect(_on_close_map_pressed)
	$SettingsView/SettingsPanel/VBox/CloseSettings.pressed.connect(_on_close_settings_pressed)
	snap_toggle.toggled.connect(_on_snap_toggled)

func _on_pause_button_pressed() -> void:
	visible = true
	get_tree().paused = true

func _on_close_button_pressed() -> void:
	visible = false
	get_tree().paused = false

func _on_map_button_pressed() -> void:
	map_view.visible = true
	_update_player_marker()

func _on_close_map_pressed() -> void:
	map_view.visible = false

func _on_settings_button_pressed() -> void:
	if player_ref != null:
		snap_toggle.set_pressed_no_signal(player_ref.snap_to_direction)
	settings_view.visible = true

func _on_close_settings_pressed() -> void:
	settings_view.visible = false

func _on_snap_toggled(pressed: bool) -> void:
	if player_ref != null:
		player_ref.snap_to_direction = pressed

func _process(_delta: float) -> void:
	if map_view.visible:
		_update_player_marker()

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
