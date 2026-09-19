extends Node2D
## Visual for a Salvage collectable. The parent Salvage node supplies the item
## id, a bob phase, and the draw alpha that handles the despawn flicker.

func _draw() -> void:
	var parent = get_parent()
	if parent == null:
		return
	var bob   : float  = parent.get_bob()      if parent.has_method("get_bob")      else 0.0
	var id    : String = parent.get_item_id()  if parent.has_method("get_item_id")  else "scrap"
	var alpha : float  = parent.draw_alpha()   if parent.has_method("draw_alpha")   else 1.0
	if alpha <= 0.01:
		return

	# A gentle rise and fall so loose salvage reads as collectable rather than
	# as more road furniture. During the collect pop the parent is already
	# moving the whole node upward, so the idle bob steps aside.
	var popping : bool  = parent.is_collecting() if parent.has_method("is_collecting") else false
	var lift    : float = 0.0 if popping else sin(bob) * 1.5

	if not popping:
		# Soft ground shadow, anchored where the piece actually sits. Skipped
		# mid-pop: the piece has left the ground, so its shadow shouldn't ride up with it.
		draw_circle(Vector2(0, 3), 5.0, Color(0, 0, 0, 0.18 * alpha))
		# Faint glint ring, so a piece is visible against dark asphalt at night.
		draw_arc(Vector2(0, lift), 8.0, 0.0, TAU, 16, Color(1.0, 0.95, 0.70, 0.22 * alpha), 1.0)

	if id == "bolts":
		_draw_bolts(lift, alpha)
	else:
		_draw_scrap(lift, alpha)

## Scrap metal: a bent sheet-metal offcut with a lighter torn edge.
func _draw_scrap(lift: float, alpha: float) -> void:
	var body := PackedVector2Array([
		Vector2(-6.0, 1.5 + lift),
		Vector2(-2.5, -4.0 + lift),
		Vector2( 5.5, -2.0 + lift),
		Vector2( 3.0,  3.5 + lift),
	])
	draw_colored_polygon(body, Color(0.62, 0.64, 0.68, alpha))
	# Torn top edge catches the light.
	draw_line(Vector2(-2.5, -4.0 + lift), Vector2(5.5, -2.0 + lift),
		Color(0.86, 0.88, 0.92, alpha), 1.4)
	# Rust streak along the fold.
	draw_line(Vector2(-4.0, 0.0 + lift), Vector2(2.0, 1.0 + lift),
		Color(0.52, 0.33, 0.20, 0.85 * alpha), 1.2)
	draw_polyline(body + PackedVector2Array([body[0]]),
		Color(0.28, 0.29, 0.33, 0.9 * alpha), 1.0)

## Bag of bolts: a small sack with a few bolts spilling at the mouth.
func _draw_bolts(lift: float, alpha: float) -> void:
	var sack := PackedVector2Array([
		Vector2(-4.5,  3.0 + lift),
		Vector2(-3.5, -2.0 + lift),
		Vector2( 3.5, -2.0 + lift),
		Vector2( 4.5,  3.0 + lift),
	])
	draw_colored_polygon(sack, Color(0.55, 0.45, 0.32, alpha))
	# Tie at the neck of the sack.
	draw_line(Vector2(-3.5, -2.0 + lift), Vector2(3.5, -2.0 + lift),
		Color(0.36, 0.28, 0.19, alpha), 1.6)
	draw_polyline(sack + PackedVector2Array([sack[0]]),
		Color(0.32, 0.25, 0.17, 0.9 * alpha), 1.0)
	# Three bolt heads poking out of the top.
	var heads : Array[Vector2] = [
		Vector2(-2.2, -3.6 + lift),
		Vector2( 0.2, -4.4 + lift),
		Vector2( 2.4, -3.4 + lift),
	]
	for h in heads:
		draw_circle(h, 1.7, Color(0.70, 0.72, 0.76, alpha))
		draw_circle(h, 0.7, Color(0.44, 0.46, 0.50, alpha))
