class_name RegularNPC
extends NPCBase
## Named villager with a weekly schedule (weekday + day phase → location) and
## dialogue. Its data comes from an NPCDefinition in NPCRegistry (configured by
## NPCManager at spawn). The player interacts with E when close; the NPC stops,
## turns to face the player, and the dialogue box opens.

var npc_name        : String                  = "Villager"
var home_position   : Vector2                 = Vector2.ZERO
var home_anchor     : String                  = ""   # door name backing home_position
var schedule        : Array[NPCScheduleEntry] = []
var dialogue_lines  : Array                   = []   # Array of DialogueLine
var conversation    : Resource                = null # future branching tree
var portrait        : Texture2D               = null # neutral portrait (fallback)
var definition      : NPCDefinition           = null # source data; resolves mood portraits
# Door node name -> resolved world position, filled in by NPCManager so the
# NPC can turn its schedule anchors into positions at retarget time.
var anchor_positions : Dictionary             = {}

# Interior presence. While `_inside`, the NPC is inside a building (`current_interior`)
# and hidden from the overworld; when the player enters that building the
# InteriorManager `_pinned`s it into the interior so it can be seen and talked to.
var _inside          : bool    = false
var current_interior : String  = ""
var _pending_interior: String  = ""   # walking to this building's door, then going inside
var _pinned          : bool    = false
var _prepin_pos      : Vector2 = Vector2.ZERO
var _col_layer       : int     = 1
var _col_mask        : int     = 1

func _ready() -> void:
	super._ready()
	add_to_group("interactable_npc")
	add_to_group("regular_npc")
	_col_layer = collision_layer
	_col_mask  = collision_mask

## First schedule entry matching the current weekday/phase/week wins. Interior
## entries make the NPC walk to the building and go inside on arrival (or, when
## `immediate`, appear inside at once — used at spawn / start of day). No match
## means head home.
func _retarget(immediate: bool = false) -> void:
	if _pinned:
		return   # currently displayed in an interior; don't move
	for entry in schedule:
		if entry.matches(TimeManager.weekday, TimeManager.phase, TimeManager.week_parity, TimeManager.hour):
			if entry.interior:
				_target_interior(entry.anchor, _resolve(entry.anchor, entry.offset), immediate)
			else:
				# Standing outside a building: keep clear of its doorway.
				_pending_interior = ""
				_come_outside()
				var door : Vector2 = anchor_positions.get(entry.anchor, home_position)
				set_move_target(_clear_of_door(door, _resolve(entry.anchor, entry.offset)))
			return
	_pending_interior = ""
	_come_outside()
	set_move_target(_clear_of_door(_home_door_pos(), home_position))

## The home door itself (home_position already includes the definition offset).
func _home_door_pos() -> Vector2:
	return anchor_positions.get(home_anchor, home_position)

func _target_interior(building_id: String, door_pos: Vector2, immediate: bool) -> void:
	if _inside and current_interior == building_id:
		return   # already inside this building
	if immediate:
		_go_inside(building_id, door_pos)
	else:
		# Walk to the door (visible); _on_arrived() takes it inside.
		_come_outside()
		_pending_interior = building_id
		set_move_target(door_pos)

func _on_arrived() -> void:
	if _pending_interior != "":
		var b : String = _pending_interior
		_pending_interior = ""
		_go_inside(b, global_position)

# ── Interior presence ──────────────────────────────────────
func is_inside_building(building_id: String) -> bool:
	return _inside and current_interior == building_id

## Materialize this NPC inside an interior instance at `pos` (called by
## InteriorManager when the player enters the building it's in).
func show_in_interior(pos: Vector2) -> void:
	if not _pinned:
		_prepin_pos = global_position   # remember her parked door spot (once)
	_pinned = true
	global_position = pos
	velocity = Vector2.ZERO
	set_move_target(pos)
	facing = Vector2.DOWN
	_apply_presence()

## Stop displaying in an interior: return to the building's door, hide again if
## still scheduled inside, or walk out (transit) if the schedule now sends her
## elsewhere — so she always leaves via the door rather than teleporting.
func leave_interior() -> void:
	_pinned = false
	global_position = _prepin_pos
	_apply_presence()      # hides her if she's still _inside
	_retarget(false)       # same building → stays inside; different → walks out

func _go_inside(building_id: String, park_pos: Vector2) -> void:
	current_interior = building_id
	_inside = true
	global_position = park_pos
	velocity = Vector2.ZERO
	set_move_target(park_pos)
	_apply_presence()

func _come_outside() -> void:
	if _inside:
		_inside = false
		current_interior = ""
		_apply_presence()

# Visible & interactable when outside or pinned; collidable only when outside.
func _apply_presence() -> void:
	var shown : bool = (not _inside) or _pinned
	visible = shown
	_set_group("interactable_npc", shown)
	collision_layer = _col_layer if not _inside else 0
	collision_mask  = _col_mask  if not _inside else 0

func _set_group(g: String, on: bool) -> void:
	if on and not is_in_group(g):
		add_to_group(g)
	elif not on and is_in_group(g):
		remove_from_group(g)

## Minimum distance an idling NPC must keep from a doorway, so nobody loiters in
## a door the player needs to use. Only applies to resting spots — NPCs actually
## entering or leaving a building still walk right up to the door.
const DOOR_CLEARANCE : float = 20.0

func _resolve(anchor: String, offset: Vector2) -> Vector2:
	var base : Vector2 = anchor_positions.get(anchor, home_position)
	return base + offset

## Push a standing spot away from its doorway if it's too close. The direction
## is kept (so an NPC meant to wait south of a door still waits south of it),
## just extended out to DOOR_CLEARANCE.
func _clear_of_door(door_pos: Vector2, spot: Vector2) -> Vector2:
	var away : Vector2 = spot - door_pos
	if away.length() >= DOOR_CLEARANCE:
		return spot
	if away.length() < 0.01:
		away = Vector2.DOWN   # spot sits exactly on the door: step south of it
	return door_pos + away.normalized() * DOOR_CLEARANCE

## Called by Player just before opening the dialogue box. The tree pauses
## while dialogue is open; the short halt keeps the NPC standing politely
## for a beat after it closes.
func begin_interaction(player: Node2D) -> void:
	_halt_timer = maxf(_halt_timer, 1.0)
	velocity = Vector2.ZERO
	face_toward(player.global_position)

func get_dialogue() -> Array:
	if dialogue_lines.is_empty():
		# Fallback is a DialogueLine (not a bare String) so it still resolves a
		# portrait via the neutral/base art.
		return [DialogueLine.make("%s waves hello!" % npc_name)]
	# Random-chatter NPCs say one line per conversation; others play the whole
	# sequence in order.
	if definition != null and definition.random_dialogue:
		return [dialogue_lines[randi() % dialogue_lines.size()]]
	return dialogue_lines

func get_portrait() -> Texture2D:
	return portrait

## Portrait for a mood (see DialogueLine mood constants), with fallback baked
## into NPCDefinition.portrait_texture().
func portrait_for_mood(mood: String) -> Texture2D:
	if definition != null:
		return definition.portrait_texture(mood)
	return portrait

## Build ready-to-display dialogue blocks: each line's text paired with the
## portrait for that line's emotion. Tolerates plain Strings as neutral lines.
func get_dialogue_blocks() -> Array:
	var blocks : Array = []
	for line in get_dialogue():
		if line is DialogueLine:
			blocks.append({"text": line.text, "portrait": portrait_for_mood(line.mood)})
		else:
			blocks.append({"text": str(line), "portrait": portrait_for_mood("")})
	return blocks
