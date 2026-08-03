extends Node2D
## Handles entering and leaving building interiors. Created by Main. The
## exterior world stays alive and simulating (time keeps running) — it's just
## off-camera while a generic Interior instance is staged far from the map and
## the player + camera are moved into it.

signal sleep_requested

const InteriorScene : PackedScene = preload("res://scenes/Interior.tscn")
const STAGE_ORIGIN  : Vector2     = Vector2(100000, 100000)   # far from the world map
const ENTER_RANGE   : float       = 84.0

var _player  : CharacterBody2D = null
var _camera  : Camera2D        = null
var _markers : Array           = []   # door-marker Node2Ds (name = building id)

var _active  : Node    = null
var _return  : Vector2 = Vector2.ZERO
var _saved   : Rect2   = Rect2()
var _inside_npcs : Array = []   # NPCs materialized inside the active interior
var current_building_id : String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

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

func enter(building_id: String) -> void:
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

	var def : InteriorDefinition = InteriorRegistry.get_definition(building_id)
	_active = InteriorScene.instantiate()
	# Match the Player (PROCESS_MODE_ALWAYS) so the interior's input/processing
	# stays consistent with it while dialogue or menus pause the tree.
	_active.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_active)
	_active.global_position = STAGE_ORIGIN
	_active.player_ref = _player
	_active.build(def, building_id == GameManager.home_id)
	_active.exit_requested.connect(exit)
	_active.sleep_requested.connect(_on_sleep)

	_player.global_position = STAGE_ORIGIN + _active.player_spawn_point()
	_saved = Rect2(_camera.limit_left, _camera.limit_top,
			_camera.limit_right - _camera.limit_left,
			_camera.limit_bottom - _camera.limit_top)
	_apply_limits(Rect2(STAGE_ORIGIN, def.size))
	_snap_camera()

	if building_id == GameManager.home_id:
		GameManager.show_message("🏠 Home. Press E at the bed to sleep, or leave by the south doorway.", 4.0)
	else:
		GameManager.show_message("🚪 Inside. Walk out the south doorway to leave.", 4.0)

	_inside_npcs.clear()
	_sync_inside_npcs()
	_try_auto_deliver(building_id)

func _process(_delta: float) -> void:
	if _active != null:
		_sync_inside_npcs()   # materialize anyone who walks in while we're inside

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
			if is_instance_valid(_inside_npcs[i]):
				_inside_npcs[i].show_in_interior(STAGE_ORIGIN + _active.interior_npc_spot(i, _inside_npcs.size()))

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
	for npc in _inside_npcs:
		if is_instance_valid(npc):
			npc.leave_interior()
	_inside_npcs.clear()
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
