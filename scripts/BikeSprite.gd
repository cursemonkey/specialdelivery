extends Node2D
## Draws the on-bike player sprite procedurally using canvas commands.
## Rotated each frame by Player.gd to match bike_angle.

func _ready() -> void:
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	# Shadow
	_draw_ellipse(Vector2(0, 2), Vector2(7, 13), Color(0, 0, 0, 0.18))

	# Back wheel
	draw_rect(Rect2(-3, 7, 6, 10), Color("#2c2c2c"))
	draw_rect(Rect2(-1, 9, 2, 6), Color("#aaaaaa"))

	# Front wheel
	draw_rect(Rect2(-3, -17, 6, 10), Color("#2c2c2c"))
	draw_rect(Rect2(-1, -15, 2, 6), Color("#aaaaaa"))

	# Bike frame (main tube)
	draw_rect(Rect2(-1, -7, 2, 14), Color("#e04020"))

	# Handlebars
	draw_rect(Rect2(-6, -10, 12, 2), Color("#888888"))

	# Seat
	draw_rect(Rect2(-3, 5, 6, 3), Color("#3c1a0a"))

	# Rider body (shirt)
	draw_rect(Rect2(-4, -8, 8, 10), Color("#5b8ed4"))

	# Rider head
	draw_rect(Rect2(-4, -16, 8, 9), Color("#e8c8a0"))

	# Hair
	draw_rect(Rect2(-4, -19, 8, 4), Color("#5c3317"))

	# Package indicator (backpack)
	if GameManager.packages > 0:
		draw_rect(Rect2(4, -5, 5, 7), Color("#e8a040"))
		draw_rect(Rect2(4, -5, 5, 2), Color("#c07820"))

func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
