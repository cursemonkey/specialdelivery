extends Vehicle
## The police cruiser Kali and Darin drive to a roadblock and park nearby.
## Faster than the bicycle, so officers reach the scene quickly.

const DRIVE_SPEED : float = 220.0   # px/sec — well above the bike's top speed

var _light_phase : float = 0.0

func _ready() -> void:
	body_color = Color(0.13, 0.20, 0.45)
	trim_color = Color(0.92, 0.94, 0.98)
	size       = Vector2(46, 22)
	super._ready()

func _process(delta: float) -> void:
	_light_phase = fmod(_light_phase + delta * 3.0, 1.0)
	queue_redraw()

func _draw() -> void:
	super._draw()
	# Roof lightbar, alternating red/blue.
	var red_on : bool = _light_phase < 0.5
	var bar : Rect2 = Rect2(-7.0, -4.0, 14.0, 5.0)
	draw_rect(bar, Color(0.12, 0.12, 0.14))
	draw_rect(Rect2(bar.position, Vector2(7.0, bar.size.y)),
			Color(1.0, 0.2, 0.2) if red_on else Color(0.5, 0.1, 0.1))
	draw_rect(Rect2(bar.position + Vector2(7.0, 0.0), Vector2(7.0, bar.size.y)),
			Color(0.3, 0.4, 1.0) if not red_on else Color(0.1, 0.15, 0.5))
	# "POLICE" stripe down the side.
	draw_rect(Rect2(-size.x * 0.5 + 3.0, -1.5, size.x - 6.0, 3.0), Color(0.9, 0.9, 0.95, 0.85))
