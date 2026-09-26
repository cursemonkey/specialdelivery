extends Node
## InteriorRegistry (autoload) — interior layout data keyed by building id (the
## door-marker name under Main's "Doors" node). Any building without an explicit
## entry gets a default generic room, so every building is enterable out of the
## box. Flesh interiors out by adding overrides in _register_overrides(); this
## mirrors how NPCRegistry works for villagers.

const DEFAULT_SIZE : Vector2 = Vector2(520, 360)

var _defs : Dictionary = {}   # building_id -> InteriorDefinition

func _ready() -> void:
	_register_overrides()

func get_definition(building_id: String) -> InteriorDefinition:
	if _defs.has(building_id):
		return _defs[building_id]
	var d : InteriorDefinition = InteriorDefinition.new()
	d.building_id = building_id
	d.size = DEFAULT_SIZE
	return d

func _add(def: InteriorDefinition) -> void:
	_defs[def.building_id] = def

const CityHallScene : PackedScene = preload("res://scenes/CityHallInterior.tscn")

## The four homes the player can buy. Each has its own scene so it can be given
## its own art, the same way City Hall was — see HomeInterior.gd for what to
## fill in. Until a Background texture is assigned they paint the plain
## procedural room, so these are safe to leave half-finished.
##
## `size` must match the art once there is art: the camera is limited to it.
const Townhouse15Scene : PackedScene = preload("res://scenes/Townhouse15Interior.tscn")
const ApartmentsScene  : PackedScene = preload("res://scenes/ApartmentsInterior.tscn")
const House84Scene     : PackedScene = preload("res://scenes/House84Interior.tscn")
const House10Scene     : PackedScene = preload("res://scenes/House10Interior.tscn")

func _register_overrides() -> void:
	# City Hall is large enough that the interior scrolls, and is hand-authored:
	# its art and collision live in CityHallInterior.tscn. Keep `size` matching
	# the artwork — the camera is limited to that rectangle.
	_add(_make("Building_TownHall", Vector2(1500, 960), CityHallScene))
	# The mayor's house, a touch larger than a default room.
	_add(_make("House19", Vector2(640, 440)))
	# Player homes, in the order they are offered. Sizes are the procedural
	# fallback for now — change each to its artwork's pixel size when the art
	# goes in, or the camera will show the void around it.
	_add(_make("Townhouse15", Vector2(560, 380), Townhouse15Scene))
	_add(_make("Apartments",  Vector2(560, 380), ApartmentsScene))
	_add(_make("House84",     Vector2(620, 420), House84Scene))
	_add(_make("House10",     Vector2(700, 470), House10Scene))

func _make(id: String, size: Vector2, scene: PackedScene = null) -> InteriorDefinition:
	var d : InteriorDefinition = InteriorDefinition.new()
	d.building_id = id
	d.size  = size
	d.scene = scene
	return d
