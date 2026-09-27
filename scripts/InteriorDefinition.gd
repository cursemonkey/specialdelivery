class_name InteriorDefinition
extends Resource
## Layout data for one building interior, keyed by building id (the door-marker
## name) in InteriorRegistry. v1 is a single plain room; floors, furniture, and
## NPC spawn points come in later phases.

@export var building_id   : String  = ""
@export var size          : Vector2 = Vector2(520, 360)  # room size in px
@export var doorway_width : float   = 64.0               # width of the south exit

## Optional hand-authored interior. When set, InteriorManager instantiates this
## instead of the generic procedural room, so a building can have painted art
## and collision drawn over it in the editor. The scene must honour the same
## contract as Interior.gd — easiest by extending it (see CityHallInterior.gd).
## Left null, the building gets the generic room as before.
@export var scene         : PackedScene = null

## A second room reached through a doorway inside this one, rather than from
## the street: a player home's garage or back yard, and the way back from it.
## `link_id` is that room's id in InteriorRegistry ("" = no such doorway),
## `link_label` is what the doorway is signed as, and `link_side` is the wall it
## sits in — homes put it in the east wall, their annexes in the west, so the
## two doorways face each other.
@export var link_id    : String = ""
@export var link_label : String = ""
@export var link_side  : int    = SIDE_EAST

const SIDE_EAST : int = 0
const SIDE_WEST : int = 1

## Floor for the procedural room: "tiles" (the white checkerboard), "concrete"
## (a garage) or "grass" (a back yard).
@export var floor_style : String = "tiles"

func has_link() -> bool:
	return not link_id.is_empty()

func has_custom_scene() -> bool:
	return scene != null
