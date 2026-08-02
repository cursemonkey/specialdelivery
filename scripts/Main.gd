extends Node2D
## Main — wires player, world, HUD, camera, and day cycle together.

const TILE             := 16
const PLAYER_START     := Vector2(1819, 1635)  # south of House5
const TARGETS_PER_DAY  := 12
const DAY_DURATION     := 240.0   # 4 minutes in seconds
const START_PACKAGES   := 0

const BikeScene             := preload("res://scenes/Bike.tscn")
const BirdScene             := preload("res://scenes/Bird.tscn")
const NPCManagerScript       := preload("res://scripts/NPCManager.gd")
const InteriorManagerScript  := preload("res://scripts/InteriorManager.gd")
const RoadblockManagerScript := preload("res://scripts/RoadblockManager.gd")
const DayTransitionScene     := preload("res://scenes/DayTransition.tscn")
const LedgerScreenScene      := preload("res://scenes/LedgerScreen.tscn")
const BIRD_COUNT             := 6

@onready var world          : Node2D          = $WorldGenerator
@onready var player         : CharacterBody2D = $Player
@onready var camera         : Camera2D        = $Player/Camera2D
@onready var hud            : CanvasLayer     = $HUD
@onready var title          : CanvasLayer     = $TitleScreen
@onready var sky            : CanvasModulate  = $CanvasModulate
@onready var drop_pads      : StaticBody2D    = $Background/DropPads
@onready var home_selection : CanvasLayer     = $HomeSelectionLayer
@onready var save_slot_panel : CanvasLayer    = $SaveSlotPanel

var _current_targets  : Array  = []
var _day_timer        : float  = 0.0
var _day_running      : bool   = false
var _bonus_paid       : bool   = false
var _world_bike       : Node2D = null
var _birds            : Array[Node] = []
var _first_day        : bool   = true
var _continue_flow    : bool   = false   # loading a save: start drops now, don't advance the day
var _home_door_node   : Node2D = null
var _npc_manager       : Node2D = null
var _interior_manager  : Node2D = null
var _roadblock_manager : Node2D = null
var _day_transition    : CanvasLayer = null
var _ledger_screen     : CanvasLayer = null
var _day_ending        : bool = false

var _energy_accum : float = 0.0   # fractional energy drained this second
var _rizz_accum   : float = 0.0   # fractional rizz gained from following birds

const DOCTOR_LETTER : Array = [
	"A letter from the town doctor:",
	"\"You pushed yourself too hard out there and collapsed. I've had you brought home to rest. Please take better care of yourself — mind those crashes!\"",
]

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
	var _road_nodes       : Array[NavigationRegion2D] = []
	var _dirt_road_nodes  : Array[NavigationRegion2D] = []
	var _grass_nodes      : Array[NavigationRegion2D] = []
	for _n in get_tree().get_nodes_in_group("road_zone"):
		_road_nodes.append(_n)
	for _n in get_tree().get_nodes_in_group("dirt_road_zone"):
		_dirt_road_nodes.append(_n)
	for _n in get_tree().get_nodes_in_group("grass_zone"):
		_grass_nodes.append(_n)
	player.road_regions      = _road_nodes
	player.dirt_road_regions = _dirt_road_nodes
	player.grass_regions     = _grass_nodes
	player.drop_pad_manager = drop_pads

	drop_pads.player_ref = player
	drop_pads.drop_arrived.connect(_on_drop_arrived)
	drop_pads.pad_picked_up.connect(_on_pad_picked_up)

	home_selection.home_selected.connect(_on_home_selected)
	home_selection.dialogue_box_ref = get_node_or_null("DialogueBox")
	home_selection.background_ref   = $Background
	var _door_positions : Dictionary = {}
	for _id in ["Townhouse15", "Apartments", "House84", "House10"]:
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
		pause_screen.save_slot_panel  = save_slot_panel
		pause_screen.next_day_requested.connect(_on_next_day)

	title.save_slot_panel = save_slot_panel

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

	_interior_manager = InteriorManagerScript.new()
	_interior_manager.name = "InteriorManager"
	add_child(_interior_manager)
	var doors_node := get_node_or_null("Doors")
	var door_markers : Array = doors_node.get_children() if doors_node != null else []
	_interior_manager.setup(player, camera, door_markers)
	_interior_manager.sleep_requested.connect(_on_home_door_activated)
	player.interior_manager = _interior_manager

	_roadblock_manager = RoadblockManagerScript.new()
	_roadblock_manager.name = "RoadblockManager"
	add_child(_roadblock_manager)
	_roadblock_manager.setup()

	_ledger_screen = LedgerScreenScene.instantiate()
	add_child(_ledger_screen)

	GameManager.out_of_health.connect(_on_collapsed)

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
	GameManager.play_clock += delta
	_day_timer += delta
	var remaining := maxf(DAY_DURATION - _day_timer, 0.0)
	hud.update_timer(remaining)
	_apply_sky_tint(_day_timer)
	TimeManager.set_day_progress(_day_timer / DAY_DURATION)
	drop_pads.tick(delta)
	_tick_stats(delta)
	if _day_timer >= DAY_DURATION:
		_day_running = false
		drop_pads.end_day()
		_on_day_time_up()

# Energy drains while moving (bike 1/min, foot 2/min); Rizz gains 1/min per
# bird that's currently following the player.
func _tick_stats(delta: float) -> void:
	if player.velocity.length() > 5.0:
		var rate : float = (2.0 if player.on_bike else 3.0) / 60.0   # bike 2/min, walking 3/min
		_energy_accum += rate * delta
		while _energy_accum >= 1.0:
			_energy_accum -= 1.0
			GameManager.add_energy(-1)

	var following : int = 0
	for b in _birds:
		if is_instance_valid(b) and b.is_following():
			following += 1
	if following > 0:
		_rizz_accum += (float(following) / 60.0) * delta
		while _rizz_accum >= 1.0:
			_rizz_accum -= 1.0
			GameManager.add_rizz(1)

# Out of health: end the day, deliver the doctor's letter, wake at home.
func _on_collapsed() -> void:
	if not _day_running:
		return
	_day_running = false
	drop_pads.end_day()
	player.input_locked = true
	# Doctor's letter first, then the day-end ledger, then wake at home.
	var dbox := get_node_or_null("DialogueBox")
	if dbox != null:
		dbox.open(DOCTOR_LETTER, func() -> void: _end_day(_next_day))
	else:
		_end_day(_next_day)

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
func start_game(slot: int) -> void:
	title.hide_title()
	GameManager.reset()
	GameManager.current_slot = slot
	_begin_day()
	home_selection.show_selection()

func continue_game(slot: int) -> void:
	title.hide_title()
	GameManager.load_game(slot)
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
	# If a day change happens while the player is inside a building (e.g. time
	# ran out, or they slept), pull them back outside first so control, camera,
	# and in_interior state are restored before the new day is set up.
	if _interior_manager != null and _interior_manager.is_inside():
		_interior_manager.exit()

	GameManager.reset_day_stats()   # full HP & energy, zero rizz for the new day
	_energy_accum = 0.0
	_rizz_accum   = 0.0

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

	if _roadblock_manager != null:
		_roadblock_manager.spawn_for_day(player.global_position)

	GameManager.show_message(
		"☀️ %s! Watch for supply drops — pick them up to get deliveries!" \
		% GameManager.date_label()
	)

	# Each day starts inside the player's home; they walk out to begin. (The
	# bike was just parked at the home door above, so it's waiting outside.)
	if _interior_manager != null and not GameManager.home_id.is_empty() and _home_door_node != null:
		_interior_manager.enter(GameManager.home_id)

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

# ── End of day ─────────────────────────────────────────────
# All day-end triggers funnel here: freeze the day, show the ledger, and on
# Continue apply the undelivered dock and run the continuation (start next day).
func _end_day(after: Callable) -> void:
	if _day_ending:
		return
	_day_ending  = true
	_day_running = false
	drop_pads.end_day()
	hud.update_timer(0.0)
	player.input_locked = true

	var undelivered : int  = GameManager.packages   # all packages come from pads
	var rizz_saved  : bool = GameManager.rizz_over_half()
	var dock        : int  = 0 if rizz_saved else undelivered * 5

	_ledger_screen.present(GameManager.get_ledger(), undelivered, dock, rizz_saved,
		func() -> void:
			if dock > 0:
				GameManager.add_cash(-dock)
			player.input_locked = false
			_day_ending = false
			after.call()
	)

func _next_day() -> void:
	world._scatter_pickups()
	_begin_day()

func _on_home_door_activated() -> void:
	if not _day_running:
		return
	_end_day(_next_day)

func _on_next_day() -> void:
	_end_day(_next_day)

func _on_skip_day() -> void:
	hud.hide_day_complete_prompt()
	_end_day(_next_day)

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

func _on_pad_picked_up(_pad_idx: int, count: int, landing_times: Array) -> void:
	var new_targets : Array = world.select_extra_targets(count)
	for i in new_targets.size():
		var t : Object = new_targets[i]
		# Start each package's delivery clock at the time its drop landed.
		t.package_landing_time = landing_times[i] if i < landing_times.size() \
				else GameManager.play_clock
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
	GameManager.show_message("⏰ %s is over!" % GameManager.date_label())
	_end_day(_next_day)
