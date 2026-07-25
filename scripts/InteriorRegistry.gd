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

func _register_overrides() -> void:
	# City Hall is large enough that the interior scrolls.
	_add(_make("Building_TownHall", Vector2(1500, 960)))
	# The mayor's house, a touch larger than a default room.
	_add(_make("House19", Vector2(640, 440)))

func _make(id: String, size: Vector2) -> InteriorDefinition:
	var d : InteriorDefinition = InteriorDefinition.new()
	d.building_id = id
	d.size = size
	return d
