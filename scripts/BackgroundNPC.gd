class_name BackgroundNPC
extends NPCBase
## Ambient villager — not interactable. Follows a simple route keyed only by
## the day phase: route_points[0] = day, [1] = sunset, [2] = night.
## Give it 2 points and it reuses the last one for the night.

var route_points : Array[Vector2] = []

func _retarget(_immediate: bool = false) -> void:
	if route_points.is_empty():
		return
	var idx : int = mini(TimeManager.phase, route_points.size() - 1)
	set_move_target(route_points[idx])
