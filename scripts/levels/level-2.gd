extends LevelBase

# Level geometry is authored in level-2.tscn's TileMapLayers.
#
# The roommate's path is drawn visually in the editor, not hardcoded here. Open
# level-2.tscn, select the "RoommatePath" (a Path2D) node, and use the editor's
# curve tool to click points along the route. The roommate walks those points in
# order; LevelBase snaps each point to its grid cell (accounting for the node's
# full transform: position, scale, and rotation) and also draws the debug line.
#
# To tweak the route: just drag/add/remove points on RoommatePath in the editor.
# No code changes needed.

func build() -> void:
	# Dream floor: standable cells are painted in the DreamFloorLayer tilemap in
	# the editor. This code only fills a fallback rectangle if that layer is
	# empty, so the roommate always has ground while the level is being blocked.
	var dream_floor_layer := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream_floor_layer == null or dream_floor_layer.get_used_cells().is_empty():
		add_dream_floor(Rect2i(2, 2, 20, 14))

	# Spawn the player.
	add_player(Vector2i(4, 3))

	# Spawn the sleepwalker on the route drawn on the RoommatePath node. Falls
	# back to no roommate if the path is missing/too short (a warning is pushed
	# so it's obvious during development).
	add_roommate_from_path("RoommatePath")
