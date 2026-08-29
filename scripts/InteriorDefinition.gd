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

func has_custom_scene() -> bool:
	return scene != null
