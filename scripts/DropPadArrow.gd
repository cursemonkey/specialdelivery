extends Node2D
## Orbits the player and points toward the nearest drop pad that has packages waiting.

const ORBIT_RADIUS := 38.0

func _process(_delta: float) -> void:
	var player = get_parent()
	var mgr    = player.drop_pad_manager
	if mgr == null:
		visible = false
		return

	var packages  : Array[int]     = mgr.get_packages()
	var centroids : Array[Vector2] = mgr.get_centroids()

	var nearest_pos  : Vector2 = Vector2.ZERO
	var nearest_dist : float   = INF
	var found        : bool    = false

	for i in packages.size():
		if packages[i] <= 0:
			continue
		var d : float = player.global_position.distance_to(centroids[i])
		if d < nearest_dist:
			nearest_dist = d
			nearest_pos  = centroids[i]
			found        = true

	if not found:
		visible = false
		return

	visible  = true
	var dir  : Vector2 = (nearest_pos - player.global_position).normalized()
	position = dir * ORBIT_RADIUS
	rotation = dir.angle()
	queue_redraw()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2( 10,  0),
		Vector2( -5, -5),
		Vector2( -2,  0),
		Vector2( -5,  5),
	]), Color(0.65, 0.65, 0.65, 0.55))
	draw_polyline(PackedVector2Array([
		Vector2( 10,  0),
		Vector2( -5, -5),
		Vector2( -2,  0),
		Vector2( -5,  5),
		Vector2( 10,  0),
	]), Color(0.25, 0.25, 0.25, 0.7), 1.0)
