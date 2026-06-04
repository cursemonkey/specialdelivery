extends Node2D
## WorldGenerator — builds the entire town at runtime:
##   • Paints grass / road tiles on a TileMap
##   • Places Building nodes in every land block
##   • Scatters Pickup nodes (tricks & traps) on road tiles
##   • Exposes select_targets() and clear_targets() for day management

const TILE          := 16
const COLS          := 80
const ROWS          := 60
const ROAD_W        := 4

# Full map bounds for pickup spawning (matches camera limits in Main.gd)
const MAP_COLS      := 415
const MAP_ROWS      := 313

# Horizontal road top-edges (tile rows)
const ROAD_ROWS     := [18, 50, 70, 110]
# Vertical road left-edges (tile cols)
const ROAD_COLS     := [8, 22, 36, 50, 64]

# TileMap source / atlas IDs — we'll paint programmatically using
# a single-pixel colour atlas built at runtime (see _build_tileset)
const SOURCE_ID     := 0

# Colours
const C_GRASS        := Color("#c8dfa0")
const C_ROAD         := Color("#b0b8c8")
const C_ROAD_MARK    := Color("#9aa8b8")
const C_INTERSECT    := Color("#a8b0c0")

const HOUSE_PALETTES : Array = [
	[Color("#e8c99a"), Color("#c0392b"), Color("#f5deb3")],
	[Color("#b8d4e8"), Color("#2980b9"), Color("#ddeeff")],
	[Color("#c8e6b0"), Color("#27ae60"), Color("#e8f8e0")],
	[Color("#f0d4a8"), Color("#e67e22"), Color("#ffe8c0")],
	[Color("#d4b8d8"), Color("#8e44ad"), Color("#eeddf5")],
	[Color("#f8e0d0"), Color("#e74c3c"), Color("#fff0e8")],
	[Color("#d0e8c8"), Color("#16a085"), Color("#e4f5e0")],
]

# Preloaded packed scenes
const BuildingScene  := preload("res://scenes/Building.tscn")
const PickupScene    := preload("res://scenes/Pickup.tscn")
const PackageScene   := preload("res://scenes/ThrownPackage.tscn")

# ── Runtime data ────────────────────────────────────────────
var buildings       : Array = []   # all Building nodes
var road_tiles      : Array = []   # Vector2i of road tile coords
var _rng            := RandomNumberGenerator.new()

@onready var tile_map  : TileMap = $TileMap
@onready var bld_layer : Node2D  = $BuildingLayer
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
	_place_buildings()
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

# ── Block extraction ───────────────────────────────────────
func _get_blocks() -> Array:
	var row_bands := _extract_bands(ROAD_ROWS, ROWS)
	var col_bands := _extract_bands(ROAD_COLS, COLS)
	var blocks := []
	for rb in row_bands:
		for cb in col_bands:
			if rb[1] - rb[0] > 3 and cb[1] - cb[0] > 3:
				blocks.append([rb[0], rb[1], cb[0], cb[1]])  # r1,r2,c1,c2
	return blocks

func _extract_bands(road_starts: Array, total: int) -> Array:
	var bands := []
	var start := 0
	for i in road_starts.size() + 1:
		var end: int = road_starts[i] if i < road_starts.size() else total
		if end - start > 2:
			bands.append([start, end])
		if i < road_starts.size():
			start = road_starts[i] + ROAD_W
	return bands

# ── Building placement ─────────────────────────────────────
func _place_buildings() -> void:
	var blocks := _get_blocks()
	for blk in blocks:
		var r1 : int = blk[0] + 1
		var r2 : int = blk[1] - 1
		var c1 : int = blk[2] + 1
		var c2 : int = blk[3] - 1
		if r2 - r1 < 3 or c2 - c1 < 3:
			continue
		var c := c1
		while c < c2 - 2:
			var max_w : int = min(c2 - c, 18)
			var roll  := _rng.randf()
			var btype : int
			var bw    : int
			var bh    : int
			if roll < 0.10 and max_w >= 18:
				btype = Building.BuildingType.BUILDING
				bw    = 18 + _rng.randi_range(0, 4)
				bh    = r2 - r1
			elif roll < 0.25 and max_w >= 13:
				btype = Building.BuildingType.MANSION
				bw    = 13
				bh    = min(r2 - r1, 9)
			else:
				btype = Building.BuildingType.HOUSE
				bw    = 9
				bh    = min(r2 - r1, 8)

			bw = min(bw, c2 - c)
			if bw < 4:
				c += 1
				continue


			var idx := _rng.randi() % HOUSE_PALETTES.size()
			var pal: Array = HOUSE_PALETTES[idx]
			
			var bnode : StaticBody2D = BuildingScene.instantiate()
			bld_layer.add_child(bnode)
			bnode.position = Vector2(c * TILE, r1 * TILE)
			bnode.setup(btype, bw, bh, pal[0], pal[1], pal[2], buildings.size())

			# Door world position (centre of bottom row)
			var door_local := Vector2((bw / 2) * TILE + TILE / 2.0, (bh - 1) * TILE + TILE)
			bnode.door_position = bnode.position + door_local

			# Collision shape covering the building
			var shape := RectangleShape2D.new()
			shape.size = Vector2(bw * TILE, bh * TILE)
			var col := CollisionShape2D.new()
			col.shape  = shape
			col.position = shape.size / 2.0
			bnode.add_child(col)

			buildings.append(bnode)
			c += bw + 1 + _rng.randi_range(0, 1)

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
