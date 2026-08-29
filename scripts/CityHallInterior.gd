extends "res://scripts/Interior.gd"
## City Hall's hand-authored interior. Everything the generic room draws in code
## is replaced here by art plus collision drawn over it in the editor, so the
## only thing this script does is switch the procedural painting off — the exit
## area, sleep handling, NPC placement and camera limits are all inherited.
##
## The scene supplies:
##   Background   Sprite2D            the painted room; keep it behind the
##                                    player (see z_index note in _ready)
##   Walls        StaticBody2D        CollisionPolygon2D children drawn over the
##                                    art: outer walls, desks, counters, planters
##   ExitArea     Area2D              walked into to leave; put it on the doorway
##   PlayerSpawn  Marker2D            where the player appears, just inside it
##   NPCSpots     Node2D + Marker2D   optional: where villagers stand indoors
##
## Nothing here is required to match the generic room's geometry, but the
## InteriorDefinition's `size` should match the artwork, because the camera is
## limited to that rectangle.

func _is_procedural() -> bool:
	return false   # the scene brings its own floor, walls and furniture
