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
		"price":    75,
		"energy":   10,
		"portions": 5,
	},
	"milk": {
		"id":       "milk",
		"name":     "Carton of Milk",
		"icon":     "🥛",
		"price":    45,
		"energy":   12,
		"portions": 3,
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
}

## Ids in the order Nayra offers them.
const SHOP_STOCK : Array = ["butter", "bread", "milk"]

## Ids in the order Aidan offers them at the garage.
const GARAGE_STOCK : Array = ["scrap", "bolts"]

## True for workshop materials, which sit in the bag but can't be eaten.
func is_material(id: String) -> bool:
	return bool(get_item(id).get("material", false))

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
func shop_label(id: String) -> String:
	if is_material(id):
		return "%s %s — $%d" % [icon(id), display_name(id), price(id)]
	var p : int = portions(id)
	var suffix : String = "" if p <= 1 else " × %d" % p
	return "%s %s — $%d  (+%d energy%s)" % [icon(id), display_name(id), price(id), energy(id), suffix]
