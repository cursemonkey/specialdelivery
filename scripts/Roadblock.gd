extends StaticBody2D
## A construction barricade placed at a road intersection: a long thin board
## (thickness × length = _size.x × _size.y) rotated diagonally in one direction
## or the other. It blocks a diagonal across the junction, forcing a detour
## around the open corners rather than fully sealing the road.

var _size : Vector2 = Vector2(24, 120)

func setup(block_size: Vector2) -> void:
	_size = block_size
	var shape : CollisionShape2D = CollisionShape2D.new()
	var box   : RectangleShape2D = RectangleShape2D.new()
	box.size    = _size
	shape.shape = box
	add_child(shape)
	# Diagonal in either direction.
	rotation = (PI / 4.0) if randf() < 0.5 else (-PI / 4.0)
	z_index  = 5
	queue_redraw()

func _draw() -> void:
	var w    : float = _size.x   # thickness
	var h    : float = _size.y   # length
	var rect : Rect2 = Rect2(-w * 0.5, -h * 0.5, w, h)

	# Shadow.
	draw_rect(Rect2(-w * 0.5 + 3.0, -h * 0.5 + 3.0, w, h), Color(0, 0, 0, 0.2))

	# Hazard board: orange base with white bands along its length.
	draw_rect(rect, Color(0.9, 0.5, 0.1))
	var band : float = 12.0
	var y    : float = -h * 0.5
	var on   : bool  = false
	while y < h * 0.5:
		if on:
			draw_rect(Rect2(-w * 0.5, y, w, minf(band, h * 0.5 - y)), Color(0.95, 0.95, 0.95))
		y += band
		on = not on
	draw_rect(rect, Color(0.1, 0.1, 0.1), false, 2.0)

	# A traffic cone at each end of the barrier.
	for cy in [-h * 0.5 - 8.0, h * 0.5 + 8.0]:
		var tip : float = cy - 8.0 if cy < 0.0 else cy + 8.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(0.0, tip), Vector2(-6.0, cy), Vector2(6.0, cy),
		]), Color(0.95, 0.4, 0.05))
