extends Node2D
## Draws a small yellow bird arrow. Parent sets rotation to match movement direction.

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var c  := Color("#f8d060")
	var c2 := Color("#d4a020")
	# Body — filled triangle pointing right (+X), rotation handles direction
	draw_colored_polygon(PackedVector2Array([
		Vector2( 7,  0),
		Vector2(-5, -4),
		Vector2(-2,  0),
		Vector2(-5,  4),
	]), c)
	# Wing lines
	draw_line(Vector2(-1, 0), Vector2( 4, -3), c2, 1.0)
	draw_line(Vector2(-1, 0), Vector2( 4,  3), c2, 1.0)
