extends Node2D
## WorldGenerator — builds the town at runtime:
##   • Paints grass / road tiles on a TileMap
##   • Scatters Pickup nodes (tricks & traps) on road tiles
##   • Exposes select_targets() and clear_targets() for day management
##     (delivery targets are the hand-drawn ArtBuilding nodes in the scene)

const TILE          := 16
const COLS          := 80
const ROWS          := 60
const ROAD_W        := 4

# Full map bounds for pickup spawning (matches camera limits in Main.gd)
const MAP_COLS      := 415
const MAP_ROWS      := 313

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
const PICKUP_MIN_SEPARATION := 6   # tiles — one minimum house width

func _scatter_pickups() -> void:
	_clear_pickups()
	var placed : Array[Vector2i] = []
	var tricks  := 0
	var traps   := 0
	var attempts := 0
	while (tricks < 90 or traps < 60) and attempts < 15000:
		attempts += 1
		var coord := Vector2i(randi_range(0, MAP_COLS - 1), randi_range(0, MAP_ROWS - 1))
		if _pickup_too_close(coord, placed):
			continue
		if tricks < 90:
			_spawn_pickup(coord, Pickup.Kind.TRICK)
			tricks += 1
		elif traps < 60:
			_spawn_pickup(coord, Pickup.Kind.TRAP)
			traps += 1
		placed.append(coord)

func _pickup_too_close(coord: Vector2i, placed: Array[Vector2i]) -> bool:
	for other in placed:
		var dx := coord.x - other.x
		var dy := coord.y - other.y
		if dx * dx + dy * dy < PICKUP_MIN_SEPARATION * PICKUP_MIN_SEPARATION:
			return true
	return false

func _spawn_pickup(coord: Vector2i, kind: int) -> void:
	var p : Area2D = PickupScene.instantiate()
	pkg_layer.add_child(p)
	p.position = Vector2(coord.x * TILE + TILE / 2.0,
						 coord.y * TILE + TILE / 2.0)
	p.setup(kind)
	p.body_entered.connect(_on_pickup_body_entered.bind(p))

func _on_pickup_body_entered(body: Node2D, pickup: Area2D) -> void:
	pass  # handled inside Pickup.gd

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
