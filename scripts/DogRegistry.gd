extends Node
## DogRegistry (autoload) — the table of the town's dogs, keyed by a stable id,
## mirroring how NPCRegistry works for villagers.
##
## Each dog lives with a human villager, keeps to a small territory around its
## home door, and is outside only during its own hours. Six are daytime dogs and
## four are night dogs, with the windows deliberately overlapping so dawn and
## dusk have a mix of both rather than a clean shift change.
##
## `owner_id` is flavour for now — nothing reads it yet beyond the status text.
## Territories are centred on the owner's door and resolved to world positions
## by DogManager at spawn.

## One dog's data. Plain fields; no behaviour lives here.
class DogDefinition:
	extends RefCounted
	var id          : String  = ""
	var dog_name    : String  = "Dog"
	var owner_id    : String  = ""
	var home_anchor : String  = ""
	var radius      : float   = 150.0
	var out_start   : float   = 8.0
	var out_end     : float   = 18.0
	var coat        : Color   = Color("#8a6242")
	var collar      : Color   = Color("#c0392b")

	## True when this dog is out at `hour`, wrapping past midnight if needed.
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

func get_definition(id: String) -> DogDefinition:
	for d in _defs:
		if d.id == id:
			return d
	return null

## Dogs whose window currently has them outside.
func out_at(hour: float) -> Array:
	var out : Array = []
	for d in _defs:
		if d.is_out_at(hour):
			out.append(d)
	return out

func _add(d: DogDefinition) -> void:
	_defs.append(d)

func _make(id: String, dog_name: String, owner_id: String, home_anchor: String,
		out_start: float, out_end: float, radius: float,
		coat: String, collar: String) -> DogDefinition:
	var d : DogDefinition = DogDefinition.new()
	d.id          = id
	d.dog_name    = dog_name
	d.owner_id    = owner_id
	d.home_anchor = home_anchor
	d.out_start   = out_start
	d.out_end     = out_end
	d.radius      = radius
	d.coat        = Color(coat)
	d.collar      = Color(collar)
	return d

# ── The pack ───────────────────────────────────────────────
# Six daytime dogs, four night dogs. Windows overlap around dawn (5\u20138) and dusk
# (17\u201320) so the streets are never empty of dogs at the changeover.
func _register_all() -> void:
	# \u2500\u2500 Daytime \u2500\u2500
	# Aidan's shop dog: out while the garage is open, wide roaming radius.
	_add(_make("rivet",   "Rivet",   "aidan",            "House4",      7.0,  18.0, 190.0, "#6b5342", "#3a6ea5"))
	# Kali's, out early with the morning shift.
	_add(_make("scout",   "Scout",   "kali",             "House70",     5.5,  15.0, 160.0, "#3f3a35", "#2f4a7a"))
	# Darin's old boy: short hours, small circuit, sleeps a lot.
	_add(_make("sarge",   "Sarge",   "darin",            "House72",     9.0,  16.0, 110.0, "#9c9186", "#1e3560"))
	# Spider's mum's place \u2014 out all day while the band sleeps.
	_add(_make("banjo",   "Banjo",   "elsie_carrington", "House60",     8.0,  19.0, 175.0, "#4a3b30", "#b3352f"))
	# Marco's, hangs about near the cafe end of town from opening time.
	_add(_make("biscuit", "Biscuit", "marco",            "House98",     6.0,  17.0, 165.0, "#c9a227", "#7a4b2a"))
	# The mayor's, patrols the square by City Hall.
	_add(_make("mayor",   "Chancellor", "mayor_henderson", "House96",   8.5,  17.5, 145.0, "#e0d6c4", "#6a4c93"))

	# \u2500\u2500 Night \u2500\u2500
	# Farm dog, out from dusk to sunrise across a big yard.
	_add(_make("clover",  "Clover",  "flower_campbell",  "Farm",       18.0,   6.0, 210.0, "#8a6242", "#3f7d4a"))
	# The Thornes' \u2014 late roamer around the east side.
	_add(_make("ember",   "Ember",   "elias_thorne",     "House138",   19.0,   5.0, 170.0, "#7a3b2a", "#d4a020"))
	# Nayra's, out after the shop shuts, keeps near the Apartments.
	_add(_make("mochi",   "Mochi",   "nayra",            "Apartments", 20.0,   4.0, 130.0, "#2e2a28", "#8fbf8a"))
	# Doctor's dog, overlaps both ends \u2014 out at dusk, in after dawn.
	_add(_make("pepper",  "Pepper",  "doctor_carrington","House10",    17.0,   7.0, 155.0, "#5c5c5c", "#c9d1d9"))
