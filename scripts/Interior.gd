class_name Interior
extends Node2D
## Generic building interior: a white room on a black backdrop with an obvious
## south doorway you walk out of to leave. Built procedurally from an
## InteriorDefinition, so one scene serves every building. If it's the player's
## home, a bed is added — interacting with it (E) sleeps / ends the day.
##
## Besides the street exit a room can have doors into other rooms of the same
## building, in any wall, and an elevator (see InteriorDefinition.doors).

signal exit_requested
signal sleep_requested
## Walked through a doorway into another room of the same building (a home's
## garage, a flat off a hallway, or back). InteriorManager swaps rooms.
signal link_requested(room_id: String)
## Walked into the elevator. InteriorManager asks which floor.
signal elevator_requested

const WALL_THICKNESS : float   = 10.0
const BED_SIZE       : Vector2 = Vector2(72, 46)
const BED_INTERACT   : float   = 44.0
const DOOR_COLOR     : Color   = Color(0.55, 0.35, 0.18)
const LIFT_COLOR     : Color   = Color(0.62, 0.66, 0.72)
const SIGN_COLOR     : Color   = Color(0.25, 0.25, 0.25)

var player_ref : Node2D = null

var _size      : Vector2 = Vector2.ZERO
var _doorway_w : float   = 64.0
var _is_home   : bool    = false
var _bed_rect  : Rect2   = Rect2()
var _floor     : String  = "tiles"
var _title     : String  = ""

## Every gap in the walls: the street exit (when the room has one) and each
## door or elevator, as the Dictionaries described on InteriorDefinition.doors
## plus a "street" flag.
var _openings : Array = []

func build(def: InteriorDefinition, is_home: bool) -> void:
	_size      = def.size
	_doorway_w = def.doorway_width
	_is_home   = is_home
	_floor     = def.floor_style
	_title     = def.title
	_openings.clear()
	if def.street_exit:
		_openings.append({"to": "", "label": "Exit", "side": InteriorDefinition.SIDE_SOUTH,
				"at": 0.5, "kind": InteriorDefinition.KIND_DOOR, "street": true})
	for d in def.doors:
		var owner : String = str(d.get("owner", ""))
		# A doorway that belongs to a home the player doesn't own isn't there.
		if not owner.is_empty() and owner != GameManager.home_id:
			continue
		var op : Dictionary = d.duplicate()
		op["street"] = false
		_openings.append(op)
	z_index    = -1000   # render behind the player
	if _is_home:
		_bed_rect = _resolve_bed_rect()
	_build_walls()
	_build_opening_areas()
	queue_redraw()

## Where the bed sits. An authored scene places a Marker2D named "Bed" on the
## bed in its art and that is used; otherwise the bed goes centre-top of the
## room, where the procedural _draw paints it.
func _resolve_bed_rect() -> Rect2:
	var m : Marker2D = get_node_or_null("Bed") as Marker2D
	if m != null:
		return Rect2(m.position - BED_SIZE * 0.5, BED_SIZE)
	return Rect2(_size.x * 0.5 - BED_SIZE.x * 0.5, 26.0, BED_SIZE.x, BED_SIZE.y)

## Overridable: a hand-authored interior draws its own art (a Sprite2D child)
## and supplies its own collision, so it returns false here to suppress the
## procedural floor, checkerboard and box walls. See CityHallInterior.gd.
func _is_procedural() -> bool:
	return true

## Where the player appears on entering — just inside the south doorway, or at
## a Marker2D named "PlayerSpawn" if the authored scene provides one.
func player_spawn_point() -> Vector2:
	var m : Marker2D = get_node_or_null("PlayerSpawn") as Marker2D
	if m != null:
		return m.position
	return Vector2(_size.x * 0.5, _size.y - 46.0)

## A spot inside the room for the `index`-th of `count` NPCs — spread across the
## upper part of the room, ahead of the player who enters from the south.
## An authored scene can place Marker2Ds under a node named "NPCSpots" to choose
## where villagers stand; they're used in order, falling back to the even spread
## once they run out.
func interior_npc_spot(index: int, count: int) -> Vector2:
	var spots : Node = get_node_or_null("NPCSpots")
	if spots != null and index < spots.get_child_count():
		var m : Marker2D = spots.get_child(index) as Marker2D
		if m != null:
			return m.position
	# Spread across the room. index can exceed count if more villagers walk in
	# than were counted, so keep the result inside the walls either way.
	var slots : int   = maxi(count, index + 1)
	var x     : float = _size.x * float(index + 1) / float(slots + 1)
	return Vector2(clampf(x, 40.0, _size.x - 40.0), _size.y * 0.45)

## Where the player appears on coming through from `from_room` — just inside
## the doorway that leads back there, or at a Marker2D "Spawn_<from_room>".
## Falls back to the street spawn.
func door_spawn_point(from_room: String) -> Vector2:
	var m : Marker2D = get_node_or_null("Spawn_" + from_room) as Marker2D
	if m != null:
		return m.position
	for op in _openings:
		if not op["street"] and op["kind"] == InteriorDefinition.KIND_DOOR and str(op["to"]) == from_room:
			return _inside_of(op)
	return player_spawn_point()

## Where the player steps out of the elevator, or a Marker2D "ElevatorSpawn".
func elevator_spawn_point() -> Vector2:
	var m : Marker2D = get_node_or_null("ElevatorSpawn") as Marker2D
	if m != null:
		return m.position
	for op in _openings:
		if op["kind"] == InteriorDefinition.KIND_ELEVATOR:
			return _inside_of(op)
	return player_spawn_point()

# ── Opening geometry ───────────────────────────────────────
func _is_horizontal(side: int) -> bool:
	return side == InteriorDefinition.SIDE_NORTH or side == InteriorDefinition.SIDE_SOUTH

# Length of the wall on `side`.
func _wall_length(side: int) -> float:
	return _size.x if _is_horizontal(side) else _size.y

# Centre of an opening, measured along its wall.
func _along(op: Dictionary) -> float:
	return float(op["at"]) * _wall_length(int(op["side"]))

# Range [start, end] along its wall that an opening's gap covers.
func _gap(op: Dictionary) -> Vector2:
	var c : float = _along(op)
	return Vector2(c - _doorway_w * 0.5, c + _doorway_w * 0.5)

# A point just inside the room in front of an opening.
func _inside_of(op: Dictionary) -> Vector2:
	var c : float = _along(op)
	match int(op["side"]):
		InteriorDefinition.SIDE_NORTH: return Vector2(c, 46.0)
		InteriorDefinition.SIDE_SOUTH: return Vector2(c, _size.y - 46.0)
		InteriorDefinition.SIDE_EAST:  return Vector2(_size.x - 50.0, c)
		_:                             return Vector2(50.0, c)

# Centre of the trigger strip just beyond an opening's gap.
func _outside_of(op: Dictionary) -> Vector2:
	var c : float = _along(op)
	match int(op["side"]):
		InteriorDefinition.SIDE_NORTH: return Vector2(c, -14.0)
		InteriorDefinition.SIDE_SOUTH: return Vector2(c, _size.y + 14.0)
		InteriorDefinition.SIDE_EAST:  return Vector2(_size.x + 14.0, c)
		_:                             return Vector2(-14.0, c)

# ── Collision ──────────────────────────────────────────────
func _build_walls() -> void:
	if not _is_procedural():
		return   # the authored scene brings its own walls
	var body : StaticBody2D = StaticBody2D.new()
	add_child(body)
	for side in [InteriorDefinition.SIDE_NORTH, InteriorDefinition.SIDE_SOUTH,
			InteriorDefinition.SIDE_EAST, InteriorDefinition.SIDE_WEST]:
		_add_side_wall(body, side)

# One wall, split around every opening in it. North and south run past the
# corners so the box has no gaps where the walls meet.
func _add_side_wall(body: StaticBody2D, side: int) -> void:
	var t     : float = WALL_THICKNESS
	var horiz : bool  = _is_horizontal(side)
	var gaps  : Array = []
	for op in _openings:
		if int(op["side"]) == side:
			gaps.append(_gap(op))
	gaps.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cursor : float = -t if horiz else 0.0
	for g in gaps:
		_add_wall_span(body, side, cursor, g.x)
		cursor = g.y
	_add_wall_span(body, side, cursor, _wall_length(side) + (t if horiz else 0.0))

func _add_wall_span(body: StaticBody2D, side: int, from: float, to: float) -> void:
	if to <= from:
		return
	var t : float = WALL_THICKNESS
	match side:
		InteriorDefinition.SIDE_NORTH: _add_wall(body, Rect2(from, -t, to - from, t))
		InteriorDefinition.SIDE_SOUTH: _add_wall(body, Rect2(from, _size.y, to - from, t))
		InteriorDefinition.SIDE_EAST:  _add_wall(body, Rect2(_size.x, from, t, to - from))
		_:                             _add_wall(body, Rect2(-t, from, t, to - from))

func _add_wall(body: StaticBody2D, rect: Rect2) -> void:
	var shape : CollisionShape2D  = CollisionShape2D.new()
	var box   : RectangleShape2D  = RectangleShape2D.new()
	box.size       = rect.size
	shape.shape    = box
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)

## Wire up every way out of the room. An authored scene can place its own
## Area2D over a doorway in its art — "ExitArea" for the street, "Door_<room>"
## for a door, "Elevator" for the elevator — and that is used instead of the
## strip generated just beyond the gap.
func _build_opening_areas() -> void:
	for op in _openings:
		var callback  : Callable
		var node_name : String
		if op["street"]:
			callback  = _on_exit_body_entered
			node_name = "ExitArea"
		elif op["kind"] == InteriorDefinition.KIND_ELEVATOR:
			callback  = _on_elevator_body_entered
			node_name = "Elevator"
		else:
			callback  = _on_link_body_entered.bind(str(op["to"]))
			node_name = "Door_" + str(op["to"])
		var authored : Area2D = get_node_or_null(node_name) as Area2D
		if authored != null:
			authored.body_entered.connect(callback)
			continue
		var area  : Area2D           = Area2D.new()
		var shape : CollisionShape2D = CollisionShape2D.new()
		var box   : RectangleShape2D = RectangleShape2D.new()
		box.size       = Vector2(_doorway_w, 24.0) if _is_horizontal(int(op["side"])) else Vector2(24.0, _doorway_w)
		shape.shape    = box
		shape.position = _outside_of(op)
		area.add_child(shape)
		add_child(area)
		area.body_entered.connect(callback)

func _on_link_body_entered(body: Node, room_id: String) -> void:
	if body == player_ref:
		link_requested.emit(room_id)

func _on_elevator_body_entered(body: Node) -> void:
	if body == player_ref:
		elevator_requested.emit()

func _on_exit_body_entered(body: Node) -> void:
	if body == player_ref:
		exit_requested.emit()

# ── Sleep (home only) ──────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _is_home or player_ref == null:
		return
	if event.is_action_pressed("interact"):
		var bed_center : Vector2 = global_position + _bed_rect.position + _bed_rect.size * 0.5
		if player_ref.global_position.distance_to(bed_center) <= BED_INTERACT:
			sleep_requested.emit()

# ── Draw ───────────────────────────────────────────────────
func _draw() -> void:
	# Black backdrop far beyond the room so the screen stays black around it.
	# Authored interiors keep this (it masks the world beyond their art) but
	# skip the generic floor and walls painted below it.
	draw_rect(Rect2(-3000, -3000, _size.x + 6000, _size.y + 6000), Color.BLACK)
	if not _is_procedural():
		return
	# Room floor with a faint checkerboard so motion reads clearly: white tiles
	# indoors, grey concrete in a garage, grass in a back yard, carpet in a hall.
	var floor_a : Color = Color(0.93, 0.93, 0.93)
	var floor_b : Color = Color(0.85, 0.85, 0.87)
	match _floor:
		"concrete":
			floor_a = Color(0.62, 0.62, 0.60)
			floor_b = Color(0.57, 0.57, 0.55)
		"grass":
			floor_a = Color(0.45, 0.66, 0.36)
			floor_b = Color(0.41, 0.61, 0.33)
		"carpet":
			floor_a = Color(0.78, 0.70, 0.58)
			floor_b = Color(0.74, 0.66, 0.54)
	draw_rect(Rect2(Vector2.ZERO, _size), floor_a)
	var cell : float = 32.0
	var cols : int   = int(ceil(_size.x / cell))
	var rows : int   = int(ceil(_size.y / cell))
	for j in rows:
		for i in cols:
			if (i + j) % 2 == 1:
				var x : float = float(i) * cell
				var y : float = float(j) * cell
				draw_rect(Rect2(x, y, minf(cell, _size.x - x), minf(cell, _size.y - y)), floor_b)
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.14, 0.14, 0.14), false, WALL_THICKNESS)
	for op in _openings:
		_draw_opening(op)
	if not _title.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(18.0, 30.0), _title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, SIGN_COLOR)
	# Bed (home only).
	if _is_home:
		draw_rect(_bed_rect, Color(0.55, 0.7, 0.95))
		draw_rect(Rect2(_bed_rect.position, Vector2(_bed_rect.size.x, 14.0)), Color(0.92, 0.92, 0.97))
		draw_string(ThemeDB.fallback_font, _bed_rect.position + Vector2(0.0, -6.0),
				"Bed — E to sleep", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.9))

## Knock the gap through the painted wall, lay a threshold in it — timber for a
## door, steel for the elevator — and sign it with where it goes.
func _draw_opening(op: Dictionary) -> void:
	var t    : float   = WALL_THICKNESS
	var g    : Vector2 = _gap(op)
	var w    : float   = g.y - g.x
	var side : int     = int(op["side"])
	var lift : bool    = op["kind"] == InteriorDefinition.KIND_ELEVATOR
	var mat  : Color   = LIFT_COLOR if lift else DOOR_COLOR
	var font : Font    = ThemeDB.fallback_font
	var text : String  = str(op["label"]).to_upper()
	var tw   : float   = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	match side:
		InteriorDefinition.SIDE_NORTH:
			draw_rect(Rect2(g.x, -t, w, t * 2.0), Color.BLACK)
			draw_rect(Rect2(g.x, -4.0, w, 9.0), mat)
			if lift:   # the seam between the two sliding doors
				draw_line(Vector2(g.x + w * 0.5, -4.0), Vector2(g.x + w * 0.5, 5.0), Color(0.3, 0.32, 0.36), 2.0)
			draw_string(font, Vector2(g.x + (w - tw) * 0.5, 24.0), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SIGN_COLOR)
		InteriorDefinition.SIDE_SOUTH:
			draw_rect(Rect2(g.x, _size.y - t, w, t * 2.0), Color.BLACK)
			draw_rect(Rect2(g.x, _size.y - 5.0, w, 9.0), mat)
			if op["street"]:
				draw_string(font, Vector2(g.x - 4.0, _size.y + 28.0), "EXIT",
						HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))
			else:
				draw_string(font, Vector2(g.x + (w - tw) * 0.5, _size.y - 14.0), text,
						HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SIGN_COLOR)
		_:
			var east : bool  = side == InteriorDefinition.SIDE_EAST
			var wx   : float = _size.x - t if east else -t
			draw_rect(Rect2(wx, g.x, t * 2.0, w), Color.BLACK)
			draw_rect(Rect2(_size.x - 5.0 if east else -4.0, g.x, 9.0, w), mat)
			if lift:
				draw_line(Vector2(_size.x - 5.0 if east else -4.0, g.x + w * 0.5),
						Vector2(_size.x + 4.0 if east else 5.0, g.x + w * 0.5), Color(0.3, 0.32, 0.36), 2.0)
			text = text + " →" if east else "← " + text
			tw   = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var tx : float = _size.x - tw - 16.0 if east else 16.0
			draw_string(font, Vector2(tx, g.x - 8.0), text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, SIGN_COLOR)
