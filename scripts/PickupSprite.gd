extends Node2D
## Visual for a Pickup. Parent Pickup node provides pulse & kind.

func _draw() -> void:
	var parent = get_parent()
	if parent == null:
		return
	var pulse : float = parent.get_pulse() if parent.has_method("get_pulse") else 0.0
	var kind  = parent.get_kind()   if parent.has_method("get_kind")  else 0

	var alpha := 0.75 + 0.25 * sin(pulse)
	var scale_v := 1.0 + 0.08 * sin(pulse + 1.0)

	if kind == 0:  # TRICK — blue square
		var c := Color(0.24, 0.63, 1.0, alpha)
		var s := 5.0 * scale_v
		draw_rect(Rect2(-s, -s, s * 2, s * 2), c)
		draw_rect(Rect2(-s, -s, s * 2, s * 2), Color(0.0, 0.5, 1.0, 0.9), false, 1.0)
	else:          # TRAP — red circle
		var c := Color(1.0, 0.24, 0.24, alpha)
		var r := 5.0 * scale_v
		draw_circle(Vector2.ZERO, r, c)
		draw_arc(Vector2.ZERO, r, 0, TAU, 16, Color(0.8, 0.0, 0.0, 0.9), 1.0)

func _process(_d: float) -> void:
	queue_redraw()
