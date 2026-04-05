extends Node2D
## Animates a package arcing from the player to a building door.

var _from    : Vector2
var _to      : Vector2
var _target          # Building node
var _progress := 0.0
var _speed    := 2.2   # progress units per second (0→1)
var _done     := false

func launch(from: Vector2, to: Vector2, target: Node2D) -> void:
	global_position = from
	_from    = from
	_to      = to
	_target  = target
	_progress = 0.0
	_done     = false

func _process(delta: float) -> void:
	if _done:
		return

	_progress += delta * _speed
	if _progress >= 1.0:
		_progress = 1.0
		_done     = true
		if _target and is_instance_valid(_target):
			_target.receive_package(global_position)
		queue_free()
		return

	var t    := _progress
	var pos  := _from.lerp(_to, t)
	var arc  := -sin(t * PI) * 40.0   # arc height in pixels
	global_position = pos + Vector2(0, arc)
	rotation = t * TAU * 1.5
	queue_redraw()

func _draw() -> void:
	# Little brown box
	draw_rect(Rect2(-5, -5, 10, 10), Color("#c87820"))
	draw_rect(Rect2(-5, -5, 10, 10), Color("#8b4513"), false, 1.0)
	# Cross straps
	draw_line(Vector2(-5, 0), Vector2(5,  0), Color("#8b4513"), 0.8)
	draw_line(Vector2( 0,-5), Vector2(0,  5), Color("#8b4513"), 0.8)
