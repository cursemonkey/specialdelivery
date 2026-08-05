extends SceneTree
func _initialize() -> void:
	await process_frame
	await process_frame
	var main = current_scene
	var world = main.get_node_or_null("WorldGenerator")
	if world == null:
		print("NO WORLDGEN"); quit(); return
	var layer = world.get_node("PickupLayer")
	var kids = layer.get_children()
	print("PICKUP COUNT: ", kids.size())
	var counts = {0:0, 1:0, 2:0}
	var on_road := 0
	var roads = root.get_tree().get_nodes_in_group("road_zone")
	for k in kids:
		counts[k.kind] = counts[k.kind] + 1
		for r in roads:
			var np : NavigationPolygon = r.navigation_polygon
			if np == null: continue
			var lp : Vector2 = r.to_local(k.global_position)
			var hit := false
			for oi in np.get_outline_count():
				if Geometry2D.is_point_in_polygon(lp, np.get_outline(oi)):
					hit = true; break
			if hit:
				on_road += 1
				break
	print("RAMP/PUDDLE/POTHOLE: ", counts)
	print("ON ROAD: ", on_road, " / ", kids.size())
	quit()
