class_name RoadGraph
extends RefCounted
## A navigable graph of the town's road network, built from the road_zone
## NavigationRegion2D strips.
##
## Why this exists: hand-authored waypoint lists work for a fixed loop like the
## bus, but not for a vehicle heading somewhere chosen at runtime — a cruiser
## called to a roadblock, a fire truck called to an incident. Those need a path
## to an arbitrary point, on roads, computed on the spot.
##
## The model exploits the fact that this town's roads are axis-aligned strips.
## Each strip becomes a corridor (a centre line plus an extent); wherever two
## perpendicular corridors overlap there is a junction node. Edges join adjacent
## junctions along a shared corridor, so every path is a sequence of straight,
## axis-aligned legs — exactly the shape RoadVehicle drives.
##
## Usage:
##     var g : RoadGraph = RoadGraph.new()
##     g.build(tree)                          # once, after the world exists
##     var pts : Array[Vector2] = g.path(from, to)
##
## path() returns [] when either end can't be reached, so callers should check
## before handing the result to a vehicle.

## A corridor is one road strip: horizontal or vertical, with a centre line.
class Corridor:
	extends RefCounted
	var horizontal : bool  = true
	var centre     : float = 0.0    # y for horizontal, x for vertical
	var from       : float = 0.0    # along-axis start (x for horizontal)
	var to         : float = 0.0    # along-axis end
	var name       : String = ""

	func point_at(along: float) -> Vector2:
		return Vector2(along, centre) if horizontal else Vector2(centre, along)

	func covers(along: float, slack: float = 0.0) -> bool:
		return along >= from - slack and along <= to + slack

## How far apart two junctions must be to count as distinct.
const MERGE_DIST : float = 40.0
## Slack when testing whether a corridor spans a crossing point, in px.
const SPAN_SLACK : float = 4.0
## A corridor thinner than this on its long axis is ignored as a stub.
const MIN_LENGTH : float = 120.0
## A region whose two dimensions are closer than this ratio is treated as a
## plaza rather than a strip, and contributes no corridor of its own.
const MAX_SQUARENESS : float = 0.62

## Step between samples when clipping a corridor to real road, in px.
const SAMPLE_STEP : float = 12.0

var _corridors : Array = []          # Corridor
var _nodes     : Array[Vector2] = []
var _edges     : Array = []          # per node: Array of {to: int, cost: float}
var _polys     : Array = []          # global-space road outlines, for testing
var _built     : bool = false

## True when `p` is on road surface.
func is_on_road(p: Vector2) -> bool:
	for g in _polys:
		if Geometry2D.is_point_in_polygon(p, g):
			return true
	return false

func is_built() -> bool:
	return _built and _nodes.size() > 0

func corridor_count() -> int:
	return _corridors.size()

func node_count() -> int:
	return _nodes.size()

func nodes() -> Array[Vector2]:
	return _nodes

## Build the graph from every NavigationRegion2D in `group` (default the road
## strips). Safe to call again to rebuild.
func build(tree: SceneTree, group: String = "road_zone") -> void:
	_corridors.clear()
	_nodes.clear()
	_edges.clear()
	_polys.clear()
	var regions : Array = tree.get_nodes_in_group(group)
	# Collect every outline first: corridors are clipped against the real road
	# surface, not against the region that happened to suggest them.
	for region in regions:
		var np : NavigationPolygon = region.navigation_polygon
		if np == null:
			continue
		for oi in np.get_outline_count():
			var g : PackedVector2Array = PackedVector2Array()
			for pt in np.get_outline(oi):
				g.append(region.to_global(pt))
			if g.size() >= 3:
				_polys.append(g)
	for region in regions:
		var c = _corridor_for(region)
		if c != null:
			_corridors.append(c)
	_build_nodes()
	_build_edges()
	_built = true

## Reduce one region to a corridor: the long axis becomes the run, the short
## axis gives the centre line. Square-ish regions are skipped.
func _corridor_for(region: NavigationRegion2D):
	var np : NavigationPolygon = region.navigation_polygon
	if np == null or np.vertices.size() < 3:
		return null
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for oi in np.get_outline_count():
		for pt in np.get_outline(oi):
			var g : Vector2 = region.to_global(pt)
			mn = mn.min(g)
			mx = mx.max(g)
	var sz : Vector2 = mx - mn
	if sz.x <= 0.0 or sz.y <= 0.0:
		return null
	var horizontal : bool = sz.x >= sz.y
	var long_len   : float = sz.x if horizontal else sz.y
	if long_len < MIN_LENGTH:
		return null
	var c = Corridor.new()
	c.horizontal = horizontal
	c.centre     = (mn.y + mx.y) * 0.5 if horizontal else (mn.x + mx.x) * 0.5
	c.name       = str(region.name)
	# The bounding box lies about irregular polygons — an L-shaped or blobby
	# region would otherwise contribute a corridor running through open ground.
	# Walk the centre line and keep only the longest stretch that is genuinely
	# road, so the corridor describes where a vehicle can actually drive.
	var lo : float = mn.x if horizontal else mn.y
	var hi : float = mx.x if horizontal else mx.y
	var best_from : float = 0.0
	var best_to   : float = 0.0
	var best_len  : float = 0.0
	var run_from  : float = INF
	var along     : float = lo
	while along <= hi:
		if is_on_road(c.point_at(along)):
			if run_from == INF:
				run_from = along
		elif run_from != INF:
			if along - run_from > best_len:
				best_len  = along - run_from
				best_from = run_from
				best_to   = along - SAMPLE_STEP
			run_from = INF
		along += SAMPLE_STEP
	if run_from != INF and hi - run_from > best_len:
		best_len  = hi - run_from
		best_from = run_from
		best_to   = hi
	if best_len < MIN_LENGTH:
		return null   # nothing drivable along the middle: a plaza, not a strip
	c.from = best_from
	c.to   = best_to
	return c

## Junctions are the crossings of perpendicular corridors that actually overlap.
func _build_nodes() -> void:
	for i in _corridors.size():
		for j in _corridors.size():
			var a = _corridors[i]
			var b = _corridors[j]
			if not a.horizontal or b.horizontal:
				continue   # want a horizontal a against a vertical b, once
			# a is horizontal (centre = y), b is vertical (centre = x).
			if not a.covers(b.centre, SPAN_SLACK):
				continue
			if not b.covers(a.centre, SPAN_SLACK):
				continue
			var crossing := Vector2(b.centre, a.centre)
			# Both corridors claim to span it, but the crossing itself must be
			# tarmac — two roads can pass at different points of an L without
			# ever meeting.
			if not is_on_road(crossing):
				continue
			_add_node(crossing)

func _add_node(p: Vector2) -> int:
	for i in _nodes.size():
		if _nodes[i].distance_to(p) < MERGE_DIST:
			return i
	_nodes.append(p)
	return _nodes.size() - 1

## Join each pair of junctions that are consecutive along a shared corridor.
func _build_edges() -> void:
	_edges.resize(_nodes.size())
	for i in _nodes.size():
		_edges[i] = []
	for c in _corridors:
		# Every node sitting on this corridor, ordered along it.
		var on : Array = []
		for i in _nodes.size():
			var p : Vector2 = _nodes[i]
			var off : float = absf(p.y - c.centre) if c.horizontal else absf(p.x - c.centre)
			if off > MERGE_DIST:
				continue
			var along : float = p.x if c.horizontal else p.y
			if not c.covers(along, SPAN_SLACK):
				continue
			on.append({"idx": i, "along": along})
		on.sort_custom(func(x, y): return x["along"] < y["along"])
		for k in range(on.size() - 1):
			_connect(on[k]["idx"], on[k + 1]["idx"])

## True when the straight run between two junctions is road the whole way. This
## is what stops the graph from inventing a shortcut across a gap in a corridor
## (the Road26/Road4 severance, for instance).
func _leg_is_drivable(a: Vector2, b: Vector2) -> bool:
	var dist : float = a.distance_to(b)
	if dist <= 0.001:
		return true
	var steps : int = int(ceil(dist / SAMPLE_STEP))
	for i in range(steps + 1):
		if not is_on_road(a.lerp(b, float(i) / steps)):
			return false
	return true

func _connect(a: int, b: int) -> void:
	if a == b:
		return
	if not _leg_is_drivable(_nodes[a], _nodes[b]):
		return
	var cost : float = _nodes[a].distance_to(_nodes[b])
	for e in _edges[a]:
		if e["to"] == b:
			return   # already joined along another corridor
	_edges[a].append({"to": b, "cost": cost})
	_edges[b].append({"to": a, "cost": cost})

## The junction nearest `p`. Returns -1 when the graph is empty.
func nearest_node(p: Vector2) -> int:
	var best : int   = -1
	var best_d : float = INF
	for i in _nodes.size():
		var d : float = _nodes[i].distance_to(p)
		if d < best_d:
			best_d = d
			best   = i
	return best

## A route of world points from `from` to `to`, running along roads. The first
## and last points are the requested positions, with the junction chain between
## them, so a vehicle starts and finishes where the caller asked.
##
## Returns [] when the graph isn't built or the two ends are in disconnected
## parts of the network — callers must check rather than assume a path exists.
func path(from: Vector2, to: Vector2) -> Array[Vector2]:
	var out : Array[Vector2] = []
	if not is_built():
		return out
	var start : int = nearest_node(from)
	var goal  : int = nearest_node(to)
	if start < 0 or goal < 0:
		return out
	var chain : Array[int] = _dijkstra(start, goal)
	if chain.is_empty():
		return out
	out.append(from)
	for idx in chain:
		var p : Vector2 = _nodes[idx]
		# Skip a junction that coincides with the point we already have.
		if out[out.size() - 1].distance_to(p) > 1.0:
			out.append(p)
	if out[out.size() - 1].distance_to(to) > 1.0:
		out.append(to)
	return out

## Shortest node chain from `start` to `goal`, inclusive. [] when unreachable.
func _dijkstra(start: int, goal: int) -> Array[int]:
	var n : int = _nodes.size()
	var dist : Array[float] = []
	var prev : Array[int]   = []
	var seen : Array[bool]  = []
	dist.resize(n)
	prev.resize(n)
	seen.resize(n)
	for i in n:
		dist[i] = INF
		prev[i] = -1
		seen[i] = false
	dist[start] = 0.0
	while true:
		# Small graph (tens of nodes), so a linear scan beats a heap here.
		var u : int = -1
		var best : float = INF
		for i in n:
			if not seen[i] and dist[i] < best:
				best = dist[i]
				u    = i
		if u < 0 or u == goal:
			break
		seen[u] = true
		for e in _edges[u]:
			var v : int = e["to"]
			var nd : float = dist[u] + e["cost"]
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u
	if dist[goal] == INF:
		return []
	var chain : Array[int] = []
	var at : int = goal
	while at != -1:
		chain.push_front(at)
		at = prev[at]
	return chain

## True when every junction is reachable from every other — a quick sanity
## check that the network isn't split into islands.
func is_fully_connected() -> bool:
	if _nodes.is_empty():
		return false
	var seen : Array[bool] = []
	seen.resize(_nodes.size())
	for i in _nodes.size():
		seen[i] = false
	var stack : Array[int] = [0]
	seen[0] = true
	var count : int = 1
	while not stack.is_empty():
		var u : int = stack.pop_back()
		for e in _edges[u]:
			var v : int = e["to"]
			if not seen[v]:
				seen[v] = true
				count += 1
				stack.append(v)
	return count == _nodes.size()

## Junctions with only one edge — dead ends a blocked vehicle cannot detour
## around. This is the automatic version of the choke-point analysis that was
## previously done by hand.
func dead_ends() -> Array[Vector2]:
	var out : Array[Vector2] = []
	for i in _nodes.size():
		if _edges[i].size() <= 1:
			out.append(_nodes[i])
	return out
