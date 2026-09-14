extends Node2D
## Draws a small procedural cat, seen from above: a slim body, a wedge head with
## pointed ears, and a long tail that sways as it walks. Placeholder art in the
## same spirit as DogSprite and BirdSprite — drop in a sprite sheet later and
## swap this for a Sprite2D.
##
## The parent sets `facing` (a unit vector) rather than rotating this node, so
## the cat always reads as viewed from above instead of spinning on the spot.
##
## Kept visually distinct from a dog at a glance: narrower body, triangular
## ears rather than round, and a long tail instead of a stub.

var coat_color   : Color = Color("#8a8a8a")
var accent_color : Color = Color("#e8e2d8")   # belly / paws / muzzle
var facing       : Vector2 = Vector2.RIGHT
## Sways the tail and shifts the legs while walking, so a moving cat reads as
## alive at a glance.
var walk_phase   : float = 0.0

func _ready() -> void:
	queue_redraw()

func set_facing(dir: Vector2) -> void:
	if dir.length_squared() < 0.001:
		return
	facing = dir.normalized()
	queue_redraw()

func _draw() -> void:
	var dark  : Color = coat_color.darkened(0.30)
	var light : Color = coat_color.lightened(0.15)
	# Body axis follows the facing direction, so the cat points where it walks.
	var f     : Vector2 = facing
	var side  : Vector2 = Vector2(-f.y, f.x)
	var sway  : float   = sin(walk_phase)
	var step  : float   = sin(walk_phase) * 0.8

	# Tail — long, drawn as three segments so it curves rather than sticking out
	# straight. This is the clearest read against a dog's short stub.
	var t0 : Vector2 = -f * 5.0
	var t1 : Vector2 = -f * 9.5  + side * sway * 1.8
	var t2 : Vector2 = -f * 13.0 + side * sway * 3.6
	var t3 : Vector2 = -f * 15.5 + side * sway * 5.2
	draw_line(t0, t1, coat_color, 1.5)
	draw_line(t1, t2, coat_color, 1.3)
	draw_line(t2, t3, dark,       1.1)

	# Legs, two per side, offset along the body axis.
	for along in [2.6, -2.8]:
		for s in [-1.0, 1.0]:
			var hip : Vector2 = f * along + side * (2.0 * s)
			draw_line(hip, hip + side * (1.5 * s) + f * step * s, dark, 1.2)

	# Body — narrower than a dog's, so the silhouette reads as a cat.
	draw_colored_polygon(PackedVector2Array([
		f *  5.5 + side *  1.9,
		f *  5.5 + side * -1.9,
		f * -5.5 + side * -2.4,
		f * -5.5 + side *  2.4,
	]), coat_color)
	# A paler belly stripe down the centre line.
	draw_line(f * 4.5, f * -4.5, accent_color, 1.4)

	# Head — a small circle at the front.
	var head : Vector2 = f * 7.0
	draw_circle(head, 3.0, light)
	# Ears — triangles rather than the dog's round blobs.
	for s in [-1.0, 1.0]:
		var base_in  : Vector2 = head + side * (0.6 * s) - f * 1.0
		var base_out : Vector2 = head + side * (2.8 * s) - f * 0.4
		var tip      : Vector2 = head + side * (2.4 * s) + f * 2.6
		draw_colored_polygon(PackedVector2Array([base_in, base_out, tip]), dark)
	# Muzzle.
	draw_circle(head + f * 2.2, 1.2, accent_color)
