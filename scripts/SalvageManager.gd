extends Node2D
## SalvageManager — free scrap and bolts lying about the town. Created from
## Main._ready().
##
## Two populations, tuned separately:
##   • The town at large — thin. TOWN_TARGET pieces spread over every road.
##   • The junk yard     — thick. YARD_MIN..YARD_MAX pieces spread over every
##                       region in the junkyard_zone group.
##
## Cadence: a sweep runs every SPAWN_INTERVAL_HOURS in-game hours and tops each
## population back up to target. Pieces expire on their own timer (see Salvage),
## flickering out shortly before they go, so the town is never picked bare and
## never silts up. Spawning and despawning are deliberately silent — no toast,
## no dialogue; the player just finds things.

const SalvageScene : PackedScene = preload("res://scenes/Salvage.tscn")

## Items that can turn up loose. Both are GARAGE_STOCK materials, so anything
## found here is something Aidan would otherwise sell.
const ITEM_IDS : Array[String] = ["scrap", "bolts"]

# ── Population targets ─────────────────────────────────────
## Pieces loose on the town's roads at any one time.
const TOWN_TARGET : int = 5
## Pieces in the junk yard at any one time, re-rolled each sweep.
const YARD_MIN    : int = 3
const YARD_MAX    : int = 5

# ── Cadence ────────────────────────────────────────────────
## In-game hours between top-up sweeps. The clock runs at 2 in-game hours per
## real minute, so 12 in-game hours is a sweep every 6 real minutes.
const SPAWN_INTERVAL_HOURS : float = 12.0

## How long a piece lasts, in real seconds. Set a shade under two sweeps so a
## piece generally survives one full sweep-to-sweep window and is gone by the
## next — the population turns over instead of accumulating.
const LIFETIME_SECONDS      : float = 660.0
## Random +/- spread on each piece's lifetime, so a batch doesn't vanish
## together in one blink.
const LIFETIME_JITTER       : float = 90.0

# ── The junk yard ──────────────────────────────────────────
## The junk yard is every NavigationRegion2D in this group, so the yard can be
## several plots (grass, dirt track, whatever else) rather than one polygon.
## Tag a region with this group in the editor and it joins the territory — no
## code change, no node paths to keep in step with renames.
const JUNKYARD_GROUP : String = "junkyard_zone"

## Fallback when nothing carries the group yet: regions whose node name starts
## with any of these (case-insensitive) are treated as junk yard too, so the
## yard keeps working before the group is applied.
const JUNKYARD_NAME_PREFIXES : Array[String] = ["junkyardgrass", "dirtroadjunkyard"]
## Pixels pulled in from the polygon edge so pieces don't sit half off the plot.
const JUNKYARD_EDGE_INSET  : float  = 12.0

## Minimum gap between two loose pieces, so they don't stack into one blob.
const MIN_SEPARATION      : float = 64.0
## The yard is dense by design, so it gets a tighter rule of its own.
const YARD_MIN_SEPARATION : float = 34.0

var _rng         : RandomNumberGenerator = RandomNumberGenerator.new()
var _world       : Node2D = null
var _town        : Array  = []   # live Salvage nodes on the roads
var _yard        : Array  = []   # live Salvage nodes in the junk yard
var _next_sweep  : float  = 0.0  # in-game hours remaining until the next sweep
var _yard_target : int    = YARD_MIN
var _yard_region_nodes : Array = []

func setup(world_gen: Node2D) -> void:
	_world = world_gen
	_rng.randomize()

## Seed both populations and start the clock. Called once the world exists.
func begin() -> void:
	_next_sweep  = SPAWN_INTERVAL_HOURS
	_yard_target = _rng.randi_range(YARD_MIN, YARD_MAX)
	_sweep()

func _process(delta: float) -> void:
	_prune()
	# Count the sweep timer down in in-game hours so the cadence follows the
	# game clock (and any future time-scale change) rather than wall time.
	_next_sweep -= delta * TimeManager.HOURS_PER_SECOND
	if _next_sweep <= 0.0:
		_next_sweep = SPAWN_INTERVAL_HOURS
		# Re-roll how full the yard should be, so it varies sweep to sweep.
		_yard_target = _rng.randi_range(YARD_MIN, YARD_MAX)
		_sweep()

## Drop freed pieces (collected or expired) out of the live lists.
func _prune() -> void:
	_town = _town.filter(func(s): return is_instance_valid(s))
	_yard = _yard.filter(func(s): return is_instance_valid(s))

## Top both populations back up to target.
func _sweep() -> void:
	_prune()
	_fill_town()
	_fill_yard()

# ── Town roads ─────────────────────────────────────────────
## Reuses WorldGenerator's road triangulation, so loose salvage lands on the
## same drivable surface as the ramps and potholes and is always rideable-over.
func _fill_town() -> void:
	var missing : int = TOWN_TARGET - _town.size()
	if missing <= 0:
		return
	if _world == null or not _world.has_method("random_road_points"):
		return
	var points : Array = _world.random_road_points(missing * 8)
	if points.is_empty():
		return
	var added : int = 0
	for pos in points:
		if added >= missing:
			break
		if _too_close(pos, _town, MIN_SEPARATION):
			continue
		_town.append(_spawn_at(pos))
		added += 1

# ── Junk yard ──────────────────────────────────────────────
func _fill_yard() -> void:
	var missing : int = _yard_target - _yard.size()
	if missing <= 0:
		return
	var regions : Array = _yard_regions()
	if regions.is_empty() or _world == null or not _world.has_method("random_points_in_regions"):
		return
	# Over-sample so rejected (too-close) candidates still leave enough to fill.
	# Area-weighted across all the yard's plots, so a big plot gets
	# proportionally more than a small one instead of each getting an equal share.
	var points : Array = _world.random_points_in_regions(regions, missing * 12, JUNKYARD_EDGE_INSET)
	if points.is_empty():
		return
	var added : int = 0
	for pos in points:
		if added >= missing:
			break
		if _too_close(pos, _yard, YARD_MIN_SEPARATION):
			continue
		_yard.append(_spawn_at(pos))
		added += 1

## Every navigation region making up the junk yard, resolved once and kept.
## Group first; name prefixes only as a fallback when the group is empty.
func _yard_regions() -> Array:
	_yard_region_nodes = _yard_region_nodes.filter(func(r): return is_instance_valid(r))
	if not _yard_region_nodes.is_empty():
		return _yard_region_nodes
	var found : Array = []
	for n in get_tree().get_nodes_in_group(JUNKYARD_GROUP):
		if n is NavigationRegion2D:
			found.append(n)
	if found.is_empty():
		found = _regions_by_name()
	if found.is_empty():
		push_warning("SalvageManager: no junk yard regions (group '%s' or names %s) — no yard salvage."
			% [JUNKYARD_GROUP, str(JUNKYARD_NAME_PREFIXES)])
	_yard_region_nodes = found
	return _yard_region_nodes

## Fallback scan: any NavigationRegion2D under Main whose name starts with one
## of JUNKYARD_NAME_PREFIXES.
func _regions_by_name() -> Array:
	var out  : Array = []
	var root : Node  = get_parent()
	if root == null:
		return out
	for n in root.find_children("*", "NavigationRegion2D", true, false):
		var lower : String = str(n.name).to_lower()
		for prefix in JUNKYARD_NAME_PREFIXES:
			if lower.begins_with(prefix):
				out.append(n)
				break
	return out

# ── Shared ─────────────────────────────────────────────────
func _spawn_at(pos: Vector2) -> Node2D:
	var s : Area2D = SalvageScene.instantiate()
	add_child(s)
	s.global_position = pos
	var life : float = LIFETIME_SECONDS + _rng.randf_range(-LIFETIME_JITTER, LIFETIME_JITTER)
	s.setup(ITEM_IDS[_rng.randi() % ITEM_IDS.size()], life)
	return s

func _too_close(pos: Vector2, others: Array, gap: float) -> bool:
	for o in others:
		if not is_instance_valid(o):
			continue
		if pos.distance_to(o.global_position) < gap:
			return true
	return false

## Remove every loose piece — used when the world is rebuilt.
func clear_all() -> void:
	for s in _town + _yard:
		if is_instance_valid(s):
			s.queue_free()
	_town.clear()
	_yard.clear()
