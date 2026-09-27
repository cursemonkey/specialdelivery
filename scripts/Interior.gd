class_name Interior
extends Node2D
## Generic building interior: a white room on a black backdrop with an obvious
## south doorway you walk out of to leave. Built procedurally from an
## InteriorDefinition, so one scene serves every building. If it's the player's
## home, a bed is added — interacting with it (E) sleeps / ends the day.

signal exit_requested
signal sleep_requested
## Walked through the doorway into the linked room (a home's garage or back
## yard, or back from it). InteriorManager swaps rooms in response.
signal link_requested(room_id: String)

const WALL_THICKNESS : float   = 10.0
const BED_SIZE       : Vector2 = Vector2(72, 46)
const BED_INTERACT   : float   = 44.0

var player_ref : Node2D = null

var _size      : Vector2 = Vector2.ZERO
var _doorway_w : float   = 64.0
var _is_home   : bool    = false
var _bed_rect  : Rect2   = Rect2()
var _link_id    : String = ""
var _link_label : String = ""
var _link_side  : int    = InteriorDefinition.SIDE_EAST
var _floor      : String = "tiles"

## Set by InteriorManager before build(): false hides the linked doorway, so a
## home the player hasn't bought doesn't lead into its garage.
var link_enabled : bool = true

func build(def: InteriorDefinition, is_home: bool) -> void:
	_size      = def.size
	_doorway_w = def.doorway_width
	_is_home   = is_home
	_floor     = def.floor_style
	if def.has_link() and link_enabled:
		_link_id    = def.link_id
		_link_label = def.link_label
		_link_side  = def.link_side
	z_index    = -1000   # render behind the player
	if _is_home:
		_bed_rect = _resolve_bed_rect()
	_build_walls()
	_build_exit_area()
	_build_link_area()
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

## Where the player appears on coming through from the linked room — just
## inside the linked doorway, or at a Marker2D named "LinkSpawn".
func link_spawn_point() -> Vector2:
	var m : Marker2D = get_node_or_null("LinkSpawn") as Marker2D
	if m != null:
		return m.position
	var x : float = _size.x - 50.0 if _link_side == InteriorDefinition.SIDE_EAST else 50.0
	return Vector2(x, _size.y * 0.5)

func has_link() -> bool:
	return not _link_id.is_empty()

# y-range [top, bottom] of the linked doorway's gap in the east or west wall.
func _link_gap() -> Vector2:
	var half : float = _doorway_w * 0.5
	return Vector2(_size.y * 0.5 - half, _size.y * 0.5 + half)

# x-range [left, right] of the doorway gap in the south wall.
func _door_gap() -> Vector2:
	var half : float = _doorway_w * 0.5
	return Vector2(_size.x * 0.5 - half, _size.x * 0.5 + half)

# ── Collision ──────────────────────────────────────────────
func _build_walls() -> void:
	if not _is_procedural():
		return   # the authored scene brings its own walls
	var body : StaticBody2D = StaticBody2D.new()
	add_child(body)
	var t   : float   = WALL_THICKNESS
	var gap : Vector2 = _door_gap()
	_add_wall(body, Rect2(-t, -t, _size.x + 2.0 * t, t))          # north
	_add_side_wall(body, -t,      InteriorDefinition.SIDE_WEST)   # west
	_add_side_wall(body, _size.x, InteriorDefinition.SIDE_EAST)   # east
	_add_wall(body, Rect2(0.0, _size.y, gap.x, t))               # south-left
	_add_wall(body, Rect2(gap.y, _size.y, _size.x - gap.y, t))   # south-right

# An east or west wall, split around the linked doorway when it's on that side.
func _add_side_wall(body: StaticBody2D, x: float, side: int) -> void:
	var t : float = WALL_THICKNESS
	if not has_link() or _link_side != side:
		_add_wall(body, Rect2(x, 0.0, t, _size.y))
		return
	var gap : Vector2 = _link_gap()
	_add_wall(body, Rect2(x, 0.0, t, gap.x))
	_add_wall(body, Rect2(x, gap.y, t, _size.y - gap.y))

func _add_wall(body: StaticBody2D, rect: Rect2) -> void:
	var shape : CollisionShape2D  = CollisionShape2D.new()
	var box   : RectangleShape2D  = RectangleShape2D.new()
	box.size       = rect.size
	shape.shape    = box
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)

## Wire up the way out. An authored scene can place its own Area2D named
## "ExitArea" over the doorway in its art; if it has one, that is used and no
## generic exit strip is built.
func _build_exit_area() -> void:
	var authored : Area2D = get_node_or_null("ExitArea") as Area2D
	if authored != null:
		authored.body_entered.connect(_on_exit_body_entered)
		return
	var gap  : Vector2 = _door_gap()
	var area : Area2D  = Area2D.new()
	add_child(area)
	var shape : CollisionShape2D = CollisionShape2D.new()
	var box   : RectangleShape2D = RectangleShape2D.new()
	box.size       = Vector2(gap.y - gap.x, 24.0)
	shape.shape    = box
	shape.position = Vector2(_size.x * 0.5, _size.y + 14.0)
	area.add_child(shape)
	area.body_entered.connect(_on_exit_body_entered)

## Wire up the doorway to the linked room, as _build_exit_area does for the way
## out: an authored Area2D named "LinkArea" is used if present, otherwise a
## strip is built just beyond the gap in the side wall.
func _build_link_area() -> void:
	if not has_link():
		return
	var authored : Area2D = get_node_or_null("LinkArea") as Area2D
	if authored != null:
		authored.body_entered.connect(_on_link_body_entered)
		return
	var gap  : Vector2 = _link_gap()
	var area : Area2D  = Area2D.new()
	add_child(area)
	var shape : CollisionShape2D = CollisionShape2D.new()
	var box   : RectangleShape2D = RectangleShape2D.new()
	box.size       = Vector2(24.0, gap.y - gap.x)
	shape.shape    = box
	var x : float = _size.x + 14.0 if _link_side == InteriorDefinition.SIDE_EAST else -14.0
	shape.position = Vector2(x, _size.y * 0.5)
	area.add_child(shape)
	area.body_entered.connect(_on_link_body_entered)

func _on_link_body_entered(body: Node) -> void:
	if body == player_ref:
		link_requested.emit(_link_id)

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
	# indoors, grey concrete in a garage, grass in a back yard.
	var floor_a : Color = Color(0.93, 0.93, 0.93)
	var floor_b : Color = Color(0.85, 0.85, 0.87)
	match _floor:
		"concrete":
			floor_a = Color(0.62, 0.62, 0.60)
			floor_b = Color(0.57, 0.57, 0.55)
		"grass":
			floor_a = Color(0.45, 0.66, 0.36)
			floor_b = Color(0.41, 0.61, 0.33)
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
	# Open the doorway in the south wall and mark it.
	var gap : Vector2 = _door_gap()
	draw_rect(Rect2(gap.x, _size.y - WALL_THICKNESS, gap.y - gap.x, WALL_THICKNESS * 2.0), Color.BLACK)
	draw_rect(Rect2(gap.x, _size.y - 5.0, gap.y - gap.x, 9.0), Color(0.55, 0.35, 0.18))
	draw_string(ThemeDB.fallback_font, Vector2(gap.x - 4.0, _size.y + 28.0), "EXIT",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))
	# The doorway through to the linked room, signed with where it goes.
	if has_link():
		var lg : Vector2 = _link_gap()
		var wx : float   = _size.x - WALL_THICKNESS if _link_side == InteriorDefinition.SIDE_EAST else -WALL_THICKNESS
		draw_rect(Rect2(wx, lg.x, WALL_THICKNESS * 2.0, lg.y - lg.x), Color.BLACK)
		var mx : float = _size.x - 5.0 if _link_side == InteriorDefinition.SIDE_EAST else -4.0
		draw_rect(Rect2(mx, lg.x, 9.0, lg.y - lg.x), Color(0.55, 0.35, 0.18))
		var font : Font  = ThemeDB.fallback_font
		var text : String = _link_label.to_upper() + (" →" if _link_side == InteriorDefinition.SIDE_EAST else "")
		if _link_side == InteriorDefinition.SIDE_WEST:
			text = "← " + text
		var tw : float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var tx : float = _size.x - tw - 16.0 if _link_side == InteriorDefinition.SIDE_EAST else 16.0
		draw_string(font, Vector2(tx, lg.x - 8.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.25, 0.25, 0.25))
	# Bed (home only).
	if _is_home:
		draw_rect(_bed_rect, Color(0.55, 0.7, 0.95))
		draw_rect(Rect2(_bed_rect.position, Vector2(_bed_rect.size.x, 14.0)), Color(0.92, 0.92, 0.97))
		draw_string(ThemeDB.fallback_font, _bed_rect.position + Vector2(0.0, -6.0),
				"Bed — E to sleep", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.9))
