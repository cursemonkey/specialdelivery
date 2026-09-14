extends Node2D
## Draws a small procedural bunny, seen from above: a rounded body, two long
## ears and a round tail. Placeholder art in the same spirit as BirdSprite and
## CatSprite — drop in a sprite sheet later and swap this for a Sprite2D.
##
## Like DogSprite and CatSprite (and unlike BirdSprite, which the parent rotates
## outright), the parent sets `facing` rather than rotating this node, so the
## bunny always reads as viewed from above.
##
## `hop_height` is set by the parent through the arc of each hop. It scales the
## body and offsets the shadow, which is what sells the hop from a top-down
## camera — the bunny appears to leave the ground rather than slide along it.

var coat_color   : Color   = Color("#b8a894")
var accent_color : Color   = Color("#fdf6ec")   # tail, inner ears, belly
var facing       : Vector2 = Vector2.RIGHT
## 0 on the ground, rising through the arc of a hop. Set by Bunny.gd.
var hop_height   : float   = 0.0 :
	set(value):
		hop_height = value
		queue_redraw()

func _ready() -> void:
	queue_redraw()

func set_facing(dir: Vector2) -> void:
	if dir.length_squared() < 0.001:
		return
	facing = dir.normalized()
	queue_redraw()

func _draw() -> void:
	var dark : Color   = coat_color.darkened(0.30)
	var f    : Vector2 = facing
	var side : Vector2 = Vector2(-f.y, f.x)
	# Airborne: the body grows slightly and lifts off its shadow.
	var lift  : float = hop_height
	var scale : float = 1.0 + lift * 0.06

	# Shadow stays on the ground, so height reads even from straight above.
	if lift > 0.05:
		draw_circle(Vector2.ZERO, 3.4, Color(0, 0, 0, 0.18))

	var centre : Vector2 = -f * lift * 0.35

	# Ears — two long rounded shapes swept back over the body.
	for s in [-1.0, 1.0]:
		var ear_base : Vector2 = centre + f * 3.6 + side * (1.5 * s)
		var ear_tip  : Vector2 = centre + f * 9.0 + side * (2.6 * s)
		draw_line(ear_base, ear_tip, coat_color, 2.0)
		draw_line(ear_base, ear_tip, accent_color, 0.8)

	# Body — a compact rounded shape, wider at the back than the front.
	draw_colored_polygon(PackedVector2Array([
		centre + (f *  4.0 + side *  2.2) * scale,
		centre + (f *  4.0 + side * -2.2) * scale,
		centre + (f * -4.2 + side * -3.0) * scale,
		centre + (f * -4.2 + side *  3.0) * scale,
	]), coat_color)

	# Head, tucked at the front.
	draw_circle(centre + f * 4.4 * scale, 2.6 * scale, coat_color.lightened(0.12))
	# Nose.
	draw_circle(centre + f * 6.4 * scale, 0.9, dark)
	# Hind feet, tucked under while airborne and splayed when sitting.
	var foot_out : float = 2.4 if lift > 0.05 else 3.2
	for s in [-1.0, 1.0]:
		draw_line(centre + f * -2.4 + side * (2.2 * s),
				centre + f * -4.0 + side * (foot_out * s), dark, 1.3)
	# Powder-puff tail.
	draw_circle(centre + f * -4.8 * scale, 1.8, accent_color)
