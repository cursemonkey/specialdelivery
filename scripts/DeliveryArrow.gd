extends Node2D
## Orbits the player and points toward the nearest undelivered target.

const ORBIT_RADIUS := 28.0

func _ready() -> void:
	queue_redraw()

func _process(_delta: float) -> void:
	var player = get_parent()

	if GameManager.packages <= 0:
		visible = false
		return

	var targets : Array = player.delivery_targets

	var nearest        = null
	var nearest_dist   := INF

	for t in targets:
		if t.is_delivered:
			continue
		var d : float = player.global_position.distance_to(t.door_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest      = t

	if nearest == null:
		visible = false
		return

	visible = true
	var dir : Vector2 = (nearest.door_position - player.global_position).normalized()
	position = dir * ORBIT_RADIUS
	rotation = dir.angle()

func _draw() -> void:
	var c := Color(0.973, 0.816, 0.376, 0.5)
	# Arrow body pointing right (+X); rotation set each frame handles direction
	draw_colored_polygon(PackedVector2Array([
		Vector2( 10,  0),
		Vector2( -5, -5),
		Vector2( -2,  0),
		Vector2( -5,  5),
	]), c)
	# Outline for visibility against varied backgrounds
	draw_polyline(PackedVector2Array([
		Vector2( 10,  0),
		Vector2( -5, -5),
		Vector2( -2,  0),
		Vector2( -5,  5),
		Vector2( 10,  0),
	]), Color(0.4, 0.3, 0.0, 0.6), 1.0)
