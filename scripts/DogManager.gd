extends Node2D
## DogManager — spawns and owns the town's dogs. Created from Main._ready().
##
## Data-driven in the same way as NPCManager: definitions live in DogRegistry,
## and this manager resolves each one's home-door anchor into a world position
## (the centre of that dog's territory) and instances a Dog. To add or edit a
## dog, edit DogRegistry, not this file.

const DogScene : PackedScene = preload("res://scenes/Dog.tscn")

## Added to every dog's registry radius, so the pack ranges well beyond their
## own doorstep and is met out in the streets rather than only at home.
const TERRITORY_BONUS : float = 500.0

var _doors : Node  = null
var _dogs  : Array = []

func setup(doors_root: Node) -> void:
	_doors = doors_root

func spawn_all() -> void:
	for d in _dogs:
		if is_instance_valid(d):
			d.queue_free()
	_dogs.clear()
	for def in DogRegistry.all_definitions():
		_spawn(def)

func _spawn(def) -> void:
	var dog : CharacterBody2D = DogScene.instantiate()
	add_child(dog)
	dog.id               = def.id
	dog.dog_name         = def.dog_name
	dog.owner_id         = def.owner_id
	dog.home_anchor      = def.home_anchor
	dog.territory_centre = _anchor_pos(def.home_anchor)
	# Territories were widened by TERRITORY_BONUS so dogs range further from
	# home; the per-dog radius in DogRegistry stays the relative difference.
	dog.territory_radius = def.radius + TERRITORY_BONUS
	dog.out_start        = def.out_start
	dog.out_end          = def.out_end
	var sprite : Node2D = dog.get_node("DogSprite")
	sprite.coat_color   = def.coat
	sprite.collar_color = def.collar
	# Place it correctly for the current hour straight away, rather than waiting
	# for the first physics frame to notice it should be indoors.
	dog.global_position = dog.territory_centre
	_dogs.append(dog)

## All spawned dogs, for Main's Rizz tick and the indoors scatter.
func dogs() -> Array:
	return _dogs

## How many dogs are currently trailing the player.
func following_count() -> int:
	var n : int = 0
	for d in _dogs:
		if is_instance_valid(d) and d.is_following():
			n += 1
	return n

## Hand each follower its place in the line, counting from the player back, so
## the parade forms a queue instead of a pile. `start_slot` lets Main reserve
## the front slots for the birds, keeping one shared line across both species.
## Order follows join order, so the dog picked up first walks nearest.
func assign_parade_slots(start_slot: int) -> int:
	var slot : int = start_slot
	for d in _dogs:
		if is_instance_valid(d) and d.is_following():
			d.parade_slot = slot
			slot += 1
	return slot

## Send every following dog home (the player went indoors). Returns how many
## were actually let go, so the caller can word the message.
func scatter_following() -> int:
	var n : int = 0
	for d in _dogs:
		if is_instance_valid(d) and d.is_following():
			d.stop_following()
			n += 1
	return n

## Dogs currently inside `building_id` — used to show them in interiors.
func dogs_inside(building_id: String) -> Array:
	var out : Array = []
	for d in _dogs:
		if is_instance_valid(d) and d.inside_building() == building_id:
			out.append(d)
	return out

func _anchor_pos(door_name: String) -> Vector2:
	if _doors != null:
		var door : Node2D = _doors.get_node_or_null(door_name) as Node2D
		if door != null:
			return door.global_position
	return Vector2.ZERO
