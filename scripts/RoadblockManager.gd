extends Node2D
## Finds road intersections from the road_zone NavigationRegion2D strips and
## spawns a few random construction roadblocks there each day. Created by Main:
## call setup() once, then spawn_for_day() at the start of each day.
##
## Intersections are detected as compact overlaps between roughly perpendicular
## road strips (long thin overlaps between parallel strips are filtered out).

const RoadblockScript : GDScript = preload("res://scripts/Roadblock.gd")

const ROADBLOCKS_PER_DAY : int     = 1
const BLOCK_SIZE         : Vector2 = Vector2(24, 120)   # x = thickness, y = length
const AVOID_RADIUS       : float   = 140.0   # keep blocks away from the player's start

# Intersection detection tuning.
const MIN_SPAN   : float = 60.0    # a junction is ~one road-width across …
const MAX_SPAN   : float = 170.0   # … and not much more
const MIN_ASPECT : float = 0.5     # near-square (parallel-strip slivers are long/thin)
const MERGE_DIST : float = 60.0    # dedupe nearby overlaps into one point

var _intersections : Array[Vector2] = []
var _active        : Array          = []

func setup() -> void:
	_intersections = _find_intersections()

func get_intersections() -> Array[Vector2]:
	return _intersections

## Clear yesterday's blocks and place today's, avoiding `avoid_pos`.
func spawn_for_day(avoid_pos: Vector2) -> void:
	clear()
	var candidates : Array = _intersections.filter(
		func(p: Vector2) -> bool: return p.distance_to(avoid_pos) > AVOID_RADIUS
	)
	candidates.shuffle()
	var n : int = mini(ROADBLOCKS_PER_DAY, candidates.size())
	for i in n:
		var rb : StaticBody2D = RoadblockScript.new()
		add_child(rb)
		rb.global_position = candidates[i]
		rb.setup(BLOCK_SIZE)
		_active.append(rb)

func clear() -> void:
	for rb in _active:
		if is_instance_valid(rb):
			rb.queue_free()
	_active.clear()

# ── Intersection detection ─────────────────────────────────
func _find_intersections() -> Array[Vector2]:
	var polys : Array = []
	for r in get_tree().get_nodes_in_group("road_zone"):
		var np : NavigationPolygon = r.navigation_polygon
		if np == null or np.vertices.size() < 3:
			continue
		var g : PackedVector2Array = PackedVector2Array()
		for pt in np.vertices:
			g.append(r.to_global(pt))
		polys.append(Geometry2D.convex_hull(g))

	var pts : Array[Vector2] = []
	for i in polys.size():
		for j in range(i + 1, polys.size()):
			for c in Geometry2D.intersect_polygons(polys[i], polys[j]):
				var bb : Rect2  = _bbox(c)
				var lo : float  = minf(bb.size.x, bb.size.y)
				var hi : float  = maxf(bb.size.x, bb.size.y)
				if hi <= 0.0:
					continue
				if (lo / hi) >= MIN_ASPECT and lo >= MIN_SPAN and hi <= MAX_SPAN:
					pts.append(bb.position + bb.size * 0.5)
	return _dedupe(pts, MERGE_DIST)

func _dedupe(pts: Array[Vector2], radius: float) -> Array[Vector2]:
	var out : Array[Vector2] = []
	for p in pts:
		var merged : bool = false
		for q in out:
			if p.distance_to(q) < radius:
				merged = true
				break
		if not merged:
			out.append(p)
	return out

func _bbox(p: PackedVector2Array) -> Rect2:
	var r : Rect2 = Rect2(p[0], Vector2.ZERO)
	for pt in p:
		r = r.expand(pt)
	return r
