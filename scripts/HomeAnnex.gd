extends "res://scripts/HomeInterior.gd"
## A player home's garage (or, for the townhouse, its back yard): the room
## through the doorway in the home's east wall. Its own doorway in the west
## wall leads back into the house, and its south doorway out to the street like
## any other room.
##
## The workbench is where the player crafts (see ItemRegistry.RECIPES). It sits
## at a Marker2D named "Workbench" when the scene has one, otherwise centre-top
## of the room, where the procedural _draw paints it. Like HomeInterior, the
## room paints itself procedurally until its Background sprite gets art.

const BENCH_SIZE     : Vector2 = Vector2(96, 36)
const BENCH_INTERACT : float   = 56.0

var _bench_rect : Rect2 = Rect2()

func build(def: InteriorDefinition, is_home: bool) -> void:
	super.build(def, is_home)
	var m : Marker2D = get_node_or_null("Workbench") as Marker2D
	var centre : Vector2 = m.position if m != null else Vector2(_size.x * 0.5, 26.0 + BENCH_SIZE.y * 0.5)
	_bench_rect = Rect2(centre - BENCH_SIZE * 0.5, BENCH_SIZE)
	_build_bench_body()
	queue_redraw()

## True when `world_pos` is close enough to the workbench to use it.
func workbench_near(world_pos: Vector2) -> bool:
	var centre : Vector2 = global_position + _bench_rect.position + _bench_rect.size * 0.5
	return world_pos.distance_to(centre) <= BENCH_INTERACT

## Solid in the procedural room so the player walks up to it rather than
## through it. Authored rooms draw the bench's collision with their walls.
func _build_bench_body() -> void:
	if not _is_procedural():
		return
	var body : StaticBody2D = StaticBody2D.new()
	add_child(body)
	_add_wall(body, _bench_rect)

func _draw() -> void:
	super._draw()
	if not _is_procedural():
		return
	# Timber top, darker legs, a couple of tools lying on it.
	draw_rect(_bench_rect, Color(0.62, 0.43, 0.24))
	draw_rect(Rect2(_bench_rect.position, Vector2(_bench_rect.size.x, 8.0)), Color(0.74, 0.54, 0.32))
	draw_rect(Rect2(_bench_rect.position + Vector2(18.0, 13.0), Vector2(22.0, 5.0)), Color(0.45, 0.47, 0.52))
	draw_rect(Rect2(_bench_rect.position + Vector2(58.0, 12.0), Vector2(6.0, 14.0)), Color(0.45, 0.47, 0.52))
	draw_string(ThemeDB.fallback_font, _bench_rect.position + Vector2(-8.0, _bench_rect.size.y + 16.0),
			"Workbench — E to craft", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.15, 0.15))
