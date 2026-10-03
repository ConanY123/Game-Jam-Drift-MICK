extends LevelBase

# Level geometry is authored in level-1.tscn's TileMapLayers.

func build() -> void:
	# The roommate follows this route through the authored level.
	debug_path = [
		Vector2i(2, 2), Vector2i(12, 2), Vector2i(12, 8),
		Vector2i(6, 8), Vector2i(6, 14), Vector2i(18, 14),
	]

	# Dream floor: lay a platform under the roommate's whole route so every cell
	# he walks is valid, leaving one intentional gap at x = 7, 8 on row 2 that
	# the player must bridge.
	# TODO: move dream-floor layout into DreamFloorLayer once it is painted in
	# the editor. Keep this metadata until then; the tileset alone doesn't mark
	# which cells are standable.
	var dream_floor_layer := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream_floor_layer == null or dream_floor_layer.get_used_cells().is_empty():
		add_dream_floor(Rect2i(2, 2, 11, 5))
		add_dream_floor(Rect2i(12, 2, 1, 7))
		add_dream_floor(Rect2i(6, 8, 7, 1))
		add_dream_floor(Rect2i(6, 8, 1, 7))
		add_dream_floor(Rect2i(6, 14, 13, 1))
		remove_dream_floor(Vector2i(7, 2))
		remove_dream_floor(Vector2i(8, 2))

	# Interactive bridge pieces remain scene objects; tilemap tiles aren't pushable.
	for x in [7, 8]:
		var bridge := add_pushable(Vector2i(x, 4), Vector2i(1, 1), 1.0, Color(0.4, 0.85, 0.8), LevelBase.Realm.DREAM, true)
		bridge.is_floor = true

	add_player(Vector2i(4, 3))
	# The sleepwalker follows the authored route (same line drawn for debug).
	add_roommate(debug_path)
