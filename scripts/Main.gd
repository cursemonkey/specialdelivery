extends Node2D
## Main — wires player, world, HUD, camera, and day cycle together.

const TILE             := 16
const PLAYER_START     := Vector2(1819, 1635)  # south of House5
const TARGETS_PER_DAY  := 12
const DAY_DURATION     := 240.0   # 4 minutes in seconds
const START_PACKAGES   := 0

const BikeScene        := preload("res://scenes/Bike.tscn")
const BirdScene        := preload("res://scenes/Bird.tscn")
const NPCManagerScript := preload("res://scripts/NPCManager.gd")
const BIRD_COUNT       := 6

@onready var world          : Node2D          = $WorldGenerator
@onready var player         : CharacterBody2D = $Player
@onready var camera         : Camera2D        = $Player/Camera2D
@onready var hud            : CanvasLayer     = $HUD
@onready var title          : CanvasLayer     = $TitleScreen
@onready var sky            : CanvasModulate  = $CanvasModulate
@onready var drop_pads      : StaticBody2D    = $Background/DropPads
@onready var home_selection : CanvasLayer     = $HomeSelectionLayer

var _current_targets  : Array  = []
var _day_timer        : float  = 0.0
var _day_running      : bool   = false
var _bonus_paid       : bool   = false
var _world_bike       : Node2D = null
var _birds            : Array[Node] = []
var _first_day        : bool   = true
var _continue_flow    : bool   = false   # loading a save: start drops now, don't advance the day
var _home_door_node   : Node2D = null
var _npc_manager      : Node2D = null

func _ready() -> void:
	var bg_size = $Background.texture.get_size() * $Background.scale
	camera.limit_left   = 0
	camera.limit_top    = 0
	camera.limit_right  = int(bg_size.x)
	camera.limit_bottom = int(bg_size.y)

	player.global_position = _safe_spawn_near(PLAYER_START)
	player.pause_menu = get_node_or_null("PauseMenuLayer/PauseMenuScreen")
	player.dialogue_box = get_node_or_null("DialogueBox")
	player.doors = get_tree().get_nodes_in_group("art_building")
	player.roads_region     = get_node_or_null("Background/Road")
	player.dirt_road_region = get_node_or_null("Background/DirtRoad")
	player.drop_pad_manager = drop_pads

	drop_pads.player_ref = player
	drop_pads.drop_arrived.connect(_on_drop_arrived)
	drop_pads.pad_picked_up.connect(_on_pad_picked_up)

	home_selection.home_selected.connect(_on_home_selected)
	home_selection.dialogue_box_ref = get_node_or_null("DialogueBox")
	home_selection.background_ref   = $Background
	var _door_positions : Dictionary = {}
	for _id in ["Townhouse3", "Apartments", "House28", "House10"]:
		var _door : Node2D = get_node_or_null("Doors/" + _id)
		if _door != null:
			_door_positions[_id] = _door.global_position
	home_selection.home_doors = _door_positions
	player.home_door_activated.connect(_on_home_door_activated)

	var pause_screen := get_node_or_null("PauseMenuLayer/PauseMenuScreen")
	if pause_screen != null:
		pause_screen.player_ref       = player
		pause_screen.background_ref   = $Background
		pause_screen.drop_pad_manager = drop_pads
		pause_screen.next_day_requested.connect(_on_next_day)

	hud.set_player(player)
	hud.skip_day_pressed.connect(_on_skip_day)
	hud.continue_playing_pressed.connect(_on_continue_playing)

	GameManager.all_delivered.connect(_on_all_delivered)
	GameManager.reset()
	GameManager.load_settings()
	_apply_settings()

	_remove_buildings_under_art()

	_npc_manager = NPCManagerScript.new()
	_npc_manager.name = "NPCManager"
	add_child(_npc_manager)
	_npc_manager.setup(player, get_node_or_null("Doors"))
	_npc_manager.spawn_all()

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

func _find_safe_position(target: Vector2) -> Vector2:
	var space_state : PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = 1
	query.position = target
	if space_state.intersect_point(query).is_empty():
		return target
	for radius in range(TILE, 300, TILE):
		for deg in range(0, 360, 30):
			var candidate : Vector2 = target + Vector2(radius, 0).rotated(deg_to_rad(float(deg)))
			query.position = candidate
			if space_state.intersect_point(query).is_empty():
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

func _process(delta: float) -> void:
	if not _day_running:
		return
	_day_timer += delta
	var remaining := maxf(DAY_DURATION - _day_timer, 0.0)
	hud.update_timer(remaining)
	_apply_sky_tint(_day_timer)
	TimeManager.set_day_progress(_day_timer / DAY_DURATION)
	drop_pads.tick(delta)
	if _day_timer >= DAY_DURATION:
		_day_running = false
		drop_pads.end_day()
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
	home_selection.show_selection()

func continue_game() -> void:
	title.hide_title()
	GameManager.load_game()
	_apply_settings()
	_resolve_home_door()
	hud.update_mortgage(GameManager.mortgage)
	# A loaded game already has a home, so the new-game home-selection flow
	# (which normally kicks off drops) never runs — flag this so _begin_day
	# schedules drops for the resumed day without advancing to a new one.
	_first_day     = false
	_continue_flow = true
	_begin_day()

func _apply_settings() -> void:
	player.snap_to_direction        = GameManager.snap_to_direction
	drop_pads.max_drops_per_day     = GameManager.max_drops_per_day
	drop_pads.max_packages_per_drop = GameManager.max_packages_per_drop

func _resolve_home_door() -> void:
	if GameManager.home_id.is_empty():
		return
	_home_door_node = get_node_or_null("Doors/" + GameManager.home_id)
	if _home_door_node != null:
		player.home_door_node = _home_door_node

func _begin_day() -> void:
	world.clear_targets()
	_current_targets        = []
	player.delivery_targets = []
	_day_timer   = 0.0
	_day_running = true
	_bonus_paid  = false
	sky.color    = Color(1.0, 1.0, 1.0)

	if _home_door_node != null:
		player.global_position = _home_door_node.global_position + Vector2(0, 10)
	else:
		player.global_position = _safe_spawn_near(PLAYER_START)

	if _first_day:
		_first_day = false
		_first_day_setup()
		# drop_pads.start_day() is called by _on_home_selected after selection
	elif _continue_flow:
		_continue_flow = false
		drop_pads.start_day(DAY_DURATION)   # resume the loaded day; don't advance
	else:
		GameManager.start_new_day(0)
		GameManager.save_game()
		drop_pads.start_day(DAY_DURATION)

	TimeManager.start_day(GameManager.day)
	_spawn_bike()
	player.reset_trail()
	_spawn_birds()

	GameManager.show_message(
		"☀️ %s! Watch for supply drops — pick them up to get deliveries!" \
		% GameManager.day_name()
	)

func _spawn_bike() -> void:
	if _world_bike != null:
		_world_bike.queue_free()
	player.force_dismount()
	_world_bike = BikeScene.instantiate()
	add_child(_world_bike)
	_world_bike.global_position = _find_safe_position(player.global_position + Vector2(0, 20))
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
	var building1 := get_node_or_null("Doors/Building1")
	var pub := get_node_or_null("Doors/Pub")
	if building1 != null:
		rooftops.append(building1.global_position)
	if pub != null:
		rooftops.append(pub.global_position)

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
	GameManager.total_targets   = 0
	GameManager.delivered_count = 0
	GameManager.day_cash        = 0
	GameManager.set_packages(0)

# ── Delivery complete (early) ──────────────────────────────
func _on_all_delivered() -> void:
	if not _day_running or _bonus_paid:
		return
	_bonus_paid = true
	var bonus := int(GameManager.day_cash * 0.25)
	GameManager.add_cash(bonus)
	GameManager.show_message("🎉 All delivered! +$%d bonus! Open menu for Next Day." % bonus, 5.0)

# ── Prompt responses ───────────────────────────────────────
func _on_home_selected(home_id: String, price: int) -> void:
	GameManager.home_id     = home_id
	GameManager.mortgage    = price
	_resolve_home_door()
	hud.update_mortgage(price)
	drop_pads.start_day(DAY_DURATION)
	GameManager.show_message("🏠 Welcome home! Your mortgage: -$%d" % price)

func _on_home_door_activated() -> void:
	if not _day_running:
		return
	_day_running = false
	drop_pads.end_day()
	GameManager.show_message("🏠 Heading home for the night...")
	await get_tree().create_timer(1.5).timeout
	world._scatter_pickups()
	_begin_day()

func _on_next_day() -> void:
	_day_running = false
	drop_pads.end_day()
	hud.update_timer(0.0)
	await get_tree().create_timer(0.3).timeout
	world._scatter_pickups()
	_begin_day()

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

# ── Drop pad events ───────────────────────────────────────
func _on_drop_arrived(pad_idx: int, count: int) -> void:
	GameManager.show_message(
		"📦 Supply drop at Pad %d! %d package%s waiting — go pick it up!" \
		% [pad_idx + 1, count, "s" if count > 1 else ""],
		5.0
	)

func _on_pad_picked_up(_pad_idx: int, count: int) -> void:
	var new_targets : Array = world.select_extra_targets(count)
	for t in new_targets:
		player.delivery_targets.append(t)
	GameManager.add_packages(new_targets.size())
	GameManager.add_targets(new_targets.size())
	GameManager.show_message(
		"📬 Picked up %d package%s! New deliveries added." \
		% [new_targets.size(), "s" if new_targets.size() > 1 else ""]
	)

# ── Timer expired ──────────────────────────────────────────
func _on_day_time_up() -> void:
	hud.hide_day_complete_prompt()
	hud.update_timer(0.0)
	GameManager.show_message("⏰ %s is over! Starting next day…" % GameManager.day_name())
	await get_tree().create_timer(2.5).timeout
	world._scatter_pickups()
	_begin_day()
