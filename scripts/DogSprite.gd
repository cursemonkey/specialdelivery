extends Node2D
## Draws a small procedural dog, seen from above: body, head, tail and legs in
## a per-dog coat colour. Placeholder art in the same spirit as BirdSprite —
## drop in a sprite sheet later and swap this for a Sprite2D.
##
## The parent sets `facing` (a unit vector) rather than rotating this node, so
## the dog always reads as viewed from above instead of spinning on the spot.

var coat_color   : Color = Color("#8a6242")
var collar_color : Color = Color("#c0392b")
var facing       : Vector2 = Vector2.RIGHT
## Bobs while walking so a moving dog reads as alive at a glance.
var walk_phase   : float = 0.0

func _ready() -> void:
	queue_redraw()

func set_facing(dir: Vector2) -> void:
	if dir.length_squared() < 0.001:
		return
	facing = dir.normalized()
	queue_redraw()

func _draw() -> void:
	var dark  : Color = coat_color.darkened(0.28)
	var light : Color = coat_color.lightened(0.12)
	# Body axis follows the facing direction, so the dog points where it walks.
	var f     : Vector2 = facing
	var side  : Vector2 = Vector2(-f.y, f.x)
	var bob   : float   = sin(walk_phase) * 0.6

	# Tail — a short line trailing behind the body.
	draw_line(-f * 5.0, -f * 9.0 + side * (2.0 + bob), dark, 1.6)
	# Legs, two per side, offset along the body axis.
	for along in [3.0, -3.0]:
		for s in [-1.0, 1.0]:
			var hip : Vector2 = f * along + side * (2.6 * s)
			draw_line(hip, hip + side * (1.8 * s) + f * bob * s, dark, 1.4)
	# Body — an ellipse approximated by a rotated rounded rect.
	draw_colored_polygon(PackedVector2Array([
		f *  6.0 + side *  2.4,
		f *  6.0 + side * -2.4,
		f * -6.0 + side * -3.0,
		f * -6.0 + side *  3.0,
	]), coat_color)
	# Head at the front, slightly wider than the neck.
	var head : Vector2 = f * 7.5
	draw_circle(head, 3.4, light)
	# Ears.
	draw_circle(head + side * 2.6 - f * 0.6, 1.4, dark)
	draw_circle(head - side * 2.6 - f * 0.6, 1.4, dark)
	# Snout.
	draw_circle(head + f * 2.6, 1.5, dark)
	# Collar, between head and body.
	draw_line(f * 4.2 + side * 2.2, f * 4.2 - side * 2.2, collar_color, 1.6)
