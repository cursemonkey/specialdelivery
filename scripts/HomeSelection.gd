extends CanvasLayer

signal home_selected(home_id: String, price: int)

const MAYOR_TEXT = [
	"Mayor Henderson: \"Welcome to Cozy Town! The city is offering you one of four homes as part of our new resident program. Choose wisely — this will be your home base and daily spawn point.\""
]

const HOME_NAMES = {
	"Townhouse3": "Townhouse 3  —  $100,000",
	"Apartments":  "Apartments  —  $150,000",
	"House28":     "House 28  —  $300,000",
	"House10":     "House 10  —  $500,000",
}

@onready var dim              : ColorRect      = $Dim
@onready var choice_panel     : PanelContainer = $ChoicePanel
@onready var confirm_panel    : PanelContainer = $ConfirmPanel
@onready var map_popup        : PanelContainer = $MapPopup
@onready var map_title        : Label          = $MapPopup/Margin/VBox/TitleLabel
@onready var map_clip         : Control        = $MapPopup/Margin/VBox/MapFrame/MapClip
@onready var map_texture_rect : TextureRect    = $MapPopup/Margin/VBox/MapFrame/MapClip/MapTextureRect
@onready var townhouse_btn    : Button         = $ChoicePanel/Margin/Grid/Townhouse3Btn
@onready var apartments_btn   : Button         = $ChoicePanel/Margin/Grid/ApartmentsBtn
@onready var house28_btn      : Button         = $ChoicePanel/Margin/Grid/House28Btn
@onready var house10_btn      : Button         = $ChoicePanel/Margin/Grid/House10Btn
@onready var yes_btn          : Button         = $ConfirmPanel/Margin/VBox/HBox/YesBtn
@onready var wait_btn         : Button         = $ConfirmPanel/Margin/VBox/HBox/WaitBtn

var dialogue_box_ref : Node     = null
var background_ref   : Sprite2D = null
var home_doors       : Dictionary = {}

var _pending_id    : String = ""
var _pending_price : int    = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	townhouse_btn.pressed.connect(func(): _preview("Townhouse3", 100000))
	apartments_btn.pressed.connect(func(): _preview("Apartments",  150000))
	house28_btn.pressed.connect(func():    _preview("House28",     300000))
	house10_btn.pressed.connect(func():    _preview("House10",     500000))
	yes_btn.pressed.connect(_on_yes)
	wait_btn.pressed.connect(_on_wait)

func show_selection() -> void:
	visible               = true
	choice_panel.visible  = false
	confirm_panel.visible = false
	map_popup.visible     = false
	dim.visible           = false
	if dialogue_box_ref != null:
		var mayor : NPCDefinition = NPCRegistry.get_definition("mayor_henderson")
		var portrait : Texture2D = mayor.portrait_texture() if mayor != null else null
		dialogue_box_ref.open(MAYOR_TEXT, _show_choices, portrait)
	else:
		_show_choices()

func _show_choices() -> void:
	dim.visible          = true
	choice_panel.visible = true
	get_tree().paused    = true

func _preview(home_id: String, price: int) -> void:
	_pending_id           = home_id
	_pending_price        = price
	choice_panel.visible  = false
	confirm_panel.visible = true
	map_popup.visible     = true
	_update_map.call_deferred(home_id)

func _update_map(home_id: String) -> void:
	if background_ref == null or not home_doors.has(home_id):
		return
	var home_pos : Vector2 = home_doors[home_id]
	map_texture_rect.texture      = background_ref.texture
	map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP
	map_texture_rect.size         = background_ref.texture.get_size()
	map_texture_rect.scale        = background_ref.scale * 0.6
	map_texture_rect.position     = map_clip.size * 0.5 - home_pos * 0.6
	map_title.text                = HOME_NAMES.get(home_id, home_id)

func _on_yes() -> void:
	visible               = false
	dim.visible           = false
	confirm_panel.visible = false
	map_popup.visible     = false
	get_tree().paused     = false
	home_selected.emit(_pending_id, _pending_price)

func _on_wait() -> void:
	confirm_panel.visible = false
	map_popup.visible     = false
	choice_panel.visible  = true
