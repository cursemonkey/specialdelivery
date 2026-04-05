extends Node2D
## Main — wires player, world, HUD, camera, and day cycle together.

const TILE          := 16
const START_COL     := 36
const START_ROW     := 28
const TARGETS_PER_DAY := 5

@onready var world   : Node2D          = $WorldGenerator
@onready var player  : CharacterBody2D = $Player
@onready var camera  : Camera2D        = $Player/Camera2D
@onready var hud     : CanvasLayer     = $HUD
@onready var title   : CanvasLayer     = $TitleScreen

var _current_targets : Array = []

func _ready() -> void:
	# Camera limits
	camera.limit_left   = 0
	camera.limit_top    = 0
	camera.limit_right  = 80 * TILE
	camera.limit_bottom = 60 * TILE

	# Position player
	player.global_position = Vector2(START_COL * TILE, START_ROW * TILE)

	# Wire HUD
	hud.set_player(player)

	# Wire GameManager
	GameManager.all_delivered.connect(_on_all_delivered)
	GameManager.reset()

	# Show title
	title.show_title()

func start_game() -> void:
	title.hide_title()
	_begin_day()

func _begin_day() -> void:
	_current_targets = world.select_targets(TARGETS_PER_DAY)
	# Feed target list to player for throw detection
	player.delivery_targets = _current_targets
	GameManager.start_new_day(_current_targets.size()) if GameManager.day > 1  else _first_day_setup()
	GameManager.show_message(
		"☀️ Day %d! Deliver %d packages. Press F for bicycle, SPACE to toss!"
		% [GameManager.day, _current_targets.size()]
	)

func _first_day_setup() -> void:
	GameManager.total_targets  = _current_targets.size()
	GameManager.delivered_count = 0
	GameManager.set_packages(_current_targets.size())

func _on_all_delivered() -> void:
	GameManager.show_message("🎉 All delivered! Next day starting…")
	await get_tree().create_timer(2.5).timeout
	world._scatter_pickups()
	_begin_day()
