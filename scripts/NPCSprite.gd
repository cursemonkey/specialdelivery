class_name NPCSprite
extends Node2D
## Draws a villager sprite procedurally (same approach as FootSprite.gd).
## Palette is exported so every NPC can look distinct without new art.
## NPCBase calls set_facing() whenever facing or walk frame changes.

@export var shirt_color : Color = Color("#c46a5a")
@export var pants_color : Color = Color("#4a4a5e")
@export var hair_color  : Color = Color("#3a2a1a")
@export var skin_color  : Color = Color("#e8c8a0")
# Background villagers set this: a blank, expressionless "NPC-meme" face
# (dead dot eyes + a flat straight mouth) instead of the direction-aware eyes.
@export var meme_style  : bool  = false

var _facing     : Vector2 = Vector2.DOWN
var _walk_frame : int     = 0

func set_facing(f: Vector2, frame: int) -> void:
	_facing     = f
	_walk_frame = frame
	queue_redraw()

func _draw() -> void:
	var leg_bob : int = [0, 3, 0, -3][_walk_frame % 4]

	# Shadow
	_draw_ellipse(Vector2(0, 10), Vector2(7, 3), Color(0, 0, 0, 0.18))

	# Shoes
	draw_rect(Rect2(-5, 14 + leg_bob, 4, 3), Color("#2c1a0e"))
	draw_rect(Rect2( 1, 14 - leg_bob, 4, 3), Color("#2c1a0e"))

	# Legs
	draw_rect(Rect2(-5, 9,  4, 6 + leg_bob), pants_color)
	draw_rect(Rect2( 1, 9,  4, 6 - leg_bob), pants_color)

	# Shirt / body
	draw_rect(Rect2(-5, -2, 10, 11), shirt_color)

	# Head
	draw_rect(Rect2(-5, -13, 10, 11), skin_color)

	# Hair
	draw_rect(Rect2(-5, -16, 10, 4), hair_color)

	if meme_style:
		_draw_meme_face()
	elif _facing != Vector2.UP:
		# Direction-aware eyes (hidden when facing away).
		var eye_offset : Vector2 = Vector2.ZERO
		if   _facing == Vector2.DOWN: eye_offset = Vector2(0, 1)
		elif _facing.x > 0:           eye_offset = Vector2(1, 0)
		elif _facing.x < 0:           eye_offset = Vector2(-1, 0)
		draw_rect(Rect2(-3 + eye_offset.x, -9 + eye_offset.y, 2, 2), Color("#2c1a0e"))
		draw_rect(Rect2( 1 + eye_offset.x, -9 + eye_offset.y, 2, 2), Color("#2c1a0e"))

# Blank, staring "NPC meme" face — always front-facing regardless of heading:
# two small dead eyes and a flat, straight mouth.
func _draw_meme_face() -> void:
	var feature : Color = Color("#3a3a3a")
	draw_rect(Rect2(-3, -9, 2, 2), feature)   # left eye
	draw_rect(Rect2( 1, -9, 2, 2), feature)   # right eye
	draw_rect(Rect2(-2, -5, 4, 1), feature)   # flat straight mouth

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts : PackedVector2Array = PackedVector2Array()
	for i in 32:
		var a : float = TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
