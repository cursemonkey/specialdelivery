class_name RoadVehicle
extends Vehicle
## A vehicle that drives itself along a route, as opposed to Vehicle, which is
## a parked obstacle. Everything here is shared by the bus, the police cruiser,
## the fire truck and ordinary traffic:
##
##   • following a polyline of waypoints, with optional pauses
##   • a sensor area, because a moving StaticBody2D never registers as a slide
##     collision against a player who is standing still
##   • the rider/walker damage split and the re-hit cooldown
##
## Subclasses supply the route, the livery (_draw), and any schedule of their
## own. They should not need to re-implement driving.
##
## Routes are plain world-space points. Build them by hand for a fixed loop
## (see Bus), or ask RoadGraph for a path to an arbitrary destination (see
## PoliceCruiser).

## Emitted when the vehicle reaches the final waypoint of a non-looping route.
signal route_finished()
## Emitted on arrival at a waypoint flagged as a stop.
signal stop_reached(index: int)

# ── Damage ─────────────────────────────────────────────────
# Fields rather than constants so each vehicle can be tuned: a fire truck
# should hurt more than a commuter car.
## Cost of being hit while riding the bike.
@export var rider_hp_cost    : int = 3
@export var rider_rizz_cost  : int = 1
## Cost of being run over on foot — heavier, and it puts the player down.
@export var walker_hp_cost   : int = 4
@export var walker_rizz_cost : int = 1
## Seconds the player lies stunned after being run over on foot.
@export var walker_stun_time : float = 3.0
## How hard this vehicle shoves what it hits.
@export var knockback_speed  : float = 300.0
## Guard so one impact does not re-fire every frame of contact.
@export var hit_cooldown     : float = 1.4

## Shown when this vehicle hits a rider / a pedestrian. "%d" takes the HP cost.
@export var rider_hit_message  : String = "🚗 A vehicle clipped you! -%d HP"
@export var walker_hit_message : String = "🚗 A vehicle ran you over! -%d HP"

# ── Driving ────────────────────────────────────────────────
@export var speed      : float = 78.0   # px/sec
@export var stop_dwell : float = 2.2    # seconds paused at a flagged stop
@export var turn_rate  : float = 6.0    # how sharply it settles onto a heading
## Closed loops rejoin waypoint 0; open routes stop at the end and emit
## route_finished.
@export var loop_route : bool = true

## Extra margin around the body for the impact sensor.
const SENSOR_PADDING : Vector2 = Vector2(10.0, 10.0)

var _route      : Array[Vector2] = []
var _stop_flags : Array[bool]    = []
var _leg        : int    = 0
var _t          : float  = 0.0   # px travelled along the current leg
var _dwell      : float  = 0.0
var _hit_timer  : float  = 0.0
var _heading    : float  = 0.0
var _sensor     : Area2D = null
## Suspended vehicles are hidden, intangible and do not drive — used for the
## bus's weekend park, and for any vehicle waiting to be called out.
var _suspended  : bool   = false
var _finished   : bool   = false

func _ready() -> void:
	moving = true          # a moving vehicle deals real damage
	super._ready()
	add_to_group("road_vehicle")
	z_index = 6
	_build_sensor()

## A slightly oversized trigger box, so a stationary player still gets hit.
func _build_sensor() -> void:
	_sensor = Area2D.new()
	var shape : CollisionShape2D = CollisionShape2D.new()
	var box   : RectangleShape2D = RectangleShape2D.new()
	box.size    = size + SENSOR_PADDING
	shape.shape = box
	_sensor.add_child(shape)
	_sensor.body_entered.connect(_on_sensor_body_entered)
	add_child(_sensor)

## Put this vehicle on `route`. `stop_flags`, when given, marks the waypoints it
## should pause at; omit it for a route with no scheduled stops.
func set_route(route: Array[Vector2], stop_flags: Array[bool] = []) -> void:
	_route      = route
	_stop_flags = stop_flags
	_leg        = 0
	_t          = 0.0
	_dwell      = 0.0
	_finished   = false
	if _route.size() >= 2:
		global_position = _route[0]
		_heading        = (_route[1] - _route[0]).angle()
		rotation        = _heading

func has_route() -> bool:
	return _route.size() >= 2

func route_points() -> Array[Vector2]:
	return _route

func _physics_process(delta: float) -> void:
	if _hit_timer > 0.0:
		_hit_timer -= delta
	if _suspended or _finished or not has_route():
		return
	if _dwell > 0.0:
		_dwell -= delta
		return
	_advance(delta)

## Drive along the current leg, rolling onto the next when it runs out.
func _advance(delta: float) -> void:
	var last : int = _route.size() - 1
	if not loop_route and _leg >= last:
		_finished = true
		route_finished.emit()
		return
	var a : Vector2 = _route[_leg]
	var b : Vector2 = _route[(_leg + 1) % _route.size()]
	var leg_len : float = a.distance_to(b)
	if leg_len <= 0.001:
		_next_leg()
		return
	_t += speed * delta
	if _t >= leg_len:
		_t = 0.0
		# Arrived at waypoint (_leg + 1); pause there if it is a flagged stop.
		var arrived : int = (_leg + 1) % _route.size()
		global_position = _route[arrived]
		_next_leg()
		if arrived < _stop_flags.size() and _stop_flags[arrived]:
			_dwell = stop_dwell
			stop_reached.emit(arrived)
		return
	global_position = a.lerp(b, _t / leg_len)
	# Ease onto the leg's heading so corners look driven rather than snapped.
	var want : float = (b - a).angle()
	_heading = lerp_angle(_heading, want, clampf(turn_rate * delta, 0.0, 1.0))
	rotation = _heading

func _next_leg() -> void:
	if loop_route:
		_leg = (_leg + 1) % _route.size()
	else:
		_leg = mini(_leg + 1, _route.size() - 1)

## Hide and disable the vehicle (off-shift, parked in the depot, not yet called
## out). A suspended vehicle neither drives nor collides.
func set_suspended(value: bool) -> void:
	if value == _suspended:
		return
	_suspended = value
	visible = not _suspended
	set_deferred("collision_layer", 0 if _suspended else 1)
	if _sensor != null:
		_sensor.set_deferred("monitoring", not _suspended)

func is_suspended() -> bool:
	return _suspended

## Restart the current route from its first waypoint.
func restart_route() -> void:
	_leg      = 0
	_t        = 0.0
	_dwell    = 0.0
	_finished = false
	if has_route():
		global_position = _route[0]

## The direction this vehicle is travelling.
func heading_vector() -> Vector2:
	return Vector2(cos(_heading), sin(_heading))

# ── Impacts ────────────────────────────────────────────────
## This vehicle hit the player. `on_bike` picks which penalty applies. Returns
## the message to show, or "" when the hit was swallowed by the cooldown.
func hit_player(player: Node2D, on_bike: bool) -> String:
	if _hit_timer > 0.0 or _suspended:
		return ""
	_hit_timer = hit_cooldown
	var dir : Vector2 = _shove_direction(player)
	if on_bike:
		GameManager.add_hp(-rider_hp_cost)
		GameManager.add_rizz(-rider_rizz_cost)
		if player != null and player.has_method("knockback_riding"):
			player.knockback_riding(dir, knockback_speed)
		return rider_hit_message % rider_hp_cost
	GameManager.add_hp(-walker_hp_cost)
	GameManager.add_rizz(-walker_rizz_cost)
	if player != null and player.has_method("knockdown_walking"):
		player.knockdown_walking(walker_stun_time)
	return walker_hit_message % walker_hp_cost

## Throw the victim out along our travel direction, biased to whichever side of
## the vehicle they are on, so they are flung clear rather than dragged under.
func _shove_direction(player: Node2D) -> Vector2:
	var travel : Vector2 = heading_vector()
	if player == null:
		return travel
	var side : float = signf(travel.cross(player.global_position - global_position))
	if side == 0.0:
		side = 1.0
	return (travel * 0.5 + travel.orthogonal() * side).normalized()

## Anyone this vehicle drives into. Only the player takes damage; NPCs are left
## to the existing pedestrian handling.
func _on_sensor_body_entered(body: Node2D) -> void:
	if _suspended:
		return
	if not body is CharacterBody2D:
		return
	if not body.has_method("apply_boost"):
		return   # the duck-typed rider test the rest of the world uses
	var riding : bool = bool(body.on_bike) if "on_bike" in body else false
	var msg : String = hit_player(body, riding)
	if msg != "":
		GameManager.show_message(msg)

## Vehicle's generic contract, for the player-initiated collision path. Moving
## vehicles resolve damage through hit_player, which knows rider from walker.
func on_hit_by_player() -> String:
	return hit_player(null, true)
