extends Node2D
## DogManager — spawns and owns the town's dogs. Created from Main._ready().
##
## Data-driven in the same way as NPCManager: definitions live in DogRegistry,
## and this manager resolves each one's home-door anchor into a world position
## (the centre of that dog's territory) and instances a Dog. To add or edit a
## dog, edit DogRegistry, not this file.

const DogScene : PackedScene = preload("res://scenes/Dog.tscn")

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
	var dog : Area2D = DogScene.instantiate()
	add_child(dog)
	dog.id               = def.id
	dog.dog_name         = def.dog_name
	dog.owner_id         = def.owner_id
	dog.home_anchor      = def.home_anchor
	dog.territory_centre = _anchor_pos(def.home_anchor)
	dog.territory_radius = def.radius
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
