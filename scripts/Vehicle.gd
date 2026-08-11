class_name Vehicle
extends StaticBody2D
## A parked vehicle in the world. Riding into one hurts: it costs health and
## rizz and spins the player out. Base class so future vehicles (delivery vans,
## tractors) share the same collision contract — Player checks for `Vehicle`.

const HP_COST   : int = 3
const RIZZ_COST : int = 1

@export var body_color : Color = Color(0.2, 0.3, 0.7)
@export var trim_color : Color = Color(0.95, 0.95, 0.95)
@export var size       : Vector2 = Vector2(44, 22)
## Parked vehicles are just obstacles: bumping one spins you out but does no
## damage. A moving vehicle (future: patrols, traffic) hits for real.
@export var moving     : bool = false

func _ready() -> void:
	add_to_group("vehicle")
	var shape : CollisionShape2D = CollisionShape2D.new()
	var box   : RectangleShape2D = RectangleShape2D.new()
	box.size    = size
	shape.shape = box
	add_child(shape)
	z_index = 4
	queue_redraw()

## Called by Player on impact. Returns the message to show. A stationary vehicle
## costs nothing but the spin-out; only a moving one deals damage.
func on_hit_by_player() -> String:
	if not moving:
		return "💥 You clipped a parked vehicle!"
	GameManager.add_hp(-HP_COST)
	GameManager.add_rizz(-RIZZ_COST)
	return "🚨 A vehicle hit you! -%d HP" % HP_COST

func _draw() -> void:
	var w : float = size.x
	var h : float = size.y
	var r : Rect2 = Rect2(-w * 0.5, -h * 0.5, w, h)
	draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.2))   # shadow
	draw_rect(r, body_color)
	draw_rect(r, Color(0.1, 0.1, 0.12), false, 1.5)
	# Cabin / windows
	draw_rect(Rect2(-w * 0.16, -h * 0.5 + 2.0, w * 0.34, h - 4.0), trim_color)
	# Wheels
	draw_rect(Rect2(-w * 0.34, -h * 0.5 - 2.5, w * 0.18, 3.0), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2(-w * 0.34,  h * 0.5 - 0.5, w * 0.18, 3.0), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2( w * 0.16, -h * 0.5 - 2.5, w * 0.18, 3.0), Color(0.1, 0.1, 0.1))
	draw_rect(Rect2( w * 0.16,  h * 0.5 - 0.5, w * 0.18, 3.0), Color(0.1, 0.1, 0.1))
