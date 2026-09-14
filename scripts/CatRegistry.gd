extends Node
## CatRegistry (autoload) — the table of the town's cats, keyed by a stable id,
## mirroring DogRegistry.
##
## Cats work like dogs with one deliberate difference: their territories are
## far larger. A dog keeps to its owner's street; a cat treats a whole quarter
## of town as its own and is met a long way from the door it sleeps behind.
## See CatManager.TERRITORY_BONUS for the extra range added on top of these
## radii at spawn.
##
## Thirteen cats in all, eight of them nocturnal — cats keep their own hours,
## so the night shift outnumbers the day shift rather than matching it.
##
## `owner_id` is flavour for now, exactly as with dogs — nothing reads it beyond
## status text. Territories are centred on the home door and resolved to world
## positions by CatManager at spawn.

## One cat's data. Plain fields; no behaviour lives here.
class CatDefinition:
	extends RefCounted
	var id          : String  = ""
	var cat_name    : String  = "Cat"
	var owner_id    : String  = ""
	var home_anchor : String  = ""
	var radius      : float   = 320.0
	var out_start   : float   = 8.0
	var out_end     : float   = 18.0
	var coat        : Color   = Color("#8a8a8a")
	var accent      : Color   = Color("#e8e2d8")   # belly / paws / muzzle

	## True when this cat is out at `hour`, wrapping past midnight if needed.
	func is_out_at(hour: float) -> bool:
		if out_start < out_end:
			return hour >= out_start and hour < out_end
		return hour >= out_start or hour < out_end

	## "day" or "night", by which half of the clock the window mostly sits in.
	func shift() -> String:
		return "night" if out_start > out_end or out_start >= 17.0 else "day"

var _defs : Array = []

func _ready() -> void:
	_register_all()

func all_definitions() -> Array:
	return _defs

func get_definition(id: String) -> CatDefinition:
	for c in _defs:
		if c.id == id:
			return c
	return null

## Cats whose window currently has them outside.
func out_at(hour: float) -> Array:
	var out : Array = []
	for c in _defs:
		if c.is_out_at(hour):
			out.append(c)
	return out

## How many of the cast keep night hours. Used by the tests and handy when
## rebalancing the day/night split.
func night_count() -> int:
	var n : int = 0
	for c in _defs:
		if c.shift() == "night":
			n += 1
	return n

func _add(c: CatDefinition) -> void:
	_defs.append(c)

func _make(id: String, cat_name: String, owner_id: String, home_anchor: String,
		out_start: float, out_end: float, radius: float,
		coat: String, accent: String) -> CatDefinition:
	var c : CatDefinition = CatDefinition.new()
	c.id          = id
	c.cat_name    = cat_name
	c.owner_id    = owner_id
	c.home_anchor = home_anchor
	c.out_start   = out_start
	c.out_end     = out_end
	c.radius      = radius
	c.coat        = Color(coat)
	c.accent      = Color(accent)
	return c

# ── The colony ─────────────────────────────────────────────
# Thirteen cats: five daytime, eight nocturnal. Radii here are already roughly
# double a dog's, and CatManager widens them much further still — these values
# are the relative difference between one cat's range and another's.
#
# Every home_anchor below must name a real node under Main's "Doors" — an
# unknown name resolves to Vector2.ZERO and strands the cat at the world origin
# rather than erroring. Note that "House4" is NOT such a node (the map has
# House3 and House40, no House4), even though Aidan's NPCDefinition and his dog
# Rivet both use it; don't copy that anchor here.
func _register_all() -> void:
	# ── Daytime (5) ──
	# The farm cat, out over the fields while the work is going on. Biggest
	# range of the day cats — nothing but open ground out there.
	_add(_make("barley",  "Barley",  "flower_campbell",   "Farm",        6.0,  18.0, 460.0, "#c98f4a", "#f2e3c8"))
	# The grocer's mouser, works the shop hours with Silas.
	_add(_make("pickle",  "Pickle",  "silas_thorne",      "Grocery",     8.0,  18.0, 300.0, "#5a5a62", "#dcdce4"))
	# Library cat — asleep in a sunbeam most of the day, but ranges when awake.
	_add(_make("dewey",   "Dewey",   "nayra",             "Library",     9.0,  17.0, 330.0, "#3a3a3a", "#f0f0f0"))
	# The cafe cat, out from opening; cadges scraps along the whole high street.
	_add(_make("crumb",   "Crumb",   "marco",             "Cafe",        6.5,  16.0, 380.0, "#e8d9b0", "#fffaf0"))
	# City Hall's resident, patrols the square and the civic end of town.
	_add(_make("chancery","Chancery","mayor_henderson",   "Building_TownHall", 8.0, 17.0, 350.0, "#9c8f7a", "#e6ddd0"))

	# ── Night (8) ──
	# The parsonage cat, out over the churchyard and the whole east side.
	_add(_make("vesper",  "Vesper",  "elias_thorne",      "House138",   19.0,   5.0, 430.0, "#2c2c34", "#c8c8d4"))
	# Junia's, follows Vesper around at a distance. Smaller circuit, still wide.
	_add(_make("moth",    "Moth",    "junia_thorne",      "House138",   20.0,   4.5, 340.0, "#8a8290", "#efe8f2"))
	# The pub cat — out from closing time, ranges the length of the main road.
	_add(_make("stout",   "Stout",   "elsie_carrington",  "Pub",        21.0,   4.0, 470.0, "#4a3b30", "#d8c4a8"))
	# Hospital cat, keeps the night shift company and wanders far between rounds.
	_add(_make("saffron", "Saffron", "doctor_carrington", "Hospital",   18.0,   6.0, 400.0, "#d9772f", "#f7e0c0"))
	# The mechanic's, out once the garage shuts; oil-black and hard to spot.
	# Anchored on the shop rather than Aidan's house: "House4" (his home_anchor,
	# and his dog Rivet's) has no matching node under Main's Doors, so it
	# silently resolves to the world origin — see the note in _register_all.
	_add(_make("gasket",  "Gasket",  "aidan",             "Mechanic",   19.5,   5.5, 390.0, "#26262a", "#7a7a82"))
	# Apartments cat, roams the rooftops and back alleys all night.
	_add(_make("juniper", "Juniper", "nayra",             "Apartments", 20.0,   5.0, 360.0, "#6b7a8f", "#e0e8f0"))
	# The station cat — out with the late patrol, covers a wide beat.
	_add(_make("bandit",  "Bandit",  "kali",              "Police",     19.0,   6.0, 440.0, "#3f3f45", "#f4f4f4"))
	# Darin's, the oldest of them. Late riser, dawn wanderer, modest range.
	_add(_make("marmalade", "Marmalade", "darin",         "House72",    22.0,   7.0, 310.0, "#e09a3e", "#fff2d8"))
