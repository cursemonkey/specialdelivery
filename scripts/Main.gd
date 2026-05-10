extends Node2D
## Main — wires player, world, HUD, camera, and day cycle together.

const TILE            := 16
const PLAYER_START    := Vector2(1100, 550)
const TARGETS_PER_DAY := 25
const DAY_DURATION    := 240.0   # 4 minutes in seconds

const BikeScene  := preload("res://scenes/Bike.tscn")
const BirdScene  := preload("res://scenes/Bird.tscn")
const BIRD_COUNT := 6

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
var _birds           : Array[Node] = []
var _first_day       := true

func _ready() -> void:
	var bg_size = $Background.texture.get_size() * $Background.scale
	camera.limit_left   = 0
	camera.limit_top    = 0
	camera.limit_right  = int(bg_size.x)
	camera.limit_bottom = int(bg_size.y)

	player.global_position = _safe_spawn_near(PLAYER_START)

	hud.set_player(player)
	hud.skip_day_pressed.connect(_on_skip_day)
	hud.continue_playing_pressed.connect(_on_continue_playing)

	GameManager.all_delivered.connect(_on_all_delivered)
	GameManager.reset()

	_remove_buildings_under_art()

	title.show_title()

func _safe_spawn_near(target: Vector2) -> Vector2:
	if not _in_building(target):
		return target
	for radius in range(TILE, 300, TILE):
		for deg in range(0, 360, 30):
			var candidate := target + Vector2(radius, 0).rotated(deg_to_rad(float(deg)))
			if not _in_building(candidate):
				return candidate
	return target

func _in_building(pos: Vector2) -> bool:
	for bldg in world.buildings:
		var r := Rect2(bldg.global_position,
				Vector2(bldg.tile_width * TILE, bldg.tile_height * TILE))
		if r.has_point(pos):
			return true
	return false

func _remove_buildings_under_art() -> void:
	var poly_node := get_node_or_null(
		"Background/StaticBody2D Buildings/CollisionPolygon2D_Building1"
	) as CollisionPolygon2D
	if poly_node == null:
		return

	# Transform polygon points into world space
	var world_poly := PackedVector2Array()
	for pt in poly_node.polygon:
		world_poly.append(poly_node.to_global(pt))

	var to_remove : Array = []
	for bldg in world.buildings:
		var bldg_poly := PackedVector2Array([
			bldg.global_position,
			bldg.global_position + Vector2(bldg.tile_width * TILE, 0),
			bldg.global_position + Vector2(bldg.tile_width * TILE, bldg.tile_height * TILE),
			bldg.global_position + Vector2(0, bldg.tile_height * TILE),
		])
		if not Geometry2D.intersect_polygons(world_poly, bldg_poly).is_empty():
			to_remove.append(bldg)

	for bldg in to_remove:
		world.buildings.erase(bldg)
		bldg.queue_free()

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
	player.reset_trail()
	_spawn_birds()

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

func _spawn_birds() -> void:
	for b in _birds:
		if is_instance_valid(b):
			b.queue_free()
	_birds.clear()

	# Build rooftop centre positions from placed buildings
	var rooftops : Array[Vector2] = []
	for bldg in world.buildings:
		rooftops.append(bldg.global_position + Vector2(bldg.tile_width * 8.0, 4.0))

	# Include art buildings
	var building1 := get_node_or_null("Building1")
	if building1 != null:
		rooftops.append(building1.global_position)

	for i in BIRD_COUNT:
		var b := BirdScene.instantiate()
		add_child(b)
		b.global_position = Vector2(
			randf_range(TILE, 6620.0),
			randf_range(TILE, 4999.0)
		)
		b.perch_positions = rooftops
		_birds.append(b)

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
