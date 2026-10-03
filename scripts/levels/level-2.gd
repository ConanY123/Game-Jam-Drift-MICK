extends LevelBase

# Level geometry is authored in level-2.tscn's TileMapLayers (paint them in the
# editor). The roommate's route is drawn visually: select the "RoommatePath"
# Path2D node in the scene and click points along the path. LevelBase snaps each
# point to its grid cell and also draws the debug line.

func build() -> void:
	# Dream floor: standable cells come from the DreamFloorLayer tilemap painted
	# in the editor. This fallback only fills a rectangle if that layer is empty,
	# so the roommate always has ground while the level is being blocked out.
	var dream_floor_layer := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream_floor_layer == null or dream_floor_layer.get_used_cells().is_empty():
		add_dream_floor(Rect2i(2, 2, 20, 14))

	# Where the player starts. Move this cell as the layout takes shape.
	add_player(Vector2i(4, 3))

	# Spawn the sleepwalker on the route drawn on the RoommatePath node. If the
	# path is missing or too short, no roommate spawns (a warning is pushed so
	# it's obvious during development).
	add_roommate_from_path("RoommatePath")
