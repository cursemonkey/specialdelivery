extends Node2D
## Visual for a Pickup. Parent Pickup node provides pulse, kind & angle.

func _draw() -> void:
	var parent = get_parent()
	if parent == null:
		return
	var pulse : float = parent.get_pulse() if parent.has_method("get_pulse") else 0.0
	var kind         = parent.get_kind()   if parent.has_method("get_kind")  else 0
	var angle : float = parent.get_angle() if parent.has_method("get_angle") else 0.0

	match kind:
		Pickup.Kind.RAMP:    _draw_ramp(pulse, angle)
		Pickup.Kind.PUDDLE:  _draw_puddle(pulse)
		_:                   _draw_pothole()

## Wedge ramp: a triangle rising toward `angle`, with tread stripes across it.
## Drawn in the ramp's local frame then rotated, so it reads as a launch lip
## pointing the way the player will be flung.
func _draw_ramp(pulse: float, angle: float) -> void:
	var alpha : float = 0.85 + 0.15 * sin(pulse)
	var len   : float = 11.0    # base to lip
	var half  : float = 7.0     # half-width at the base

	var fwd  := Vector2(cos(angle), sin(angle))
	var side := fwd.orthogonal()

	# Wedge body — widest and lowest at the back, tapering to the raised lip.
	var back_l := -fwd * len * 0.5 + side * half
	var back_r := -fwd * len * 0.5 - side * half
	var lip_l  :=  fwd * len * 0.5 + side * half * 0.55
	var lip_r  :=  fwd * len * 0.5 - side * half * 0.55

	var body := PackedVector2Array([back_l, back_r, lip_r, lip_l])
	draw_colored_polygon(body, Color(0.55, 0.40, 0.26, alpha))          # ramp deck

	# Tread stripes — brighter toward the lip to sell the rise.
	for i in 3:
		var t : float = 0.25 + 0.25 * i
		var w : float = lerpf(half, half * 0.55, t)
		var p : Vector2 = -fwd * len * 0.5 + fwd * len * t
		draw_line(p + side * w, p - side * w,
			Color(0.78, 0.62, 0.40, alpha * 0.9), 1.5)

	# Raised lip highlight and outline.
	draw_line(lip_l, lip_r, Color(1.0, 0.86, 0.55, alpha), 2.0)
	draw_polyline(PackedVector2Array([back_l, back_r, lip_r, lip_l, back_l]),
		Color(0.34, 0.23, 0.14, 0.95), 1.0)

## Puddle: a shallow blue oval with a shifting sheen.
func _draw_puddle(pulse: float) -> void:
	var alpha : float = 0.70 + 0.12 * sin(pulse)
	var rx    : float = 10.0
	var ry    : float = 6.0

	draw_set_transform(Vector2.ZERO, 0.0, Vector2(rx / ry, 1.0))
	draw_circle(Vector2.ZERO, ry, Color(0.28, 0.52, 0.82, alpha))
	draw_arc(Vector2.ZERO, ry, 0, TAU, 20, Color(0.18, 0.36, 0.62, 0.9), 1.0)
	# Sheen — a small offset highlight that drifts with the pulse.
	draw_circle(Vector2(-ry * 0.35, -ry * 0.35) + Vector2(0.0, 0.4 * sin(pulse)),
		ry * 0.28, Color(0.75, 0.90, 1.0, alpha * 0.55))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Pothole: a flat black circle with a crumbled asphalt rim.
func _draw_pothole() -> void:
	var r : float = 7.0
	draw_circle(Vector2.ZERO, r * 1.15, Color(0.30, 0.28, 0.26, 0.55))   # broken rim
	draw_circle(Vector2.ZERO, r, Color(0.06, 0.06, 0.07, 0.95))          # the hole
	draw_arc(Vector2.ZERO, r, 0, TAU, 18, Color(0.16, 0.15, 0.14, 0.9), 1.0)

func _process(_d: float) -> void:
	queue_redraw()
