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
var _away            : bool    = false   # out of town this part of the year
var _wander_centre   : Vector2 = Vector2.ZERO
var _wander_radius   : float   = 0.0     # > 0 while drifting around _wander_centre
var _on_duty         : bool    = false   # posted to a police roadblock
var _duty_post       : Vector2 = Vector2.ZERO
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
	if _on_duty:
		# Posted to a police roadblock: stay put until stood down.
		_come_outside()
		set_move_target(_duty_post)
		return
	# Out of town for the season (e.g. on tour): hide entirely and skip the
	# schedule until they're back.
	if definition != null and definition.is_away_on(GameManager.day):
		if not _away:
			_away = true
			_apply_presence()
		return
	if _away:
		_away = false
		_apply_presence()
	for entry in schedule:
		if entry.matches(TimeManager.weekday, TimeManager.phase, TimeManager.week_parity,
				TimeManager.hour, TimeManager.season):
			if entry.interior:
				_wander_centre = Vector2.ZERO
				_wander_radius = 0.0
				_target_interior(entry.anchor, _resolve(entry.anchor, entry.offset), immediate)
			else:
				# Standing outside a building: keep clear of its doorway.
				_pending_interior = ""
				_come_outside()
				var door : Vector2 = anchor_positions.get(entry.anchor, home_position)
				var spot : Vector2 = _clear_of_door(door, _resolve(entry.anchor, entry.offset))
				_wander_radius = entry.wander
				if _wander_radius > 0.0:
					_wander_centre = spot
					set_move_target(_pick_wander_point())
				else:
					_wander_centre = Vector2.ZERO
					set_move_target(spot)
				# Spawn / start of day: stand at the spot rather than walking to
				# it, so an outdoor post is reached even when the navmesh doesn't
				# quite reach it (doors sit off the walkable area).
				if immediate:
					global_position = _move_target
					velocity = Vector2.ZERO
			return
	_pending_interior = ""
	_come_outside()
	_wander_centre = Vector2.ZERO
	_wander_radius = 0.0
	set_move_target(_clear_of_door(_home_door_pos(), home_position))
	if immediate:
		global_position = _move_target
		velocity = Vector2.ZERO

## A random point within the current wander area, kept clear of the doorway.
func _pick_wander_point() -> Vector2:
	var a : float = randf() * TAU
	var r : float = sqrt(randf()) * _wander_radius   # uniform over the disc
	return _wander_centre + Vector2(cos(a), sin(a)) * r

## The home door itself (home_position already includes the definition offset).
func _home_door_pos() -> Vector2:
	return anchor_positions.get(home_anchor, home_position)

## How close to a door counts as reaching it. Door markers sit well inside the
## building's collision polygon (median ~35px, up to ~65px), so an NPC walking
## to one can never physically touch it — it would grind against the wall and
## never trigger entry. Anything within this radius steps inside.
const DOOR_ARRIVE_RADIUS : float = 26.0

func _target_interior(building_id: String, door_pos: Vector2, immediate: bool) -> void:
	if _inside and current_interior == building_id:
		return   # already inside this building
	if immediate:
		_go_inside(building_id, door_pos)
	else:
		# Walk to the door (visible); _on_arrived() takes it inside. The door
		# marker sits inside the building's collision polygon, so accept a wide
		# arrival radius — the NPC can't physically stand on it.
		_come_outside()
		_pending_interior = building_id
		set_move_target(door_pos, DOOR_ARRIVE_RADIUS)

## Only entering a building may complete while wedged against geometry — that
## is the case where the target is deliberately inside a wall.
func _blocked_arrival_ok() -> bool:
	return _pending_interior != ""

func _on_arrived() -> void:
	if _pending_interior != "":
		var b : String = _pending_interior
		_pending_interior = ""
		# Park on the door itself, not wherever we stopped short of it, so
		# stepping back out later puts us at the doorway.
		_go_inside(b, anchor_positions.get(b, global_position))
		return
	# Wandering: pause a beat, then drift to another nearby spot.
	if _wander_radius > 0.0:
		_halt_timer = maxf(_halt_timer, randf_range(1.5, 4.0))
		set_move_target(_pick_wander_point())

# ── Interior presence ──────────────────────────────────────
func is_inside_building(building_id: String) -> bool:
	return _inside and current_interior == building_id

## True while this NPC is out of town (on tour etc.) — no map marker.
func is_away() -> bool:
	return _away

# ── Police duty ────────────────────────────────────────────
## Send this officer to man a roadblock. They drive there (cruiser speed) and
## stay until released, ignoring their normal schedule.
func post_to_duty(post: Vector2) -> void:
	_on_duty   = true
	_duty_post = post
	_pending_interior = ""
	_wander_radius = 0.0
	_come_outside()
	# Arrive by cruiser: they cover the distance quickly rather than strolling.
	global_position = post
	set_move_target(post)
	_apply_presence()

func release_from_duty() -> void:
	if not _on_duty:
		return
	_on_duty = false
	_retarget(true)

## Where this NPC should be shown on the world map. Indoors they're physically
## parked at the interior staging area, so report the door of the building
## they're in instead. Returns false in `valid` when they shouldn't be shown.
func map_marker_position() -> Dictionary:
	if _away:
		return {"valid": false, "position": Vector2.ZERO, "indoors": false}
	if _inside:
		var door : Vector2 = anchor_positions.get(current_interior, home_position)
		return {"valid": true, "position": door, "indoors": true}
	if _pinned:
		# Displayed inside an interior the player is visiting; use the door too.
		var d2 : Vector2 = anchor_positions.get(current_interior, _prepin_pos)
		return {"valid": true, "position": d2, "indoors": true}
	return {"valid": true, "position": global_position, "indoors": false}

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
# Being away from town hides them regardless.
func _apply_presence() -> void:
	var shown : bool = ((not _inside) or _pinned) and not _away
	visible = shown
	_set_group("interactable_npc", shown)
	var solid : bool = shown and not _inside
	collision_layer = _col_layer if solid else 0
	collision_mask  = _col_mask  if solid else 0

func _set_group(g: String, on: bool) -> void:
	if on and not is_in_group(g):
		add_to_group(g)
	elif not on and is_in_group(g):
		remove_from_group(g)

## Minimum distance an idling NPC must keep from ANY doorway, so nobody loiters
## where the player needs to walk in. Only applies to resting spots — NPCs
## actually entering or leaving a building still walk right up to the door.
const DOOR_CLEARANCE : float = 80.0

## Every door position in town, shared by NPCManager so clearance can be checked
## against all of them rather than just this NPC's own anchors.
static var all_door_positions : Array[Vector2] = []

func _resolve(anchor: String, offset: Vector2) -> Vector2:
	var base : Vector2 = anchor_positions.get(anchor, home_position)
	return base + offset

## Push a standing spot clear of every nearby doorway. `preferred_door` is the
## NPC's own anchor, used to pick a sensible direction when the spot has to move.
func _clear_of_door(preferred_door: Vector2, spot: Vector2) -> Vector2:
	var result : Vector2 = spot
	# Repeatedly push out of whichever door is currently too close. A handful of
	# passes settles the common cases (doors clustered along a street).
	for _pass in 6:
		var worst      : Vector2 = Vector2.ZERO
		var worst_dist : float   = DOOR_CLEARANCE
		var found      : bool    = false
		for d in all_door_positions:
			var dist : float = result.distance_to(d)
			if dist < worst_dist:
				worst_dist = dist
				worst      = d
				found      = true
		if not found:
			return result
		var away : Vector2 = result - worst
		if away.length() < 0.01:
			# Sitting exactly on a door: head away from the NPC's own anchor, or
			# south if that's the same door.
			away = result - preferred_door
			if away.length() < 0.01:
				away = Vector2.DOWN
		result = worst + away.normalized() * DOOR_CLEARANCE
	return result

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
	var who    : String = display_label()
	for line in get_dialogue():
		if line is DialogueLine:
			blocks.append({"text": line.text, "portrait": portrait_for_mood(line.mood), "speaker": who})
		else:
			blocks.append({"text": str(line), "portrait": portrait_for_mood(""), "speaker": who})
	return blocks

## The name shown beside this NPC's portrait. NPCs with no name of their own
## fall back to a stable "NPC 1", "NPC 2", … label based on their id.
func display_label() -> String:
	if not npc_name.is_empty() and npc_name != "Villager":
		return npc_name
	return NPCRegistry.fallback_name_for(id)
