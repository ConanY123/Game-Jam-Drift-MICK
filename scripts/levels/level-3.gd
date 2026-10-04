extends LevelBase

func build() -> void:
	var dream_floor_layer := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream_floor_layer == null or dream_floor_layer.get_used_cells().is_empty():
		add_dream_floor(Rect2i(0, 0, 20, 18))

	# Spawn the player at the requested point in world space.
	add_player(Vector2i.ZERO)
	player.position = Vector2(180, 100)

	# The roommate follows the editor-authored route on the RoommatePath node.
	add_roommate_from_path("RoommatePath")
