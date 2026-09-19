extends RoadVehicle
## The police cruiser Kali and Darin drive to a roadblock and park nearby.
## Faster than the bicycle, so officers reach the scene quickly.
##
## It drives there for real: PoliceManager asks RoadGraph for a route from the
## station to the block and hands it over with drive_to(). On arrival it parks
## and stops being traffic, so a cruiser standing at a block is an obstacle
## rather than something that runs you down.

const DRIVE_SPEED : float = 220.0   # px/sec — well above the bike's top speed

var _light_phase : float = 0.0
var _on_station  : bool  = false   # arrived and parked at the scene

func _ready() -> void:
	body_color = Color(0.13, 0.20, 0.45)
	trim_color = Color(0.92, 0.94, 0.98)
	size       = Vector2(46, 22)
	# Lighter than the bus: a glancing blow from a car, not a bus under you.
	rider_hp_cost      = 2
	rider_rizz_cost    = 1
	walker_hp_cost     = 3
	walker_rizz_cost   = 1
	walker_stun_time   = 2.0
	rider_hit_message  = "🚓 The cruiser clipped you! -%d HP"
	walker_hit_message = "🚓 The cruiser knocked you down! -%d HP"
	speed      = DRIVE_SPEED
	loop_route = false            # one-way trip to the scene
	super._ready()
	route_finished.connect(_on_arrived)

## Send the cruiser along `route` (station → scene). An empty or too-short
## route falls back to appearing at the destination, so a map with no usable
## path still works rather than leaving the block unattended.
func drive_to(route: Array[Vector2]) -> void:
	if route.size() < 2:
		if not route.is_empty():
			global_position = route[route.size() - 1]
		_on_arrived()
		return
	_on_station = false
	set_route(route)

## Parked at the scene: stop dealing damage, become a plain obstacle.
func _on_arrived() -> void:
	_on_station = true
	moving = false

## True once it has reached the roadblock.
func is_on_station() -> bool:
	return _on_station

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
