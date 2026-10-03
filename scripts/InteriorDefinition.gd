class_name InteriorDefinition
extends Resource
## Layout data for one building interior, keyed by building id (the door-marker
## name) in InteriorRegistry. v1 is a single plain room; floors, furniture, and
## NPC spawn points come in later phases.

@export var building_id   : String  = ""
@export var size          : Vector2 = Vector2(520, 360)  # room size in px
@export var doorway_width : float   = 64.0               # width of every doorway

## Optional hand-authored interior. When set, InteriorManager instantiates this
## instead of the generic procedural room, so a building can have painted art
## and collision drawn over it in the editor. The scene must honour the same
## contract as Interior.gd — easiest by extending it (see CityHallInterior.gd).
## Left null, the building gets the generic room as before.
@export var scene         : PackedScene = null

## Whether the room has the usual south doorway out to the street. Rooms deeper
## inside a building (a hallway upstairs, a flat off it, a basement) don't: the
## only ways out are their doors to other rooms.
@export var street_exit : bool = true

## Doorways to other rooms in the same building, as opposed to the street exit.
## Each is a Dictionary, built with make_door() / make_elevator():
##   to     room id in InteriorRegistry this leads to ("" for an elevator)
##   label  what the doorway is signed as
##   side   the wall it sits in (SIDE_*)
##   at     where along that wall, 0..1 (west→east, or north→south)
##   kind   KIND_DOOR, or KIND_ELEVATOR — walking in asks which floor
##   owner  optional home id: the doorway only exists while that is the
##          player's home (a house's garage door, for instance)
@export var doors : Array = []

## The elevator shaft this room's elevator belongs to (see
## InteriorRegistry.elevator_stops), when it has one.
@export var elevator : String = ""

## Optional sign painted in the room's top-left corner ("Floor 2 — Hallway").
@export var title : String = ""

## Shown on entering from the street instead of the generic "Inside" message.
@export var enter_hint : String = ""

## For a player home's bed room: what to tell the player about the rest of the
## home ("The garage is through the east doorway.").
@export var home_hint : String = ""

## When set, the room's workbench only works while this is the player's home —
## a shared basement garage shouldn't let anyone craft at the owner's bench.
@export var owner_home : String = ""

const SIDE_EAST  : int = 0
const SIDE_WEST  : int = 1
const SIDE_NORTH : int = 2
const SIDE_SOUTH : int = 3

const KIND_DOOR     : String = "door"
const KIND_ELEVATOR : String = "elevator"

## Floor for the procedural room: "tiles" (the white checkerboard), "concrete"
## (a garage), "grass" (a back yard) or "carpet" (a hallway).
@export var floor_style : String = "tiles"

static func make_door(to: String, label: String, side: int, at: float = 0.5, owner: String = "") -> Dictionary:
	return {"to": to, "label": label, "side": side, "at": at, "kind": KIND_DOOR, "owner": owner}

static func make_elevator(side: int, at: float = 0.5) -> Dictionary:
	return {"to": "", "label": "Elevator", "side": side, "at": at, "kind": KIND_ELEVATOR, "owner": ""}

func has_custom_scene() -> bool:
	return scene != null
