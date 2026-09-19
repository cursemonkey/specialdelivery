extends Node2D
## BusManager — owns the town's bus and its route. Created from Main._ready().
##
## The route is a closed loop of axis-aligned legs, each running along one road
## corridor, verified to lie on the road_zone polygons. Waypoints marked as
## stops are where the bus pauses; the rest are just corners.
##
## Route (clockwise from the west depot):
##   west depot → Grocery → Hospital → Town Hall → Apartments
##                → School → Library → back west
##
## Where a stop's door is set back from the road (they all are, by 45–180px)
## the bus halts at the kerb outside it rather than driving to the door.

const BusScript : GDScript = preload("res://scripts/Bus.gd")

## X of the offscreen depot, west of the map edge (the map starts at x≈0).
const DEPOT_X : float = -240.0

## Waypoints, in order. `stop` marks the ones the bus pauses at; the others are
## corners where it turns. Corridor names are the road each leg runs along.
const WAYPOINTS : Array[Dictionary] = [
	{"pos": Vector2(DEPOT_X, 1662), "stop": false, "name": "Depot"},        # offscreen west
	{"pos": Vector2(1644, 1662),    "stop": true,  "name": "Grocery"},      # Road5 × Road22
	{"pos": Vector2(1644, 1159),    "stop": false, "name": "Road22×Road2"},
	{"pos": Vector2(2889, 1159),    "stop": true,  "name": "Hospital"},     # Road2 × Road11
	{"pos": Vector2(3496, 1159),    "stop": false, "name": "Road2×Road28"},
	{"pos": Vector2(3496, 2169),    "stop": true,  "name": "Town Hall"},    # Road28 × Road3
	{"pos": Vector2(3496, 2663),    "stop": false, "name": "Road28×Road6"},
	{"pos": Vector2(4122, 2663),    "stop": false, "name": "Road6×Road30"},
	{"pos": Vector2(4122, 3400),    "stop": false, "name": "Road30 south"},
	{"pos": Vector2(3496, 3400),    "stop": true,  "name": "Apartments"},   # Road4 band
	{"pos": Vector2(3496, 2663),    "stop": false, "name": "Road28×Road6"},
	{"pos": Vector2(2857, 2663),    "stop": false, "name": "Road6×Road26"},
	{"pos": Vector2(2857, 3180),    "stop": true,  "name": "School"},       # Road26 south
	{"pos": Vector2(2857, 2663),    "stop": false, "name": "Road6×Road26"},
	{"pos": Vector2(2263, 2663),    "stop": false, "name": "Road6×Road24"},
	{"pos": Vector2(2263, 3033),    "stop": true,  "name": "Library"},      # Road24 × Road15
	{"pos": Vector2(DEPOT_X, 3033), "stop": false, "name": "Road15 west"},
]

var _bus : Node2D = null

func setup() -> void:
	_bus = BusScript.new()
	_bus.name = "Bus"
	add_child(_bus)
	var route : Array[Vector2] = []
	var stops : Array[bool]    = []
	for w in WAYPOINTS:
		route.append(w["pos"])
		stops.append(bool(w["stop"]))
	_bus.set_route(route, stops)

func get_bus() -> Node2D:
	return _bus

## Route waypoints as world positions — for tooling and tests.
func route_points() -> Array[Vector2]:
	var out : Array[Vector2] = []
	for w in WAYPOINTS:
		out.append(w["pos"])
	return out

## Legs whose corridor has no parallel alternative, so a roadblock landing on
## one leaves the bus no way round. Returns a list of {from, to, name} for each.
## Used by the roadblock planner to keep blocks off the bus's sole-access legs.
func choke_point_legs() -> Array:
	var out : Array = []
	for i in WAYPOINTS.size():
		var name : String = str(WAYPOINTS[i]["name"])
		for choke in CHOKE_LEG_NAMES:
			if name == choke:
				out.append({
					"from": WAYPOINTS[i]["pos"],
					"to":   WAYPOINTS[(i + 1) % WAYPOINTS.size()]["pos"],
					"name": name,
				})
	return out

## Waypoints that sit on a spur — a corridor with no parallel road serving the
## same stop, so a roadblock there cannot be detoured around. Hospital (Road11
## dead-ends at y≈1642), School (Road26 is severed from Road4 between y≈3210 and
## y≈3360) and the single Road15 run west.
##
## RoadGraph.dead_ends() now finds these from the map itself and agrees with
## this list, so prefer that for anything new; this stays because it names the
## bus's own route legs, which the graph knows nothing about.
const CHOKE_LEG_NAMES : Array[String] = ["Hospital", "School", "Library"]
