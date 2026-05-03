extends Node2D
## Main — wires player, world, HUD, camera, and day cycle together.

const TILE            := 16
const START_COL       := 36
const START_ROW       := 28
const TARGETS_PER_DAY := 5
const DAY_DURATION    := 120.0   # 6 minutes in seconds

const BikeScene := preload("res://scenes/Bike.tscn")

@onready var world  : Node2D          = $WorldGenerator
@onready var player : CharacterBody2D = $Player
@onready var camera : Camera2D        = $Player/Camera2D
@onready var hud    : CanvasLayer     = $HUD
@onready var title  : CanvasLayer     = $TitleScreen
@onready var sky    : CanvasModulate  = $CanvasModulate

var _current_targets : Array = []
var _day_timer       := 0.0
var _day_running     := false
var _bonus_paid      := false   # prevent double bonus if signal fires twice
var _world_bike      : Node2D = null
var _first_day       := true

func _ready() -> void:
	camera.limit_left   = 0
	camera.limit_top    = 0
	camera.limit_right  = 80 * TILE
	camera.limit_bottom = 60 * TILE

	player.global_position = Vector2(START_COL * TILE, START_ROW * TILE)

	hud.set_player(player)
	hud.skip_day_pressed.connect(_on_skip_day)
	hud.continue_playing_pressed.connect(_on_continue_playing)

	GameManager.all_delivered.connect(_on_all_delivered)
	GameManager.reset()

	title.show_title()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _process(delta: float) -> void:
	if not _day_running:
		return
	_day_timer += delta
	var remaining := maxf(DAY_DURATION - _day_timer, 0.0)
	hud.update_timer(remaining)
	_apply_sky_tint(_day_timer)
	if _day_timer >= DAY_DURATION:
		_day_running = false
		_on_day_time_up()

# ── Sky tint ───────────────────────────────────────────────
func _apply_sky_tint(elapsed: float) -> void:
	var sunset_start : float = DAY_DURATION * 0.5
	var night_start  : float = DAY_DURATION * 0.75
	var phase_len    : float = DAY_DURATION * 0.25
	if elapsed >= night_start:
		var t: float = clamp((elapsed - night_start) / phase_len, 0.0, 1.0)
		sky.color = Color(1.0, 0.65, 0.3).lerp(Color(0.35, 0.45, 0.85), t)
	elif elapsed >= sunset_start:
		var t: float = clamp((elapsed - sunset_start) / phase_len, 0.0, 1.0)
		sky.color = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.65, 0.3), t)
	else:
		sky.color = Color(1.0, 1.0, 1.0)

# ── Game flow ──────────────────────────────────────────────
func start_game() -> void:
	title.hide_title()
	_begin_day()

func _begin_day() -> void:
	_current_targets = world.select_targets(TARGETS_PER_DAY)
	player.delivery_targets = _current_targets
	_day_timer  = 0.0
	_day_running = true
	_bonus_paid  = false
	sky.color    = Color(1.0, 1.0, 1.0)

	if _first_day:
		_first_day = false
		_first_day_setup()
	else:
		GameManager.start_new_day(_current_targets.size())

	_spawn_bike()

	GameManager.show_message(
		"☀️ %s! Deliver %d packages. Press F for bicycle, SPACE to toss!"
		% [GameManager.day_name(), _current_targets.size()]
	)

func _spawn_bike() -> void:
	if _world_bike != null:
		_world_bike.queue_free()
	player.force_dismount()
	_world_bike = BikeScene.instantiate()
	add_child(_world_bike)
	_world_bike.global_position = player.global_position + Vector2(3 * TILE, 0)
	player.world_bike = _world_bike

func _first_day_setup() -> void:
	GameManager.total_targets   = _current_targets.size()
	GameManager.delivered_count = 0
	GameManager.day_cash        = 0
	GameManager.set_packages(_current_targets.size())

# ── Delivery complete (early) ──────────────────────────────
func _on_all_delivered() -> void:
	if not _day_running or _bonus_paid:
		return
	_bonus_paid = true
	var bonus := int(GameManager.day_cash * 0.25)
	GameManager.add_cash(bonus)
	hud.show_day_complete_prompt(bonus)

# ── Prompt responses ───────────────────────────────────────
func _on_skip_day() -> void:
	_day_running = false
	hud.hide_day_complete_prompt()
	hud.update_timer(0.0)
	await get_tree().create_timer(0.3).timeout
	world._scatter_pickups()
	_begin_day()

func _on_continue_playing() -> void:
	hud.hide_day_complete_prompt()
	GameManager.show_message("🌇 Keep exploring! Next day starts when time runs out.")

# ── Timer expired ──────────────────────────────────────────
func _on_day_time_up() -> void:
	hud.hide_day_complete_prompt()
	hud.update_timer(0.0)
	GameManager.show_message("⏰ %s is over! Starting next day…" % GameManager.day_name())
	await get_tree().create_timer(2.5).timeout
	world._scatter_pickups()
	_begin_day()
