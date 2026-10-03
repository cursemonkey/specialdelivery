extends Node
## ItemRegistry (autoload) — the catalogue of carryable consumables, keyed by a
## stable string id so save data and shop stock can reference an item without
## caring about its stats.
##
## Each item is a Dictionary:
##   id        — stable key, safe to write to save files
##   name      — display name
##   icon      — emoji shown in the inventory HUD
##   price     — shop cost in dollars
##   energy    — energy restored per portion eaten
##   portions  — how many portions one purchase puts in a slot
##   sprite    — optional folder of 8 rotation frames (south.png, south-east.png
##               … see ROTATIONS). When set, the art replaces the emoji icon
##               wherever the item is drawn; the emoji stays for text messages.
##
## Prices are set against the current delivery economy (a delivery pays roughly
## $100–220): a full slot of bread is about one good delivery, so restocking is
## a real but comfortable cost.

const ITEMS : Dictionary = {
	"butter": {
		"id":       "butter",
		"name":     "Stick of Butter",
		"icon":     "🧈",
		"price":    20,
		"energy":   15,
		"portions": 1,
	},
	"bread": {
		"id":       "bread",
		"name":     "Loaf of Bread",
		"icon":     "🍞",
		"sprite":   "res://assets/Items/Bread",
		"price":    75,
		"energy":   10,
		"portions": 5,
	},
	# Laid on the Campbell farm, sold from Marsha's desk in the farmhouse.
	"eggs": {
		"id":       "eggs",
		"name":     "Box of Eggs",
		"icon":     "🥚",
		"price":    40,
		"energy":   7,
		"portions": 6,
	},
	"milk": {
		"id":       "milk",
		"name":     "Carton of Milk",
		"icon":     "🥛",
		"price":    45,
		"energy":   12,
		"portions": 3,
	},
	# ── Campbell farm produce (see FARM_STOCK) ──────────────
	# Flour is for baking, not eating: `ingredient` marks it inedible, like the
	# workshop materials, until there's a kitchen to use it in.
	"flour": {
		"id":         "flour",
		"name":       "Bag of Flour",
		"icon":       "🌾",
		"price":      25,
		"energy":     0,
		"portions":   1,
		"ingredient": true,
	},
	# Spring.
	"onions": {
		"id":       "onions",
		"name":     "Bunch of Onions",
		"icon":     "🧅",
		"price":    15,
		"energy":   3,
		"portions": 3,
	},
	"fiddleheads": {
		"id":       "fiddleheads",
		"name":     "Fiddleheads",
		"icon":     "🌿",
		"price":    30,
		"energy":   6,
		"portions": 3,
	},
	"blueberry_pie": {
		"id":       "blueberry_pie",
		"name":     "Blueberry Pie",
		"icon":     "🫐",
		"price":    90,
		"energy":   12,
		"portions": 6,
	},
	# Summer.
	"corn": {
		"id":       "corn",
		"name":     "Ears of Corn",
		"icon":     "🌽",
		"price":    30,
		"energy":   6,
		"portions": 3,
	},
	"strawberries": {
		"id":       "strawberries",
		"name":     "Basket of Strawberries",
		"icon":     "🍓",
		"price":    35,
		"energy":   4,
		"portions": 6,
	},
	"carrots": {
		"id":       "carrots",
		"name":     "Bunch of Carrots",
		"icon":     "🥕",
		"price":    20,
		"energy":   4,
		"portions": 4,
	},
	# Fall (carrots again, too).
	"pumpkin": {
		"id":       "pumpkin",
		"name":     "Pumpkin",
		"icon":     "🎃",
		"price":    40,
		"energy":   5,
		"portions": 6,
	},
	"zucchini": {
		"id":       "zucchini",
		"name":     "Zucchini",
		"icon":     "🥒",
		"price":    15,
		"energy":   5,
		"portions": 2,
	},
	# Winter.
	"meat_pie": {
		"id":       "meat_pie",
		"name":     "Meat Pie",
		"icon":     "🥟",
		"price":    80,
		"energy":   14,
		"portions": 4,
	},
	"pumpkin_pie": {
		"id":       "pumpkin_pie",
		"name":     "Pumpkin Pie",
		"icon":     "🥧",
		"price":    85,
		"energy":   12,
		"portions": 6,
	},
	# Famously unloved: see NPCRegistry._apply_fruitcake_tastes.
	"fruitcake": {
		"id":       "fruitcake",
		"name":     "Fruitcake",
		"icon":     "🍰",
		"price":    25,
		"energy":   2,
		"portions": 4,
	},
	"jam": {
		"id":       "jam",
		"name":     "Jar of Jam",
		"icon":     "🍯",
		"price":    30,
		"energy":   4,
		"portions": 5,
	},
	# Workshop materials. Not food: `material` marks them inedible, so eating
	# keys skip them and the shop describes them by the piece.
	"scrap": {
		"id":       "scrap",
		"name":     "Scrap Metal",
		"icon":     "🪛",
		"price":    10,
		"energy":   0,
		"portions": 1,
		"material": true,
	},
	"bolts": {
		"id":       "bolts",
		"name":     "Bag of Bolts",
		"icon":     "🔩",
		"price":    2,
		"energy":   0,
		"portions": 1,
		"material": true,
	},
	# Bike parts. Made at the home workbench rather than bought; using one
	# (E while holding it) bolts it onto the bike. See GameManager.fit_bike_part.
	"storage_bucket": {
		"id":       "storage_bucket",
		"name":     "Storage Bucket",
		"icon":     "🪣",
		"price":    0,
		"energy":   0,
		"portions": 1,
		"bike_part": true,
	},
}

## What the workbench can make. Each recipe consumes `inputs` (item id ->
## portions) from the bag and puts one `output` in it. Order is the order the
## crafting panel lists them.
const RECIPES : Array = [
	{"output": "storage_bucket", "inputs": {"scrap": 3, "bolts": 5}},
]

## Ids in the order Nayra offers them.
const SHOP_STOCK : Array = ["butter", "bread", "milk"]

## What Marsha sells at the farmhouse: the staples all year, plus whatever is
## in season. Use farm_stock() rather than reading these directly.
const FARM_STOCK_ALWAYS : Array = ["milk", "eggs", "flour"]
const FARM_STOCK_SEASONAL : Dictionary = {
	Calendar.Season.SPRING: ["onions", "fiddleheads", "blueberry_pie"],
	Calendar.Season.SUMMER: ["corn", "strawberries", "carrots"],
	Calendar.Season.FALL:   ["pumpkin", "zucchini", "carrots"],
	Calendar.Season.WINTER: ["meat_pie", "pumpkin_pie", "fruitcake", "jam"],
}

## Marsha's stock for `season` (a Calendar.Season), staples first.
func farm_stock(season: int) -> Array:
	var seasonal : Array = FARM_STOCK_SEASONAL.get(season, [])
	return FARM_STOCK_ALWAYS + seasonal

## Ids in the order Aidan offers them at the garage.
const GARAGE_STOCK : Array = ["scrap", "bolts"]

## True for workshop materials, which sit in the bag but can't be eaten.
func is_material(id: String) -> bool:
	return bool(get_item(id).get("material", false))

## True for cooking ingredients (flour), which can be carried and gifted but
## not eaten as they are.
func is_ingredient(id: String) -> bool:
	return bool(get_item(id).get("ingredient", false))

## True for parts that are fitted to the bike rather than eaten or used up.
func is_bike_part(id: String) -> bool:
	return bool(get_item(id).get("bike_part", false))

## Frame names in a sprite folder, in turning order: stepping through them
## spins the item a full circle.
const ROTATIONS : Array[String] = [
	"south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west",
]

var _frame_cache : Dictionary = {}   # item id -> Array[Texture2D]

## True when the item has sprite art rather than just an emoji.
func has_sprite(id: String) -> bool:
	return not rotation_frames(id).is_empty()

## The item's resting image (its first, south-facing frame), or null when it
## only has an emoji.
func icon_texture(id: String) -> Texture2D:
	var frames : Array[Texture2D] = rotation_frames(id)
	return frames[0] if not frames.is_empty() else null

## Every rotation frame in turning order, or an empty array for emoji-only
## items. Loaded once per item and cached.
func rotation_frames(id: String) -> Array[Texture2D]:
	if _frame_cache.has(id):
		return _frame_cache[id]
	var frames : Array[Texture2D] = []
	var dir : String = str(get_item(id).get("sprite", ""))
	if not dir.is_empty():
		for r in ROTATIONS:
			var tex : Texture2D = load("%s/%s.png" % [dir, r]) as Texture2D
			if tex == null:
				push_warning("ItemRegistry: '%s' is missing %s/%s.png" % [id, dir, r])
				frames.clear()
				break
			frames.append(tex)
	_frame_cache[id] = frames
	return frames

func get_item(id: String) -> Dictionary:
	return ITEMS.get(id, {})

func has(id: String) -> bool:
	return ITEMS.has(id)

func display_name(id: String) -> String:
	return str(get_item(id).get("name", id))

func icon(id: String) -> String:
	return str(get_item(id).get("icon", "•"))

func price(id: String) -> int:
	return int(get_item(id).get("price", 0))

func energy(id: String) -> int:
	return int(get_item(id).get("energy", 0))

func portions(id: String) -> int:
	return int(get_item(id).get("portions", 1))

## "Loaf of Bread — $75  (+10 energy × 5)", or for materials that have no
## energy value, just "🪛 Scrap Metal — $10".
##
## Items with sprite art leave the emoji off, since the shop shows the sprite as
## the button's icon instead.
func shop_label(id: String) -> String:
	var prefix : String = "" if has_sprite(id) else icon(id) + " "
	if is_material(id) or is_ingredient(id):
		return "%s%s — $%d" % [prefix, display_name(id), price(id)]
	var p : int = portions(id)
	var suffix : String = "" if p <= 1 else " × %d" % p
	return "%s%s — $%d  (+%d energy%s)" % [prefix, display_name(id), price(id), energy(id), suffix]
