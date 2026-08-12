extends Node2D
## Orbits the player and points home when they're running low. Appears once
## health or energy drops to LOW_THRESHOLD so the player can find their bed
## before collapsing. Hidden indoors and when no home has been chosen.

const ORBIT_RADIUS  := 48.0    # outside the delivery/drop-pad arrows
const LOW_THRESHOLD := 3       # HP or energy at or below this shows the arrow
const PULSE_SPEED   := 4.0

var _pulse : float = 0.0

func _process(delta: float) -> void:
	var player = get_parent()
	if player.in_interior or player.home_door_node == null:
		visible = false
		return
	if GameManager.hp > LOW_THRESHOLD and GameManager.energy > LOW_THRESHOLD:
		visible = false
		return

	visible = true
	var target : Vector2 = player.home_door_node.global_position
	var to_home : Vector2 = target - player.global_position
	if to_home.length() < 1.0:
		visible = false
		return
	var dir : Vector2 = to_home.normalized()
	position = dir * ORBIT_RADIUS
	rotation = dir.angle()
	_pulse = fmod(_pulse + delta * PULSE_SPEED, TAU)
	queue_redraw()

func _draw() -> void:
	# Same geometry as the delivery / drop-pad arrows; only the colour and the
	# soft pulse set it apart.
	var a : float = 0.65 + 0.35 * sin(_pulse)
	var body : PackedVector2Array = PackedVector2Array([
		Vector2( 10,  0),
		Vector2( -5, -5),
		Vector2( -2,  0),
		Vector2( -5,  5),
	])
	draw_colored_polygon(body, Color(0.25, 0.9, 0.35, a))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.05, 0.35, 0.1, 0.6), 1.0)
