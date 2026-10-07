extends Node2D
## CatManager — spawns and owns the town's cats. Created from Main._ready().
##
## Data-driven in the same way as DogManager and NPCManager: definitions live in
## CatRegistry, and this manager resolves each one's home-door anchor into a
## world position (the centre of that cat's territory) and instances a Cat. To
## add or edit a cat, edit CatRegistry, not this file.

const CatScene : PackedScene = preload("res://scenes/Cat.tscn")

## Added to every cat's registry radius. Far larger than the dogs' equivalent
## (DogManager.TERRITORY_BONUS, 500) because a cat is expected to turn up right
## across its quarter of town rather than near the door it sleeps behind.
const TERRITORY_BONUS : float = 1100.0

var _doors : Node  = null
var _cats  : Array = []

func setup(doors_root: Node) -> void:
	_doors = doors_root

func spawn_all() -> void:
	for c in _cats:
		if is_instance_valid(c):
			c.queue_free()
	_cats.clear()
	for def in CatRegistry.all_definitions():
		_spawn(def)

func _spawn(def) -> void:
	var cat : CharacterBody2D = CatScene.instantiate()
	add_child(cat)
	cat.id               = def.id
	cat.cat_name         = def.cat_name
	cat.owner_id         = def.owner_id
	cat.home_anchor      = def.home_anchor
	cat.territory_centre = _anchor_pos(def.home_anchor)
	# Territories were widened by TERRITORY_BONUS so cats range across a whole
	# quarter of town; the per-cat radius in CatRegistry stays the relative
	# difference between one cat's range and another's.
	cat.territory_radius = def.radius + TERRITORY_BONUS
	cat.out_start        = def.out_start
	cat.out_end          = def.out_end
	var sprite : Node2D = cat.get_node("CatSprite")
	sprite.coat_color   = def.coat
	sprite.accent_color = def.accent
	# Place it correctly for the current hour straight away, rather than waiting
	# for the first physics frame to notice it should be indoors.
	cat.global_position = cat.territory_centre
	_cats.append(cat)

## All spawned cats, for Main's Rizz tick and the indoors scatter.
func cats() -> Array:
	return _cats

## How many cats are currently trailing the player.
func following_count() -> int:
	var n : int = 0
	for c in _cats:
		if is_instance_valid(c) and c.is_following():
			n += 1
	return n

## Hand each follower its place in the line, counting from the player back, so
## the parade forms a queue instead of a pile. `start_slot` lets Main reserve
## the earlier slots for the birds and dogs, keeping one shared line across
## every species. Order follows join order, so the cat picked up first walks
## nearest.
func assign_parade_slots(start_slot: int) -> int:
	var slot : int = start_slot
	for c in _cats:
		if is_instance_valid(c) and c.is_following():
			c.parade_slot = slot
			slot += 1
	return slot

## Send every following cat home (the player went indoors). Returns how many
## were actually let go, so the caller can word the message.
func scatter_following() -> int:
	var n : int = 0
	for c in _cats:
		if is_instance_valid(c) and c.is_following():
			c.stop_following()
			n += 1
	return n

## Cats currently inside `building_id` — used to show them in interiors.
func cats_inside(building_id: String) -> Array:
	var out : Array = []
	for c in _cats:
		if is_instance_valid(c) and c.inside_building() == building_id:
			out.append(c)
	return out

func _anchor_pos(door_name: String) -> Vector2:
	door_name = InteriorRegistry.street_door_of(door_name)   # a flat -> its building
	if _doors != null:
		var door : Node2D = _doors.get_node_or_null(door_name) as Node2D
		if door != null:
			return door.global_position
	return Vector2.ZERO
