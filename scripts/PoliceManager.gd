extends Node2D
## Police roadblocks. Replaces the old construction-roadblock system: instead of
## barriers appearing from nowhere, there's a chance each day that the officers
## on shift (Kali and/or Darin) drive out from the station at 8am, park the
## cruiser near a road intersection, and man a roadblock there until end of shift.
##
## Intersections are detected from the road_zone NavigationRegion2D strips as
## compact overlaps between roughly perpendicular roads (long thin overlaps
## between parallel strips are filtered out).

const RoadblockScript : GDScript = preload("res://scripts/Roadblock.gd")
const CruiserScript   : GDScript = preload("res://scripts/PoliceCruiser.gd")

const ROADBLOCK_CHANCE : float   = 0.5     # chance of a roadblock on a given day
const DEPLOY_HOUR      : float   = 8.0     # officers leave the station at 8am
const STAND_DOWN_HOUR  : float   = 19.0    # end of shift
const BLOCK_SIZE       : Vector2 = Vector2(24, 120)
const AVOID_RADIUS     : float   = 140.0   # keep blocks away from the player's start
const CRUISER_OFFSET   : Vector2 = Vector2(70, 40)   # where the cruiser parks
const OFFICER_SPACING  : float   = 34.0

# Intersection detection tuning.
const MIN_SPAN   : float = 60.0
const MAX_SPAN   : float = 170.0
const MIN_ASPECT : float = 0.5
const MERGE_DIST : float = 60.0

var _intersections : Array[Vector2] = []
var _block         : StaticBody2D   = null
var _cruiser       : Node2D         = null
var _site          : Vector2        = Vector2.ZERO
var _officers      : Array          = []      # RegularNPCs posted to the block
var _planned_today : bool           = false   # a roadblock is scheduled today
var _deployed      : bool           = false   # officers have left the station

func setup() -> void:
	_intersections = _find_intersections()
	TimeManager.hour_changed.connect(_on_hour_changed)

func get_intersections() -> Array[Vector2]:
	return _intersections

## Decide (once per day) whether there's a roadblock, and where.
func plan_for_day(avoid_pos: Vector2) -> void:
	clear()
	_planned_today = false
	_deployed      = false
	if _on_duty_officers().is_empty():
		return
	if randf() > ROADBLOCK_CHANCE:
		return
	var candidates : Array = _intersections.filter(
		func(p: Vector2) -> bool: return p.distance_to(avoid_pos) > AVOID_RADIUS
	)
	if candidates.is_empty():
		return
	candidates.shuffle()
	_site          = candidates[0]
	_planned_today = true
	# If the day starts after the deploy hour, they're already out there.
	if TimeManager.hour >= DEPLOY_HOUR and TimeManager.hour < STAND_DOWN_HOUR:
		_deploy()

func _on_hour_changed(_h: int) -> void:
	if _planned_today and not _deployed \
			and TimeManager.hour >= DEPLOY_HOUR and TimeManager.hour < STAND_DOWN_HOUR:
		_deploy()
	elif _deployed and TimeManager.hour >= STAND_DOWN_HOUR:
		clear()

## Officers scheduled to work today (by weekday), regardless of the clock.
func _on_duty_officers() -> Array:
	var out : Array = []
	for npc in get_tree().get_nodes_in_group("regular_npc"):
		if NPCRegistry.officer_works_today(npc.id, TimeManager.weekday):
			out.append(npc)
	return out

## Put the barrier, cruiser and officers at the scene.
func _deploy() -> void:
	_deployed = true
	var officers : Array = _on_duty_officers()
	if officers.is_empty():
		return

	_block = RoadblockScript.new()
	add_child(_block)
	_block.global_position = _site
	_block.setup(BLOCK_SIZE)

	_cruiser = CruiserScript.new()
	add_child(_cruiser)
	_cruiser.global_position = _site + CRUISER_OFFSET

	# Officers drive over (fast) and man the block, spread out beside it.
	for i in officers.size():
		var npc : Node = officers[i]
		var spot : Vector2 = _site + Vector2(
			(float(i) - (officers.size() - 1) * 0.5) * OFFICER_SPACING, -34.0)
		npc.post_to_duty(spot)
		_officers.append(npc)

	var names : Array = []
	for o in officers:
		names.append(o.npc_name)
	GameManager.show_message("🚨 Police roadblock — %s on scene." % " and ".join(names), 4.0)

func clear() -> void:
	for o in _officers:
		if is_instance_valid(o):
			o.release_from_duty()
	_officers.clear()
	if is_instance_valid(_block):
		_block.queue_free()
	_block = null
	if is_instance_valid(_cruiser):
		_cruiser.queue_free()
	_cruiser = null
	_deployed = false

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
