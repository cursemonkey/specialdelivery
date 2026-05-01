extends CanvasLayer
## HUD — listens to GameManager signals and updates labels/panels.

@onready var cash_label         : Label          = $Panel/VBox/CashLabel
@onready var pkg_label          : Label          = $Panel/VBox/PackageLabel
@onready var day_label          : Label          = $Panel/VBox/DayLabel
@onready var time_label         : Label          = $Panel/VBox/TimeLabel
@onready var mode_label         : Label          = $StatusPanel/VBox/ModeLabel
@onready var speed_label        : Label          = $StatusPanel/VBox/SpeedLabel
@onready var msg_label          : Label          = $MessageBox/MsgLabel
@onready var msg_box            : PanelContainer = $MessageBox
@onready var msg_timer          : Timer          = $MessageTimer
@onready var day_complete_panel : PanelContainer = $DayCompletePanel
@onready var bonus_label        : Label          = $DayCompletePanel/VBox/BonusLabel

signal skip_day_pressed()
signal continue_playing_pressed()

var _player : CharacterBody2D = null

func _ready() -> void:
	GameManager.cash_changed.connect(_on_cash_changed)
	GameManager.packages_changed.connect(_on_packages_changed)
	GameManager.day_changed.connect(_on_day_changed)
	GameManager.message_requested.connect(show_message)
	msg_box.visible          = false
	day_complete_panel.visible = false
	_refresh()

func set_player(p: CharacterBody2D) -> void:
	_player = p

func _process(_delta: float) -> void:
	if _player == null:
		return
	mode_label.text  = "🚲 On Bicycle" if _player.on_bike else "🚶 On Foot"
	var spd: int = abs(_player.bike_speed) if _player.on_bike \
			   else _player.velocity.length()
	speed_label.text = "Speed: %.1f" % spd

func _refresh() -> void:
	cash_label.text  = "💰 Cash: $%d" % GameManager.cash
	pkg_label.text   = "📫 Packages: %d" % GameManager.packages
	day_label.text   = "📅 Day %d" % GameManager.day
	time_label.text  = "⏱ 6:00"

func update_timer(remaining: float) -> void:
	var m := int(remaining) / 60
	var s := int(remaining) % 60
	time_label.text = "⏱ %d:%02d" % [m, s]

func show_day_complete_prompt(bonus: int) -> void:
	bonus_label.text = "🎉 All delivered! +$%d bonus!" % bonus
	day_complete_panel.visible = true

func hide_day_complete_prompt() -> void:
	day_complete_panel.visible = false

func _on_cash_changed(v: int)     -> void: cash_label.text = "💰 Cash: $%d" % v
func _on_packages_changed(v: int) -> void: pkg_label.text  = "📫 Packages: %d" % v
func _on_day_changed(v: int)      -> void: day_label.text  = "📅 Day %d" % v

func show_message(text: String, duration: float = 2.5) -> void:
	msg_label.text  = text
	msg_box.visible = true
	msg_timer.wait_time = duration
	msg_timer.start()

func _on_msg_timer_timeout() -> void:
	msg_box.visible = false

func _on_skip_day_pressed() -> void:
	skip_day_pressed.emit()

func _on_continue_pressed() -> void:
	continue_playing_pressed.emit()
