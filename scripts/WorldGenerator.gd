extends Node2D
## WorldGenerator — builds the town at runtime:
##   • Paints grass / road tiles on a TileMap
##   • Scatters Pickup nodes (ramps, puddles & potholes) across the road zones
##   • Exposes select_targets() and clear_targets() for day management
##     (delivery targets are the hand-drawn ArtBuilding nodes in the scene)

const TILE          := 16
const COLS          := 80
const ROWS          := 60
const ROAD_W        := 4

# Horizontal road top-edges (tile rows) — 1 road = 2 row bands of buildings
const ROAD_ROWS     := [28]
# Vertical road left-edges (tile cols) — 5 roads = 6 column bands of buildings
const ROAD_COLS     := [8, 22, 36, 50, 64]

# TileMap source / atlas IDs — we'll paint programmatically using
# a single-pixel colour atlas built at runtime (see _build_tileset)
const SOURCE_ID     := 0

# Colours
const C_GRASS        := Color("#c8dfa0")
const C_ROAD         := Color("#b0b8c8")
const C_ROAD_MARK    := Color("#9aa8b8")
const C_INTERSECT    := Color("#a8b0c0")

# Preloaded packed scenes
const PickupScene    := preload("res://scenes/Pickup.tscn")
const PackageScene   := preload("res://scenes/ThrownPackage.tscn")

# ── Runtime data ────────────────────────────────────────────
var buildings       : Array = []   # all Building nodes
var road_tiles      : Array = []   # Vector2i of road tile coords
var _rng            := RandomNumberGenerator.new()

@onready var tile_map  : TileMap = $TileMap
@onready var pkg_layer : Node2D  = $PickupLayer
#removing - this should be coming from line 40 - @onready var Pickup = $Pickup
#removing - this shold be coming from line 39 - @onready var Building = $Building


# ── Signals ─────────────────────────────────────────────────
signal world_ready()

# ───────────────────────────────────────────────────────────
func _ready() -> void:
	_rng.seed = 42
	_generate()
	world_ready.emit()

# ── Generation entry point ─────────────────────────────────
func _generate() -> void:
	_paint_tiles()
	_scatter_pickups()

# ── Tile painting ──────────────────────────────────────────
func _paint_tiles() -> void:
	# Use layer 0 for ground, layer 1 for road marks
	for r in ROWS:
		for c in COLS:
			var coord := Vector2i(c, r)
			var kind  := _tile_kind(r, c)
			match kind:
				"grass":
					tile_map.set_cell(0, coord, SOURCE_ID, Vector2i(0, 0))
				"road_h", "road_v":
					tile_map.set_cell(0, coord, SOURCE_ID, Vector2i(1, 0))
					road_tiles.append(coord)
				"intersection":
					tile_map.set_cell(0, coord, SOURCE_ID, Vector2i(2, 0))
					road_tiles.append(coord)

func _tile_kind(r: int, c: int) -> String:
	var rr := _is_road_row(r)
	var rc := _is_road_col(c)
	if rr and rc: return "intersection"
	if rr:        return "road_h"
	if rc:        return "road_v"
	return "grass"

func _is_road_row(r: int) -> bool:
	for rr in ROAD_ROWS:
		if r >= rr and r < rr + ROAD_W:
			return true
	return false

func _is_road_col(c: int) -> bool:
	for rc in ROAD_COLS:
		if c >= rc and c < rc + ROAD_W:
			return true
	return false

# ── Pickup scattering ──────────────────────────────────────
## Ramps and hazards live on the road surface only. Candidate points are drawn
## from the road_zone NavigationRegion2D polygons (the same strips the player's
## surface-speed check and the roadblock manager use), area-weighted so long
## roads get proportionally more than short ones.

const RAMP_COUNT    := 90
const PUDDLE_COUNT  := 30
const POTHOLE_COUNT := 30

const PICKUP_MIN_SEPARATION := 96.0   # px between features — about one house width
const ROAD_EDGE_INSET       := 10.0   # px pulled off the kerb so nothing hangs over

func _scatter_pickups() -> void:
	_clear_pickups()

	var tris : Array = _road_triangles()
	if tris.is_empty():
		push_warning("WorldGenerator: no road_zone regions found — no pickups spawned.")
		return
	var cumulative : Array[float] = _cumulative_areas(tris)

	# Interleaved so a failure to place late in the run thins every kind evenly
	# rather than starving whichever came last.
	var wanted : Array[int] = []
	for i in RAMP_COUNT:    wanted.append(Pickup.Kind.RAMP)
	for i in PUDDLE_COUNT:  wanted.append(Pickup.Kind.PUDDLE)
	for i in POTHOLE_COUNT: wanted.append(Pickup.Kind.POTHOLE)
	wanted.shuffle()

	var placed : Array[Vector2] = []
	var index  := 0
	var attempts := 0
	var max_attempts : int = wanted.size() * 40
	while index < wanted.size() and attempts < max_attempts:
		attempts += 1
		var pos : Vector2 = _random_road_point(tris, cumulative)
		if _pickup_too_close(pos, placed):
			continue
		_spawn_pickup(pos, wanted[index], _road_angle_at(pos))
		placed.append(pos)
		index += 1

## Every road polygon triangulated into global-space triangles.
func _road_triangles() -> Array:
	var tris : Array = []
	for r in get_tree().get_nodes_in_group("road_zone"):
		var np : NavigationPolygon = r.navigation_polygon
		if np == null or np.vertices.size() < 3:
			continue
		# Inset shrinks each outline toward its centre so points land on the
		# road proper rather than right on the kerb line.
		for oi in np.get_outline_count():
			var outline : PackedVector2Array = np.get_outline(oi)
			if outline.size() < 3:
				continue
			var shrunk : Array = Geometry2D.offset_polygon(outline, -ROAD_EDGE_INSET)
			for poly in shrunk:
				if poly.size() < 3:
					continue
				var global_poly : PackedVector2Array = PackedVector2Array()
				for pt in poly:
					global_poly.append(r.to_global(pt))
				var idx : PackedInt32Array = Geometry2D.triangulate_polygon(global_poly)
				for i in range(0, idx.size(), 3):
					tris.append([global_poly[idx[i]], global_poly[idx[i + 1]], global_poly[idx[i + 2]]])
	return tris

func _cumulative_areas(tris: Array) -> Array[float]:
	var out : Array[float] = []
	var running := 0.0
	for t in tris:
		running += absf((t[1] - t[0]).cross(t[2] - t[0])) * 0.5
		out.append(running)
	return out

## Uniformly random point over the whole road surface: pick a triangle weighted
## by area, then a barycentric point inside it.
func _random_road_point(tris: Array, cumulative: Array[float]) -> Vector2:
	var total : float = cumulative[cumulative.size() - 1]
	var pick  : float = _rng.randf() * total
	var lo := 0
	var hi := cumulative.size() - 1
	while lo < hi:
		var mid : int = (lo + hi) / 2
		if cumulative[mid] < pick:
			lo = mid + 1
		else:
			hi = mid
	var t : Array = tris[lo]
	var u : float = _rng.randf()
	var v : float = _rng.randf()
	if u + v > 1.0:
		u = 1.0 - u
		v = 1.0 - v
	return t[0] + (t[1] - t[0]) * u + (t[2] - t[0]) * v

## Heading of the road strip containing `pos`, so ramps point along traffic
## rather than into the kerb. Uses the long axis of the containing region's
## bounding box; falls back to a random heading if nothing contains the point.
func _road_angle_at(pos: Vector2) -> float:
	for r in get_tree().get_nodes_in_group("road_zone"):
		var np : NavigationPolygon = r.navigation_polygon
		if np == null:
			continue
		var local : Vector2 = r.to_local(pos)
		for oi in np.get_outline_count():
			var outline : PackedVector2Array = np.get_outline(oi)
			if outline.size() < 3:
				continue
			if not Geometry2D.is_point_in_polygon(local, outline):
				continue
			var bb : Rect2 = Rect2(outline[0], Vector2.ZERO)
			for pt in outline:
				bb = bb.expand(pt)
			# Long axis of the strip, pointing either way along it.
			var along : float = 0.0 if bb.size.x >= bb.size.y else PI / 2.0
			if _rng.randf() < 0.5:
				along += PI
			return along + r.global_rotation
	return _rng.randf() * TAU

func _pickup_too_close(pos: Vector2, placed: Array[Vector2]) -> bool:
	for other in placed:
		if pos.distance_squared_to(other) < PICKUP_MIN_SEPARATION * PICKUP_MIN_SEPARATION:
			return true
	return false

func _spawn_pickup(pos: Vector2, kind: int, angle: float) -> void:
	var p : Area2D = PickupScene.instantiate()
	pkg_layer.add_child(p)
	p.global_position = pos
	p.setup(kind, angle)

func _clear_pickups() -> void:
	for child in pkg_layer.get_children():
		child.queue_free()

# ── Target selection ────────────────────────────────────────
func select_targets(count: int = 5) -> Array:
	for b in buildings:
		b.clear_target()
	for ab in get_tree().get_nodes_in_group("art_building"):
		ab.clear_target()

	var candidates := buildings.filter(
		func(b): return b.building_type == Building.BuildingType.HOUSE \
					 or b.building_type == Building.BuildingType.MANSION
	)
	candidates.append_array(get_tree().get_nodes_in_group("art_building"))
	candidates.shuffle()
	var chosen := candidates.slice(0, min(count, candidates.size()))
	for b in chosen:
		b.mark_as_target()
	return chosen

func select_extra_targets(count: int) -> Array:
	var candidates : Array = buildings.filter(
		func(b): return (b.building_type == Building.BuildingType.HOUSE \
					 or b.building_type == Building.BuildingType.MANSION) \
					 and not b.is_target and not b.is_delivered
	)
	var art : Array = get_tree().get_nodes_in_group("art_building").filter(
		func(ab): return not ab.is_target and not ab.is_delivered
	)
	candidates.append_array(art)
	candidates.shuffle()
	var chosen : Array = candidates.slice(0, min(count, candidates.size()))
	for b in chosen:
		b.mark_as_target()
	return chosen

func clear_targets() -> void:
	for b in buildings:
		b.clear_target()
	for ab in get_tree().get_nodes_in_group("art_building"):
		ab.clear_target()

# ── Package throwing (called from Player) ──────────────────
func spawn_package(from: Vector2, to: Vector2, target: Node2D) -> void:
	var pkg : Node2D = PackageScene.instantiate()
	add_child(pkg)
	pkg.launch(from, to, target)
