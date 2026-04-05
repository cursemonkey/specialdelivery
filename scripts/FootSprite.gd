extends Node2D
## Draws the on-foot kid sprite procedurally using canvas commands.
## Call set_facing() each frame from Player.gd.

var _facing     := Vector2.DOWN
var _walk_frame := 0

func set_facing(f: Vector2, frame: int) -> void:
	_facing     = f
	_walk_frame = frame
	queue_redraw()

func _draw() -> void:
	var f := _walk_frame
	var leg_bob: int = [0, 3, 0, -3][f]

	# Shadow
	draw_player_ellipse(Vector2(0, 10), Vector2(7, 3), Color(0, 0, 0, 0.18))

	# Shoes
	draw_rect(Rect2(-5, 14 + leg_bob, 4, 3), Color("#2c1a0e"))
	draw_rect(Rect2( 1, 14 - leg_bob, 4, 3), Color("#2c1a0e"))

	# Legs
	draw_rect(Rect2(-5, 9,  4, 6 + leg_bob), Color("#3d5a8a"))
	draw_rect(Rect2( 1, 9,  4, 6 - leg_bob), Color("#3d5a8a"))

	# Shirt / body
	draw_rect(Rect2(-5, -2, 10, 11), Color("#5b8ed4"))

	# Backpack (package indicator)
	if GameManager.packages > 0:
		draw_rect(Rect2(4, -1, 5, 8), Color("#e8a040"))
		draw_rect(Rect2(4, -1, 5, 2), Color("#c07820"))

	# Head
	draw_rect(Rect2(-5, -13, 10, 11), Color("#e8c8a0"))

	# Hair
	draw_rect(Rect2(-5, -16, 10,  4), Color("#5c3317"))

	# Eyes (direction-aware)
	var eye_offset := Vector2.ZERO
	if   _facing == Vector2.DOWN:  eye_offset = Vector2(0,  1)
	elif _facing == Vector2.UP:    eye_offset = Vector2(0, -1)
	elif _facing.x > 0:           eye_offset = Vector2( 1, 0)
	else:                          eye_offset = Vector2(-1, 0)

	draw_rect(Rect2(-3 + eye_offset.x, -9 + eye_offset.y, 2, 2), Color("#2c1a0e"))
	draw_rect(Rect2( 1 + eye_offset.x, -9 + eye_offset.y, 2, 2), Color("#2c1a0e"))

func draw_player_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
