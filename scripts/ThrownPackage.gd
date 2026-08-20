extends Node2D
## A parcel arcing from the player to a building door, drawn as a faux-3D box
## that tumbles end over end in flight.
##
## The cube is projected by hand rather than using real 3D: three visible faces
## (front, top, side) are built from a rotating unit cube's corners, which reads
## as solid against the top-down art and costs nothing.

const SPEED       : float = 2.0    # progress units per second (0 → 1)
const ARC_HEIGHT  : float = 46.0   # peak height of the throw, in pixels
const BOX_SIZE    : float = 7.0    # half-extent of the cube
const SPIN_X      : float = 3.4    # tumble (radians over the whole flight)
const SPIN_Y      : float = 2.2    # yaw
const SHADOW_A    : float = 0.22

const FACE_FRONT : Color = Color("#d98a2b")
const FACE_TOP   : Color = Color("#f0a94a")
const FACE_SIDE  : Color = Color("#a8641c")
const EDGE       : Color = Color("#6b3d10")
const TAPE       : Color = Color("#f5deb3")

var _from     : Vector2
var _to       : Vector2
var _target   : Node2D = null
var _progress : float  = 0.0
var _done     : bool   = false

func launch(from: Vector2, to: Vector2, target: Node2D) -> void:
	global_position = from
	_from     = from
	_to       = to
	_target   = target
	_progress = 0.0
	_done     = false
	z_index   = 20   # above the world while it flies

func _process(delta: float) -> void:
	if _done:
		return
	_progress += delta * SPEED
	if _progress >= 1.0:
		_done = true
		if _target != null and is_instance_valid(_target):
			_target.receive_package(global_position)
		queue_free()
		return
	global_position = _from.lerp(_to, _progress)
	queue_redraw()

## Height above the ground at the current point in the arc.
func _height() -> float:
	return sin(_progress * PI) * ARC_HEIGHT

func _draw() -> void:
	var h : float = _height()

	# Ground shadow: stays on the path, shrinking as the box rises.
	var shrink : float = 1.0 - 0.45 * (h / ARC_HEIGHT)
	_draw_ellipse(Vector2.ZERO, Vector2(7.0, 3.0) * shrink, Color(0, 0, 0, SHADOW_A))

	# The box itself is drawn offset upward by the arc height.
	var centre : Vector2 = Vector2(0, -h)
	var ax : float = _progress * SPIN_X * TAU * 0.5
	var ay : float = _progress * SPIN_Y * TAU * 0.5
	_draw_cube(centre, ax, ay)

## Project and draw a unit cube rotated by `ax` (tumble) and `ay` (yaw).
func _draw_cube(centre: Vector2, ax: float, ay: float) -> void:
	var s : float = BOX_SIZE
	# Eight corners of a cube in local 3D space.
	var pts : Array = []
	for c in [Vector3(-1,-1,-1), Vector3(1,-1,-1), Vector3(1,1,-1), Vector3(-1,1,-1),
			  Vector3(-1,-1, 1), Vector3(1,-1, 1), Vector3(1,1, 1), Vector3(-1,1, 1)]:
		pts.append(_project(c * s, ax, ay) + centre)

	# Faces as corner indices, with the colour each should paint.
	var faces : Array = [
		[[0, 1, 2, 3], FACE_FRONT],   # -Z
		[[4, 5, 6, 7], FACE_FRONT],   # +Z
		[[0, 1, 5, 4], FACE_TOP],     # -Y
		[[3, 2, 6, 7], FACE_TOP],     # +Y
		[[0, 3, 7, 4], FACE_SIDE],    # -X
		[[1, 2, 6, 5], FACE_SIDE],    # +X
	]
	# Painter's algorithm: draw back-to-front by average depth.
	var order : Array = []
	for i in faces.size():
		var idx : Array = faces[i][0]
		var depth : float = 0.0
		for j in idx:
			depth += _depth(pts[j])
		order.append({"i": i, "d": depth / 4.0})
	order.sort_custom(func(a, b): return a.d > b.d)

	for entry in order:
		var face : Array = faces[entry.i]
		var idx  : Array = face[0]
		var quad : PackedVector2Array = PackedVector2Array([
			pts[idx[0]], pts[idx[1]], pts[idx[2]], pts[idx[3]],
		])
		if _facing_away(quad):
			continue   # cull back faces so edges stay clean
		draw_colored_polygon(quad, face[1])
		draw_polyline(quad + PackedVector2Array([quad[0]]), EDGE, 1.0)
		# A strip of tape across the face nearest the camera.
		if entry == order[order.size() - 1]:
			draw_line(quad[0].lerp(quad[3], 0.5), quad[1].lerp(quad[2], 0.5), TAPE, 1.2)

## Rotate a point and flatten it to 2D. Y is squashed so the cube reads as
## sitting in a top-down world rather than facing the camera straight on.
func _project(p: Vector3, ax: float, ay: float) -> Vector2:
	# Rotate about Y (yaw), then X (tumble).
	var cy : float = cos(ay)
	var sy : float = sin(ay)
	var x1 : float = p.x * cy + p.z * sy
	var z1 : float = -p.x * sy + p.z * cy
	var cx : float = cos(ax)
	var sx : float = sin(ax)
	var y1 : float = p.y * cx - z1 * sx
	var z2 : float = p.y * sx + z1 * cx
	# Weak perspective: nearer corners spread out slightly.
	var scale : float = 1.0 + z2 * 0.012
	return Vector2(x1, y1 * 0.86) * scale

func _depth(_p: Vector2) -> float:
	return _p.y   # after projection, lower on screen == nearer

func _facing_away(quad: PackedVector2Array) -> bool:
	# Signed area: negative means the quad is wound away from us.
	var a : float = 0.0
	for i in quad.size():
		var p : Vector2 = quad[i]
		var q : Vector2 = quad[(i + 1) % quad.size()]
		a += p.x * q.y - q.x * p.y
	return a <= 0.0

func _draw_ellipse(centre: Vector2, radii: Vector2, color: Color) -> void:
	var pts : PackedVector2Array = PackedVector2Array()
	for i in 20:
		var a : float = TAU * i / 20.0
		pts.append(centre + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
