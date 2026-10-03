extends Node2D
## Handles entering and leaving building interiors. Created by Main. The
## exterior world stays alive and simulating (time keeps running) — it's just
## off-camera while a generic Interior instance is staged far from the map and
## the player + camera are moved into it.

signal sleep_requested
signal entered_building
## E at a home workbench. Main opens the crafting panel.
signal craft_requested

const InteriorScene : PackedScene = preload("res://scenes/Interior.tscn")
const ChoicePanelScript : GDScript = preload("res://scripts/ChoicePanel.gd")
const STAGE_ORIGIN  : Vector2     = Vector2(100000, 100000)   # far from the world map
const ENTER_RANGE   : float       = 84.0

var _player  : CharacterBody2D = null
var _camera  : Camera2D        = null
var _markers : Array           = []   # door-marker Node2Ds (name = building id)

var _active  : Node    = null
var _return  : Vector2 = Vector2.ZERO
var _saved   : Rect2   = Rect2()
var _inside_npcs : Array = []   # NPCs materialized inside the active interior
var _inside_pets : Array = []   # dogs and cats shown at home inside the active interior

## Villagers shown indoors don't stand frozen: every SHUFFLE_MIN–MAX game
## minutes each one strolls to a new spot within SHUFFLE_RADIUS of where the
## room placed them (never while the player is chatting to them).
const SHUFFLE_MIN_MINUTES : float = 20.0
const SHUFFLE_MAX_MINUTES : float = 40.0
const SHUFFLE_RADIUS      : float = 60.0
const SHUFFLE_WALL_MARGIN : float = 30.0   # keep this far inside the room's edge
const SHUFFLE_TALK_RANGE  : float = 60.0   # player this close = mid-chat, stay put

var _npc_spots    : Dictionary = {}   # npc -> its resting spot in the room (world)
var _npc_next     : Dictionary = {}   # npc -> game minute of its next stroll
var _game_minutes : float      = 0.0  # game minutes since entering, for the above
var _last_hour    : float      = -1.0
var current_building_id : String = ""

## Arrival point for _stage_room: the street door, the elevator, or otherwise
## the id of the room the player just came from.
const FROM_STREET   : String = ""
const FROM_ELEVATOR : String = "<elevator>"

## The floor picker shown on walking into an elevator.
var _elevator_panel : CanvasLayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_elevator_panel = ChoicePanelScript.new()
	_elevator_panel.name = "ElevatorPanel"
	add_child(_elevator_panel)
	_elevator_panel.chosen.connect(_on_floor_chosen)

func setup(player: CharacterBody2D, camera: Camera2D, door_markers: Array) -> void:
	_player  = player
	_camera  = camera
	_markers = door_markers

func is_inside() -> bool:
	return _active != null

## Enter the nearest building door within range. Returns true if it entered.
func try_enter_nearest(from_pos: Vector2) -> bool:
	if is_inside():
		return false
	var best : Node2D = _nearest_door(from_pos)
	if best == null:
		return false
	enter(String(best.name))
	return true

## True if there's an enterable door within range (without entering it).
func has_door_near(from_pos: Vector2) -> bool:
	return _nearest_door(from_pos) != null

func _nearest_door(from_pos: Vector2) -> Node2D:
	var best   : Node2D = null
	var best_d : float  = ENTER_RANGE
	for m in _markers:
		if m is Node2D:
			var d : float = from_pos.distance_to(m.global_position)
			if d <= best_d:
				best_d = d
				best   = m
	return best

## Go in through `building_id`'s street door. `start_room` puts the player
## straight into another room of the building instead — the flat upstairs when
## a day begins at home in the apartments.
func enter(building_id: String, start_room: String = "") -> void:
	if is_inside():
		return
	current_building_id = building_id
	_return = _player.global_position
	# Park the bike at the door so it's saved here for when the player comes back
	# out (force_dismount alone would leave it hidden from the mount).
	if _player.on_bike and _player.world_bike != null:
		_player.world_bike.global_position = _return
		_player.world_bike.visible = true
	_player.force_dismount()
	_player.in_interior = true

	_saved = Rect2(_camera.limit_left, _camera.limit_top,
			_camera.limit_right - _camera.limit_left,
			_camera.limit_bottom - _camera.limit_top)
	var room : String = building_id if start_room.is_empty() else start_room
	_stage_room(room, FROM_STREET)

	var def : InteriorDefinition = InteriorRegistry.get_definition(room)
	if _is_home_room(room):
		var via : String = "" if def.home_hint.is_empty() else " " + def.home_hint
		GameManager.show_message("🏠 Home. Press E at the bed to sleep.%s" % via, 4.0)
	elif not def.enter_hint.is_empty():
		GameManager.show_message(def.enter_hint, 4.0)
	else:
		GameManager.show_message("🚪 Inside. Walk out the south doorway to leave.", 4.0)

	_inside_npcs.clear()
	_inside_pets.clear()
	_reset_shuffle()
	_sync_inside_npcs()
	_sync_inside_pets()
	entered_building.emit()   # birds don't follow the player indoors
	_try_auto_deliver(building_id)

## True when `room_id` is the room with the player's bed in it.
func _is_home_room(room_id: String) -> bool:
	return not GameManager.home_id.is_empty() and room_id == InteriorRegistry.home_room(GameManager.home_id)

## Build `room_id`'s interior at the staging area and put the player and camera
## in it — at its street entrance, out of its elevator, or beside the doorway
## back to the room they came `from` (see FROM_STREET / FROM_ELEVATOR).
func _stage_room(room_id: String, from: String) -> void:
	current_building_id = room_id
	var def : InteriorDefinition = InteriorRegistry.get_definition(room_id)
	# A building may supply its own hand-authored interior (painted background,
	# collision drawn over it); everything else gets the generic room.
	var packed : PackedScene = def.scene if def.has_custom_scene() else InteriorScene
	_active = packed.instantiate()
	# Match the Player (PROCESS_MODE_ALWAYS) so the interior's input/processing
	# stays consistent with it while dialogue or menus pause the tree.
	_active.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_active)
	_active.global_position = STAGE_ORIGIN
	_active.player_ref = _player
	_active.build(def, _is_home_room(room_id))
	_active.exit_requested.connect(exit)
	_active.sleep_requested.connect(_on_sleep)
	_active.link_requested.connect(_on_link_requested)
	_active.elevator_requested.connect(_on_elevator_requested)

	var spawn : Vector2
	match from:
		FROM_STREET:   spawn = _active.player_spawn_point()
		FROM_ELEVATOR: spawn = _active.elevator_spawn_point()
		_:             spawn = _active.door_spawn_point(from)
	_player.global_position = STAGE_ORIGIN + spawn
	_apply_limits(Rect2(STAGE_ORIGIN, def.size))
	_snap_camera()

## Forget indoor strolling state: a new room lays everyone out afresh.
func _reset_shuffle() -> void:
	_npc_spots.clear()
	_npc_next.clear()
	_game_minutes = 0.0
	_last_hour    = -1.0

## Walked through a doorway into another room. Deferred: this arrives from a
## physics callback, where new collision areas can't be added.
func _on_link_requested(room_id: String) -> void:
	_switch_room.call_deferred(room_id, current_building_id)

## Walked into the elevator: offer every other floor on its shaft.
func _on_elevator_requested() -> void:
	var def   : InteriorDefinition = InteriorRegistry.get_definition(current_building_id)
	var stops : Array              = InteriorRegistry.elevator_stops(def.elevator)
	var options : Array = []
	for i in range(stops.size() - 1, -1, -1):   # top floor first, like the buttons
		var stop : Dictionary = stops[i]
		if stop["room"] != current_building_id:
			options.append({"text": stop["label"], "id": stop["room"]})
	if options.is_empty():
		return
	_elevator_panel.open.call_deferred("🛗 Which floor?", options)

func _on_floor_chosen(room_id: String) -> void:
	_switch_room.call_deferred(room_id, FROM_ELEVATOR)

## Swap the active room for `room_id` without going back outside, so leaving
## through the street door still returns the player to where they came in.
## `from` is where they arrive in the new room (see _stage_room).
func _switch_room(room_id: String, from: String) -> void:
	if not is_inside() or room_id == current_building_id:
		return
	for npc in _inside_npcs:
		if is_instance_valid(npc):
			npc.leave_interior()
	_inside_npcs.clear()
	_reset_shuffle()
	_hide_inside_pets()
	_active.queue_free()
	_stage_room(room_id, from)
	if _active.get("workbench_enabled") == true:
		GameManager.show_message("🔧 Press E at the workbench to craft.", 3.5)
	elif _is_home_room(room_id):
		GameManager.show_message("🏠 Home. Press E at the bed to sleep.", 3.0)

## E pressed inside: if it's at a workbench, ask for the crafting panel.
## Returns true when it was, so the player doesn't also use what's in hand.
func try_use_workbench(from_pos: Vector2) -> bool:
	if not is_inside() or not _active.has_method("workbench_near"):
		return false
	if not _active.workbench_near(from_pos):
		return false
	craft_requested.emit()
	return true

func _process(_delta: float) -> void:
	if _active != null:
		_sync_inside_npcs()    # materialize anyone who walks in while we're inside
		_sync_inside_pets()    # … and any dog or cat that's home at this hour
		_shuffle_inside_npcs()

## Advance the indoor clock and send any villager whose time has come for a
## short stroll. Game time is read off TimeManager.hour (wrapping at midnight),
## so it follows the in-game clock rather than real seconds, and a sleep or a
## pause simply doesn't count.
func _shuffle_inside_npcs() -> void:
	var h : float = TimeManager.hour
	if _last_hour >= 0.0:
		var step : float = fposmod(h - _last_hour, 24.0)
		# A big jump is a nap or a day rollover, not minutes passing indoors.
		if step < 1.0:
			_game_minutes += step * 60.0
	_last_hour = h
	if get_tree().paused:
		return
	var room : Rect2 = Rect2(STAGE_ORIGIN, InteriorRegistry.get_definition(current_building_id).size) \
			.grow(-SHUFFLE_WALL_MARGIN)
	for npc in _inside_npcs:
		if not is_instance_valid(npc) or not _npc_spots.has(npc):
			continue
		if _game_minutes < float(_npc_next.get(npc, 0.0)):
			continue
		_npc_next[npc] = _game_minutes + randf_range(SHUFFLE_MIN_MINUTES, SHUFFLE_MAX_MINUTES)
		if _player.global_position.distance_to(npc.global_position) <= SHUFFLE_TALK_RANGE:
			continue
		var a    : float   = randf() * TAU
		var r    : float   = sqrt(randf()) * SHUFFLE_RADIUS
		var spot : Vector2 = _npc_spots[npc] + Vector2(cos(a), sin(a)) * r
		spot = spot.clamp(room.position, room.end)
		npc.set_move_target(spot)

## Materialize any NPCs whose schedule currently has them inside this building
## but who aren't shown yet, and lay them out along the room.
func _sync_inside_npcs() -> void:
	var added : bool = false
	for npc in get_tree().get_nodes_in_group("regular_npc"):
		if npc.is_inside_building(current_building_id) and not _inside_npcs.has(npc):
			_inside_npcs.append(npc)
			added = true
	if added:
		for i in _inside_npcs.size():
			var npc : Node = _inside_npcs[i]
			if not is_instance_valid(npc):
				continue
			var spot : Vector2 = STAGE_ORIGIN + _active.interior_npc_spot(i, _inside_npcs.size())
			npc.show_in_interior(spot)
			_npc_spots[npc] = spot
			# Stagger first strolls so the room doesn't all move at once.
			if not _npc_next.has(npc):
				_npc_next[npc] = _game_minutes + randf_range(SHUFFLE_MIN_MINUTES, SHUFFLE_MAX_MINUTES)

## Show any dogs and cats whose home is this building and whose hours have them
## indoors, curled up along the back of the room. They're display-only in here —
## a pet can't be picked up indoors, it rejoins the world when its window opens.
##
## Both species are laid out in one shared row, so a household with a dog and a
## cat doesn't stack them on the same spot.
func _sync_inside_pets() -> void:
	var parent : Node  = get_parent()
	var home   : Array = []
	var dog_mgr : Node = parent.get_node_or_null("DogManager")
	if dog_mgr != null:
		home.append_array(dog_mgr.dogs_inside(current_building_id))
	var cat_mgr : Node = parent.get_node_or_null("CatManager")
	if cat_mgr != null:
		home.append_array(cat_mgr.cats_inside(current_building_id))
	for i in home.size():
		var pet : Node2D = home[i]
		if not is_instance_valid(pet):
			continue
		if not _inside_pets.has(pet):
			_inside_pets.append(pet)
		# Spread them along the room, offset from where villagers stand.
		var spot : Vector2 = _active.interior_npc_spot(i, maxi(home.size(), 1))
		pet.global_position = STAGE_ORIGIN + spot + Vector2(0.0, 42.0)
		pet.visible = true

## Hide the pets again on the way out, so they aren't left visible at the
## staging area once the interior is torn down.
func _hide_inside_pets() -> void:
	for pet in _inside_pets:
		if is_instance_valid(pet) and pet.is_inside():
			pet.visible = false
	_inside_pets.clear()

## If the building we entered is a live delivery target and the player has a
## package, drop it off automatically (the door markers are ArtBuildings, so the
## entered building is itself the delivery target).
func _try_auto_deliver(building_id: String) -> void:
	var node : Node2D = null
	for m in _markers:
		if m is Node2D and String(m.name) == building_id:
			node = m
			break
	if node == null:
		return
	if node.get("is_target") != true or node.get("is_delivered") == true:
		return
	if GameManager.use_package():
		node.receive_package(node.global_position)

func exit() -> void:
	if not is_inside():
		return
	_elevator_panel.close()
	for npc in _inside_npcs:
		if is_instance_valid(npc):
			npc.leave_interior()
	_inside_npcs.clear()
	_reset_shuffle()
	_hide_inside_pets()
	_active.queue_free()
	_active = null
	_player.in_interior = false
	_player.global_position = _return
	_restore_limits()
	_snap_camera()
	current_building_id = ""

func _on_sleep() -> void:
	exit()
	sleep_requested.emit()

# ── Camera ─────────────────────────────────────────────────
func _apply_limits(rect: Rect2) -> void:
	_camera.limit_left   = int(rect.position.x)
	_camera.limit_top    = int(rect.position.y)
	_camera.limit_right  = int(rect.position.x + rect.size.x)
	_camera.limit_bottom = int(rect.position.y + rect.size.y)

func _restore_limits() -> void:
	_apply_limits(_saved)

func _snap_camera() -> void:
	_camera.reset_smoothing()
	_camera.force_update_scroll()
