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

## Each house's second room, through a doorway in its east wall: a garage for
## the houses, a back yard for the townhouse. Each holds the workbench (see
## HomeAnnex.gd) and, like the homes, paints itself procedurally until it has
## art. The apartments are different — see _register_apartments().
const Townhouse15BackYardScene : PackedScene = preload("res://scenes/Townhouse15BackYard.tscn")
const ApartmentsGarageScene    : PackedScene = preload("res://scenes/ApartmentsGarage.tscn")
const House84GarageScene       : PackedScene = preload("res://scenes/House84Garage.tscn")
const House10GarageScene       : PackedScene = preload("res://scenes/House10Garage.tscn")

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
	_register_apartments()
	_add(_make("House84",     Vector2(620, 420), House84Scene))
	_add(_make("House10",     Vector2(700, 470), House10Scene))
	# …and the room behind each. Room ids aren't door markers, so these can only
	# be reached from inside the home they belong to.
	_link_rooms("Townhouse15", "Townhouse15_BackYard", "Back Yard", "grass",    Vector2(560, 360), Townhouse15BackYardScene)
	_link_rooms("House84",     "House84_Garage",       "Garage",    "concrete", Vector2(520, 360), House84GarageScene)
	_link_rooms("House10",     "House10_Garage",       "Garage",    "concrete", Vector2(560, 380), House10GarageScene)

# ── The apartment block ────────────────────────────────────
## Four storeys joined by an elevator:
##   Basement  the residents' garage, with the player's workbench
##   Floor 1   the lobby, with the main entrance from the street
##   Floor 2   a hallway with flats 201–204
##   Floor 3   a hallway with flats 301–304; 301 is the one the player can buy
## Only the lobby has a street door ("Apartments" is the door marker), so every
## other room is reached through it. The building id stays "Apartments" for the
## home choice, saves and the map; the bed is in APARTMENT_HOME_ROOM.
const APARTMENT_HOME_ROOM : String = "Apartments_301"
const APARTMENT_SHAFT     : String = "Apartments"

## Elevator shaft id -> its stops, bottom to top, as {room, label}.
var _elevators : Dictionary = {}

func _register_apartments() -> void:
	var lobby : InteriorDefinition = _make("Apartments", Vector2(560, 380))
	lobby.title      = "Floor 1 — Lobby"
	lobby.enter_hint = "🏢 Lobby. The elevator goes down to the garage and up to the flats."
	lobby.doors      = [InteriorDefinition.make_elevator(InteriorDefinition.SIDE_NORTH)]
	lobby.elevator   = APARTMENT_SHAFT
	_add(lobby)

	var basement : InteriorDefinition = _make("Apartments_Basement", Vector2(560, 380), ApartmentsGarageScene)
	basement.title       = "Basement — Garage"
	basement.floor_style = "concrete"
	basement.street_exit = false
	basement.owner_home  = "Apartments"
	basement.doors       = [InteriorDefinition.make_elevator(InteriorDefinition.SIDE_WEST)]
	basement.elevator    = APARTMENT_SHAFT
	_add(basement)

	for floor_no in [2, 3]:
		_register_apartment_floor(floor_no)

	var home : InteriorDefinition = _defs[APARTMENT_HOME_ROOM]
	home.home_hint = "Your workbench is in the basement garage — take the elevator."

	_elevators[APARTMENT_SHAFT] = [
		{"room": "Apartments_Basement", "label": "Basement — Garage"},
		{"room": "Apartments",          "label": "Floor 1 — Lobby"},
		{"room": "Apartments_F2",       "label": "Floor 2"},
		{"room": "Apartments_F3",       "label": "Floor 3"},
	]

## A hallway with the elevator at its west end and four flats off its north
## wall, each flat's own door in its south wall leading back out.
func _register_apartment_floor(floor_no: int) -> void:
	var hall_id : String = "Apartments_F%d" % floor_no
	var hall : InteriorDefinition = _make(hall_id, Vector2(800, 220))
	hall.title       = "Floor %d — Hallway" % floor_no
	hall.floor_style = "carpet"
	hall.street_exit = false
	hall.elevator    = APARTMENT_SHAFT
	var doors : Array = [InteriorDefinition.make_elevator(InteriorDefinition.SIDE_WEST)]
	var along : Array[float] = [0.32, 0.48, 0.64, 0.80]
	for i in 4:
		var number  : String = "%d0%d" % [floor_no, i + 1]
		var flat_id : String = "Apartments_" + number
		doors.append(InteriorDefinition.make_door(flat_id, number, InteriorDefinition.SIDE_NORTH, along[i]))
		# 301 is the flat the player can buy, so it has its own scene with a
		# bed; the rest are plain rooms for now.
		var is_home : bool = flat_id == APARTMENT_HOME_ROOM
		var flat : InteriorDefinition = _make(flat_id, Vector2(560, 380) if is_home else Vector2(440, 320),
				ApartmentsScene if is_home else null)
		flat.title       = "Apartment " + number
		flat.street_exit = false
		flat.doors       = [InteriorDefinition.make_door(hall_id, "Hallway", InteriorDefinition.SIDE_SOUTH)]
		_add(flat)
	hall.doors = doors
	_add(hall)

## The stops of the elevator `shaft`, bottom to top, as {room, label}.
func elevator_stops(shaft: String) -> Array:
	return _elevators.get(shaft, [])

## The room holding the bed for player home `home_id`: the home itself, except
## for the apartments, where it's the flat upstairs rather than the lobby.
func home_room(home_id: String) -> String:
	if home_id == "Apartments":
		return APARTMENT_HOME_ROOM
	return home_id

## Register `room_id` as the room through the east wall of `home_id` (already
## registered), with the doorway in each signed for the other. The way in only
## exists once `home_id` is the player's home.
func _link_rooms(home_id: String, room_id: String, label: String, floor_style: String, size: Vector2, scene: PackedScene) -> void:
	var home : InteriorDefinition = _defs[home_id]
	home.doors.append(InteriorDefinition.make_door(room_id, label, InteriorDefinition.SIDE_EAST, 0.5, home_id))
	home.home_hint = "The %s is through the east doorway." % label.to_lower()
	var room : InteriorDefinition = _make(room_id, size, scene)
	room.doors       = [InteriorDefinition.make_door(home_id, "Indoors", InteriorDefinition.SIDE_WEST)]
	room.floor_style = floor_style
	_add(room)

func _make(id: String, size: Vector2, scene: PackedScene = null) -> InteriorDefinition:
	var d : InteriorDefinition = InteriorDefinition.new()
	d.building_id = id
	d.size  = size
	d.scene = scene
	return d
