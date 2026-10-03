extends LevelBase

# Level geometry is authored in level-2.tscn's TileMapLayers.
#
# NEW IN LEVEL 2: the roommate's path is drawn visually in the editor instead
# of being hardcoded here. Open level-2.tscn, select the "RoommatePath" (a
# Path2D) node, and use the editor's curve tool to click points along the
# route. The roommate walks those points in order; LevelBase snaps each point
# to its grid cell and also draws the debug line from them.
#
# To tweak the route: just drag/add/remove points on RoommatePath in the editor.
# No code changes needed.

func build() -> void:
	# Dream floor: lay a platform under the roommate's whole route so every cell
	# he walks is valid. (Painted in DreamFloorLayer in the editor; this code
	# only fills in a fallback if that layer is empty.)
	var dream_floor_layer := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream_floor_layer == null or dream_floor_layer.get_used_cells().is_empty():
		add_dream_floor(Rect2i(2, 2, 20, 14))

	add_player(Vector2i(4, 3))

	# The sleepwalker follows the route drawn on the RoommatePath node in the
	# editor. Falls back to no roommate if the path is missing/too short (a
	# warning is pushed so it's obvious during development).
	add_roommate_from_path("RoommatePath")
