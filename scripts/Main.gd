extends Node2D
## Main — wires player, world, HUD, camera, and day cycle together.

const TILE             := 16
const PLAYER_START     := Vector2(1819, 1635)  # south of House5
const TARGETS_PER_DAY  := 12
const DAY_DURATION     := 720.0   # 12 real minutes = 24 in-game hours (2 hrs/min)
const START_PACKAGES   := 0

const BikeScene             := preload("res://scenes/Bike.tscn")
const BirdScene             := preload("res://scenes/Bird.tscn")
const NPCManagerScript       := preload("res://scripts/NPCManager.gd")
const DogManagerScript       := preload("res://scripts/DogManager.gd")
const InteriorManagerScript  := preload("res://scripts/InteriorManager.gd")
const PoliceManagerScript    := preload("res://scripts/PoliceManager.gd")
const DayTransitionScene     := preload("res://scenes/DayTransition.tscn")
const LedgerScreenScene      := preload("res://scenes/LedgerScreen.tscn")
const CutsceneScene          := preload("res://scenes/Cutscene.tscn")
const SleepPromptScript      := preload("res://scripts/SleepPrompt.gd")
const ShopPanelScript        := preload("res://scripts/ShopPanel.gd")
const MortgagePanelScript    := preload("res://scripts/MortgagePanel.gd")
const ChoicePanelScript      := preload("res://scripts/ChoicePanel.gd")
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
var _dog_manager       : Node2D = null
var _interior_manager  : Node2D = null
var _police_manager    : Node2D = null
var _day_transition    : CanvasLayer = null
var _ledger_screen     : CanvasLayer = null
var _sleep_prompt      : CanvasLayer = null
var _shop_panel        : CanvasLayer = null
var _mortgage_panel    : CanvasLayer = null
var _choice_panel      : CanvasLayer = null
var _choice_npc        : RegularNPC  = null
var _pending_sleep_hours : int = TimeManager.SLEEP_MAX_HOURS   # length of the sleep in progress
var _cutscene          : CanvasLayer = null
var _day_ending        : bool = false

var _energy_accum : float = 0.0   # fractional energy drained this second
var _rizz_accum   : float = 0.0   # fractional rizz gained from following birds

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

	# NPC pathfinding prefers roads: travel_cost multiplies a region's crossing
	# cost, so pathfinding routes along roads/dirt roads and only cuts across
	# grass when that's genuinely shorter.
	for r in _road_nodes:
		r.travel_cost = 1.0
	for r in _dirt_road_nodes:
		r.travel_cost = 1.5
	for r in _grass_nodes:
		r.travel_cost = 6.0
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

	# The town's dogs. Like villagers they're data-driven (see DogRegistry) and
	# keep to a territory around their owner's door.
	_dog_manager = DogManagerScript.new()
	_dog_manager.name = "DogManager"
	add_child(_dog_manager)
	_dog_manager.setup(get_node_or_null("Doors"))
	_dog_manager.spawn_all()

	_interior_manager = InteriorManagerScript.new()
	_interior_manager.name = "InteriorManager"
	add_child(_interior_manager)
	var doors_node := get_node_or_null("Doors")
	var door_markers : Array = doors_node.get_children() if doors_node != null else []
	_interior_manager.setup(player, camera, door_markers)
	_interior_manager.sleep_requested.connect(_on_home_door_activated)
	_interior_manager.entered_building.connect(_on_entered_building)
	player.interior_manager = _interior_manager

	_police_manager = PoliceManagerScript.new()
	_police_manager.name = "PoliceManager"
	add_child(_police_manager)
	_police_manager.setup()

	_ledger_screen = LedgerScreenScene.instantiate()
	add_child(_ledger_screen)

	_sleep_prompt = SleepPromptScript.new()
	_sleep_prompt.name = "SleepPrompt"
	add_child(_sleep_prompt)
	_sleep_prompt.chosen.connect(_on_sleep_hours_chosen)

	_shop_panel = ShopPanelScript.new()
	_shop_panel.name = "ShopPanel"
	add_child(_shop_panel)
	player.shop_panel = _shop_panel

	_mortgage_panel = MortgagePanelScript.new()
	_mortgage_panel.name = "MortgagePanel"
	add_child(_mortgage_panel)
	player.mortgage_panel = _mortgage_panel

	_choice_panel = ChoicePanelScript.new()
	_choice_panel.name = "ChoicePanel"
	add_child(_choice_panel)
	_choice_panel.chosen.connect(_on_choice_made)
	player.choice_panel = _choice_panel

	_cutscene = CutsceneScene.instantiate()
	add_child(_cutscene)

	GameManager.out_of_health.connect(_on_collapsed)
	TimeManager.midnight_passed.connect(_on_midnight)

	title.show_title()

## Dialogue choices come back here; the Player owns what each one means.
func _on_choice_made(id: String) -> void:
	var npc : RegularNPC = null
	for n in get_tree().get_nodes_in_group("regular_npc"):
		if n.id == player.BANKER_ID:
			npc = n
			break
	player.on_banker_choice(id, npc)

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
	TimeManager.advance(delta)
	hud.update_timer(TimeManager.hour)
	# Indoors, ignore the sunset/night colour filter (keep interiors neutral).
	if player.in_interior:
		sky.color = Color(1.0, 1.0, 1.0)
	else:
		_apply_sky_tint(TimeManager.daylight())
	drop_pads.tick(delta)
	_tick_stats(delta)

# Midnight: show the ledger for the day just finished, then keep playing
# through the small hours until the player goes to bed.
func _on_midnight() -> void:
	if not _day_running or _day_ending:
		return
	# Close out the day that just finished BEFORE rolling the counter, so its
	# ledger is recorded against the day that actually earned it.
	_end_day(func() -> void:
		GameManager.day += 1           # the calendar day rolls at midnight
		GameManager.day_changed.emit(GameManager.day)
		TimeManager.advance_calendar_day(GameManager.day)
		_resume_after_midnight()
	)

# After the midnight ledger the same session continues — no respawn, no reset of
# the clock; the player carries on until they choose to sleep.
func _resume_after_midnight() -> void:
	GameManager.reset_day_stats()
	_energy_accum = 0.0
	_rizz_accum   = 0.0
	world.clear_targets()
	player.delivery_targets = []
	drop_pads.start_day(DAY_DURATION)
	_day_running = true
	GameManager.show_message("🌙 A new day begins — %s." % GameManager.date_label())

# Going indoors scatters any birds and dogs trailing the player — they wait
# outside, and
# the Rizz bonus they were providing stops with them.
func _on_entered_building() -> void:
	var scattered : int = 0
	for b in _birds:
		if is_instance_valid(b) and b.is_following():
			b.stop_following()
			scattered += 1
	var dogs_left : int = 0
	if _dog_manager != null:
		dogs_left = _dog_manager.scatter_following()
	if scattered > 0 or dogs_left > 0:
		_rizz_accum = 0.0
		var parts : Array = []
		if scattered > 0:
			parts.append("bird%s" % ("s" if scattered > 1 else ""))
		if dogs_left > 0:
			parts.append("dog%s" % ("s" if dogs_left > 1 else ""))
		GameManager.show_message("🐕 Your %s waited outside." % " and ".join(parts))

# Energy drains while moving, priced in game hours (bike 1.5/hr, walking 2/hr);
# Rizz gains 1 per game hour per bird or dog currently following the player.
func _tick_stats(delta: float) -> void:
	var game_hours : float = delta * TimeManager.HOURS_PER_SECOND
	if player.velocity.length() > 5.0:
		var rate : float = 1.5 if player.on_bike else 2.0   # per game hour
		_energy_accum += rate * game_hours
		while _energy_accum >= 1.0:
			_energy_accum -= 1.0
			GameManager.add_energy(-1)

	var following : int = 0
	for b in _birds:
		if is_instance_valid(b) and b.is_following():
			following += 1
	# Dogs in the parade count towards the same Rizz bonus as the birds.
	if _dog_manager != null:
		following += _dog_manager.following_count()
	_assign_parade_slots()
	if following > 0:
		_rizz_accum += float(following) * game_hours
		while _rizz_accum >= 1.0:
			_rizz_accum -= 1.0
			GameManager.add_rizz(1)

## Number the parade from the player backwards so birds and dogs form one
## shared queue. Birds take the front slots (they flew in first and cut
## corners anyway), then dogs in the order they joined.
func _assign_parade_slots() -> void:
	var slot : int = 0
	for b in _birds:
		# `get` guards against an out-of-date Bird.gd that predates parade_slot:
		# ordering the line is cosmetic, so skip rather than crash the frame.
		if is_instance_valid(b) and b.is_following() and b.get("parade_slot") != null:
			b.parade_slot = slot
			slot += 1
	if _dog_manager != null:
		_dog_manager.assign_parade_slots(slot)

# Out of health: play the collapse cutscene, show the day's ledger, then wake
# up in your own bed at 6am having lost a day.
func _on_collapsed() -> void:
	if not _day_running or _day_ending:
		return
	_day_running = false
	drop_pads.end_day()
	player.input_locked = true
	# Whichever Carrington is more plausible as your carer: the doctor by day,
	# her mother the nurse otherwise.
	var carer : String = "doctor_carrington" if TimeManager.hour < 18.0 else "elsie_carrington"
	var carer_def : NPCDefinition = NPCRegistry.get_definition(carer)
	var carer_name : String = carer_def.display_name if carer_def != null else "The doctor"
	_cutscene.play("Your bedroom — later that day", [
		{"text": "Everything goes grey at the edges. The pavement comes up to meet you..."},
		{"speaker": carer, "mood": "calm",
		 "text": "Easy now. You collapsed out on your route — we brought you home."},
		{"speaker": carer, "mood": "mad",
		 "text": "You pushed yourself far too hard. I've written you off for the rest of the day."},
		{"speaker": carer, "mood": "calm",
		 "text": "Rest up. Your deliveries can wait until tomorrow — doctor's orders."},
		{"text": "%s sees themselves out. You've lost a day." % carer_name},
	], _after_collapse_cutscene)

func _after_collapse_cutscene() -> void:
	# Ledger for the day that just ended, then wake at 6am tomorrow, in bed.
	_end_day(_wake_after_collapse)

func _wake_after_collapse() -> void:
	GameManager.day += 1
	GameManager.day_changed.emit(GameManager.day)
	world._scatter_pickups()
	_begin_day(TimeManager.DAY_START_HOUR)   # 6am, spawns inside the player's home
	GameManager.show_message("☀️ You wake at %s, a day behind — %s." \
			% [TimeManager.clock_label(), GameManager.date_label()])

# ── Sky tint ───────────────────────────────────────────────
## Driven by TimeManager.daylight(): 0 = full night, 1 = full daylight. The
## golden hour sits in the middle of each transition (dawn 6–8am, dusk 7–9pm).
const NIGHT_TINT  : Color = Color(0.35, 0.45, 0.85)
const GOLDEN_TINT : Color = Color(1.0, 0.65, 0.3)
const DAY_TINT    : Color = Color(1.0, 1.0, 1.0)

func _apply_sky_tint(light: float) -> void:
	if light >= 0.5:
		sky.color = GOLDEN_TINT.lerp(DAY_TINT, (light - 0.5) / 0.5)
	else:
		sky.color = NIGHT_TINT.lerp(GOLDEN_TINT, light / 0.5)

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
	# Resume at the saved time of day (packages/HP/energy/rizz still reset to
	# their defaults inside _begin_day), starting inside the player's home.
	_begin_day(GameManager.loaded_hour)

func _apply_settings() -> void:
	player.snap_to_direction        = GameManager.snap_to_direction
	drop_pads.max_drops_per_day     = GameManager.max_drops_per_day
	drop_pads.max_packages_per_drop = GameManager.max_packages_per_drop

func _resolve_home_door() -> void:
	if GameManager.home_id.is_empty():
		return
	_home_door_node = get_node_or_null("Doors/" + GameManager.home_id)
	if _home_door_node == null:
		push_warning("Home door '%s' not found under Doors/ — no bed or map icon." \
				% GameManager.home_id)
		return
	player.home_door_node = _home_door_node
	# Let the pause-menu map show a 🏠 icon at the player's home.
	var pause_screen := get_node_or_null("PauseMenuLayer/PauseMenuScreen")
	if pause_screen != null:
		pause_screen.home_position = _home_door_node.global_position
		pause_screen.has_home      = true

func _begin_day(at_hour: float = TimeManager.DAY_START_HOUR) -> void:
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
		# Resume the loaded day without advancing it. The day's takings
		# (ledger, day_cash, delivered_count) were restored by load_game and
		# are deliberately kept, so tonight's midnight ledger still reports the
		# whole calendar day rather than only what happened after loading.
		# Only the in-flight packages are dropped: their delivery targets no
		# longer exist in the reloaded world, so they could never be completed.
		GameManager.total_targets = GameManager.delivered_count
		GameManager.set_packages(0)
		drop_pads.start_day(DAY_DURATION)
	else:
		# The day counter is advanced by whoever ended the day (sleep / midnight),
		# so only reset the per-day bookkeeping here.
		GameManager.day_cash        = 0
		GameManager.delivered_count = 0
		GameManager.total_targets   = 0
		GameManager.set_packages(0)
		GameManager.save_game()
		drop_pads.start_day(DAY_DURATION)

	TimeManager.start_day(GameManager.day, at_hour)
	# Match the sky to the resumed time rather than assuming full daylight.
	_apply_sky_tint(TimeManager.daylight())
	_spawn_bike()
	player.reset_trail()
	_spawn_birds()

	if _police_manager != null:
		_police_manager.plan_for_day(player.global_position)

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
	player.input_locked = true

	var undelivered : int  = GameManager.packages   # all packages come from pads
	var rizz_saved  : bool = GameManager.rizz_over_half()
	var dock        : int  = 0 if rizz_saved else undelivered * 5

	# Fold this calendar day into the lifetime records before the ledger is
	# cleared for the next one.
	var entries : Array = GameManager.get_ledger()
	var gross   : int   = 0
	var tips    : int   = 0
	for e in entries:
		gross += int(e.value) + int(e.tip)
		tips  += int(e.tip)
	GameManager.record_day_stats(GameManager.day, gross - dock, tips, entries.size())

	_ledger_screen.present(entries, undelivered, dock, rizz_saved,
		func() -> void:
			if dock > 0:
				GameManager.add_cash(-dock)
			# The calendar day is over: start the next one with a clean ledger.
			GameManager.clear_ledger()
			player.input_locked = false
			_day_ending = false
			after.call()
	)

func _next_day() -> void:
	world._scatter_pickups()
	_begin_day()

## Sleeping: ask how long (1–8 hours), then rest that long. Recovery is 12.5%
## of HP and energy per hour, so 8 hours is a full restore and 1 hour is a
## top-up. The ledger spans the calendar day, so it only closes out when the
## chosen sleep actually carries the clock past midnight.
func _on_home_door_activated() -> void:
	if not _day_running:
		return
	_sleep_prompt.open()

func _on_sleep_hours_chosen(hours: int) -> void:
	_pending_sleep_hours = hours
	if TimeManager.sleep_crosses_midnight(float(hours)):
		_end_day(_sleep_into_new_day)
	else:
		# Same-day rest: time passes and the player recovers, but the day's
		# ledger keeps accruing so the morning's work stays on it.
		_apply_sleep(hours)
		# Bed is a save point, however short the rest — a nap that isn't saved
		# is a session the player can lose.
		GameManager.save_game()
		GameManager.show_message("😴 You slept %d hour%s until %s. (Saved)" \
				% [hours, "" if hours == 1 else "s", TimeManager.clock_label()])

## Advance the clock and restore the fraction of HP/energy the rest earned.
## Street features redistribute on every sleep.
func _apply_sleep(hours: int) -> void:
	TimeManager.skip_hours(float(hours))
	GameManager.recover_by_fraction(float(hours) * TimeManager.SLEEP_RECOVERY_PER_HR)
	world._scatter_pickups()

func _sleep_into_new_day() -> void:
	var hours : int = _pending_sleep_hours
	# Carry the pre-sleep HP/energy across the day boundary: a short night should
	# top the player up from where they were, not reset them to a full bar.
	var hp_before : int = GameManager.hp
	var en_before : int = GameManager.energy
	GameManager.day += 1
	GameManager.day_changed.emit(GameManager.day)
	var wake : float = TimeManager.wake_hour(float(hours))
	world._scatter_pickups()
	_begin_day(wake)
	# _begin_day restores full HP/energy for the new day, which is only correct
	# for a full night. For anything shorter, restore what the player actually
	# had and then add the fraction those hours earned.
	var frac : float = clampf(float(hours) * TimeManager.SLEEP_RECOVERY_PER_HR, 0.0, 1.0)
	if frac < 1.0:
		GameManager.hp     = hp_before
		GameManager.energy = en_before
		GameManager.recover_by_fraction(frac)
	GameManager.show_message("☀️ You wake at %s — %s." % [TimeManager.clock_label(), GameManager.date_label()])

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
	var msg : String = "📬 Picked up %d package%s! New deliveries added." \
			% [new_targets.size(), "s" if new_targets.size() > 1 else ""]
	# The pad only hands over what the rack can hold; say so if it is now full.
	if GameManager.package_space() <= 0:
		msg += "  Bike is full (%d/%d)." % [GameManager.packages, GameManager.bike_max_packages]
	GameManager.show_message(msg)

# The day no longer ends on a timer — it ends when the player sleeps, collapses
# (0 HP), or the midnight ledger rolls the calendar over.
