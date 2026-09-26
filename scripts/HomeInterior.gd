extends "res://scripts/Interior.gd"
## A player home's interior, set up the same way as City Hall: art in a
## Background Sprite2D, collision drawn over it, and markers for the doorway,
## the spawn point and the bed.
##
## The difference from CityHallInterior is that this one is ALSO usable before
## any art exists. _is_procedural() reports false only once the Background
## sprite actually has a texture, so an empty scene still paints the plain white
## room with its bed and doorway exactly as before. Drop a texture in and the
## room switches over to the art on the next visit — nothing else to change.
##
## To finish one of these homes (see the four *Interior.tscn scenes):
##   Background   Sprite2D     assign the room art here; keep centered = false
##                             and position it so the art's top-left is (0, 0)
##   Walls        StaticBody2D add CollisionPolygon2D children over the walls
##                             and furniture in the art
##   ExitArea     Area2D       move onto the doorway in the art
##   PlayerSpawn  Marker2D     just inside that doorway
##   Bed          Marker2D     on the bed in the art — this is what E-to-sleep
##                             measures against, so it must sit on the bed
##   NPCSpots     Node2D       optional Marker2Ds for visiting villagers
##
## Then set the matching size in InteriorRegistry to the art's pixel size: the
## camera is limited to that rectangle, so a mismatch shows the void or crops
## the room.

## The art for the room, when one has been assigned.
@onready var _background : Sprite2D = get_node_or_null("Background") as Sprite2D

## Procedural until there is art to replace it. Checked rather than hard-coded
## so these scenes can be committed empty and filled in later, without the
## homes being black boxes in the meantime.
func _is_procedural() -> bool:
	return _background == null or _background.texture == null

## Keep the art behind the player. Sprite2D defaults to z_index 0, the same as
## the player, and Interior itself sits at -1000, so without this the room can
## paint over whoever walks into it.
func _ready() -> void:
	if _background != null:
		_background.z_index = -10
