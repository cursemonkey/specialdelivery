extends Node2D
## Generic building interior: a white room on a black backdrop with an obvious
## south doorway you walk out of to leave. Built procedurally from an
## InteriorDefinition, so one scene serves every building. If it's the player's
## home, a bed is added — interacting with it (E) sleeps / ends the day.

signal exit_requested
signal sleep_requested

const WALL_THICKNESS : float   = 10.0
const BED_SIZE       : Vector2 = Vector2(72, 46)
const BED_INTERACT   : float   = 44.0

var player_ref : Node2D = null

var _size      : Vector2 = Vector2.ZERO
var _doorway_w : float   = 64.0
var _is_home   : bool    = false
var _bed_rect  : Rect2   = Rect2()

func build(def: InteriorDefinition, is_home: bool) -> void:
	_size      = def.size
	_doorway_w = def.doorway_width
	_is_home   = is_home
	z_index    = -1000   # render behind the player
	if _is_home:
		_bed_rect = Rect2(_size.x * 0.5 - BED_SIZE.x * 0.5, 26.0, BED_SIZE.x, BED_SIZE.y)
	_build_walls()
	_build_exit_area()
	queue_redraw()

## Where the player appears on entering — just inside the south doorway.
func player_spawn_point() -> Vector2:
	return Vector2(_size.x * 0.5, _size.y - 46.0)

## A spot inside the room for the `index`-th of `count` NPCs — spread across the
## upper part of the room, ahead of the player who enters from the south.
func interior_npc_spot(index: int, count: int) -> Vector2:
	var x : float = _size.x * float(index + 1) / float(count + 1)
	return Vector2(x, _size.y * 0.45)

# x-range [left, right] of the doorway gap in the south wall.
func _door_gap() -> Vector2:
	var half : float = _doorway_w * 0.5
	return Vector2(_size.x * 0.5 - half, _size.x * 0.5 + half)

# ── Collision ──────────────────────────────────────────────
func _build_walls() -> void:
	var body : StaticBody2D = StaticBody2D.new()
	add_child(body)
	var t   : float   = WALL_THICKNESS
	var gap : Vector2 = _door_gap()
	_add_wall(body, Rect2(-t, -t, _size.x + 2.0 * t, t))          # north
	_add_wall(body, Rect2(-t, 0.0, t, _size.y))                   # west
	_add_wall(body, Rect2(_size.x, 0.0, t, _size.y))              # east
	_add_wall(body, Rect2(0.0, _size.y, gap.x, t))               # south-left
	_add_wall(body, Rect2(gap.y, _size.y, _size.x - gap.y, t))   # south-right

func _add_wall(body: StaticBody2D, rect: Rect2) -> void:
	var shape : CollisionShape2D  = CollisionShape2D.new()
	var box   : RectangleShape2D  = RectangleShape2D.new()
	box.size       = rect.size
	shape.shape    = box
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)

func _build_exit_area() -> void:
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

func _on_exit_body_entered(body: Node) -> void:
	if body == player_ref:
		exit_requested.emit()

# ── Sleep (home only) ──────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _is_home or player_ref == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_E:
		var bed_center : Vector2 = global_position + _bed_rect.position + _bed_rect.size * 0.5
		if player_ref.global_position.distance_to(bed_center) <= BED_INTERACT:
			sleep_requested.emit()

# ── Draw ───────────────────────────────────────────────────
func _draw() -> void:
	# Black backdrop far beyond the room so the screen stays black around it.
	draw_rect(Rect2(-3000, -3000, _size.x + 6000, _size.y + 6000), Color.BLACK)
	# White room floor with a faint grey checkerboard so motion reads clearly.
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.93, 0.93, 0.93))
	var cell : float = 32.0
	var cols : int   = int(ceil(_size.x / cell))
	var rows : int   = int(ceil(_size.y / cell))
	for j in rows:
		for i in cols:
			if (i + j) % 2 == 1:
				var x : float = float(i) * cell
				var y : float = float(j) * cell
				draw_rect(Rect2(x, y, minf(cell, _size.x - x), minf(cell, _size.y - y)),
						Color(0.85, 0.85, 0.87))
	draw_rect(Rect2(Vector2.ZERO, _size), Color(0.14, 0.14, 0.14), false, WALL_THICKNESS)
	# Open the doorway in the south wall and mark it.
	var gap : Vector2 = _door_gap()
	draw_rect(Rect2(gap.x, _size.y - WALL_THICKNESS, gap.y - gap.x, WALL_THICKNESS * 2.0), Color.BLACK)
	draw_rect(Rect2(gap.x, _size.y - 5.0, gap.y - gap.x, 9.0), Color(0.55, 0.35, 0.18))
	draw_string(ThemeDB.fallback_font, Vector2(gap.x - 4.0, _size.y + 28.0), "EXIT",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.8, 0.8))
	# Bed (home only).
	if _is_home:
		draw_rect(_bed_rect, Color(0.55, 0.7, 0.95))
		draw_rect(Rect2(_bed_rect.position, Vector2(_bed_rect.size.x, 14.0)), Color(0.92, 0.92, 0.97))
		draw_string(ThemeDB.fallback_font, _bed_rect.position + Vector2(0.0, -6.0),
				"Bed — E to sleep", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.85, 0.9))
