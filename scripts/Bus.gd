class_name Bus
extends RoadVehicle
## The town bus. Runs a fixed loop of the six stops all day, every day, except
## that at weekends it goes off the west edge of the map to park between
## PARK_START_HOUR and PARK_END_HOUR.
##
## Driving, impacts and the rider/walker damage split all live in RoadVehicle.
## What is specific to the bus is its weekend schedule and its livery; the route
## itself is supplied by BusManager.

## Weekend parking window. Saturday and Sunday only; the bus leaves the route
## at PARK_START_HOUR and is back on it at PARK_END_HOUR.
const PARK_START_HOUR : float = 1.0
const PARK_END_HOUR   : float = 7.0
const SUNDAY   : int = 0
const SATURDAY : int = 6

func _ready() -> void:
	body_color = Color("#d8a43a")     # school-bus yellow
	trim_color = Color("#2a2f3a")
	size       = Vector2(92, 34)
	# The bus is heavy and on a fixed route: it hurts more than ordinary traffic.
	rider_hp_cost      = 3
	rider_rizz_cost    = 2
	walker_hp_cost     = 4
	walker_rizz_cost   = 1
	walker_stun_time   = 3.0
	rider_hit_message  = "🚌 The bus clipped you! -%d HP"
	walker_hit_message = "🚌 The bus ran you over! -%d HP"
	speed      = 78.0
	stop_dwell = 2.2
	loop_route = true
	super._ready()
	add_to_group("bus")

func _physics_process(delta: float) -> void:
	_update_parking()
	super._physics_process(delta)

## Weekends: off the map from 1am to 7am. On a weekday it never stops.
func _update_parking() -> void:
	var weekend     : bool = TimeManager.weekday == SATURDAY or TimeManager.weekday == SUNDAY
	var in_window   : bool = TimeManager.hour >= PARK_START_HOUR and TimeManager.hour < PARK_END_HOUR
	var want_parked : bool = weekend and in_window
	if want_parked == is_suspended():
		return
	set_suspended(want_parked)
	if not want_parked:
		# Back on shift: pick the route up again from the western depot leg.
		restart_route()

## True while the bus is off-map for the weekend. Kept as its own name because
## "parked" reads better than "suspended" for callers asking about the bus.
func is_parked() -> bool:
	return is_suspended()

func _draw() -> void:
	var w : float = size.x
	var h : float = size.y
	var r : Rect2 = Rect2(-w * 0.5, -h * 0.5, w, h)
	# Shadow.
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.22))
	# Body.
	draw_rect(r, body_color)
	draw_rect(r, Color(0.16, 0.13, 0.05), false, 2.0)
	# Black skirt stripe along the bottom flank.
	draw_rect(Rect2(-w * 0.5, h * 0.5 - 6.0, w, 4.0), Color(0.18, 0.16, 0.12))
	# Windows down the side — a row of panes, with the windscreen up front.
	var pane : float = 12.0
	var x : float = -w * 0.5 + 10.0
	while x < w * 0.5 - 20.0:
		draw_rect(Rect2(x, -h * 0.5 + 5.0, pane - 3.0, h * 0.42), Color(0.62, 0.78, 0.86, 0.95))
		x += pane
	# Windscreen and destination board at the front (bus faces +X).
	draw_rect(Rect2(w * 0.5 - 16.0, -h * 0.5 + 4.0, 11.0, h - 8.0), Color(0.70, 0.84, 0.90))
	draw_rect(Rect2(w * 0.5 - 30.0, -h * 0.5 + 1.5, 13.0, 5.0), Color(0.12, 0.12, 0.14))
	# Door on the near side.
	draw_rect(Rect2(w * 0.18, h * 0.5 - 13.0, 9.0, 11.0), Color(0.35, 0.42, 0.48))
	# Wheels.
	for wx in [-w * 0.30, w * 0.26]:
		draw_rect(Rect2(wx, -h * 0.5 - 3.0, 15.0, 4.0), Color(0.1, 0.1, 0.1))
		draw_rect(Rect2(wx,  h * 0.5 - 1.0, 15.0, 4.0), Color(0.1, 0.1, 0.1))
	# Headlights.
	draw_circle(Vector2(w * 0.5 - 3.0, -h * 0.28), 2.4, Color(1.0, 0.95, 0.75))
	draw_circle(Vector2(w * 0.5 - 3.0,  h * 0.28), 2.4, Color(1.0, 0.95, 0.75))
