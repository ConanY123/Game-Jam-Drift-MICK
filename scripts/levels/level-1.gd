extends LevelBase

# Level 1: REV lobby (grey box). Layout is a rough stand-in for the concept art.
# Chairs are 1x1, the table is 3x3.

func build() -> void:
	# Outer walls
	add_wall(Rect2i(0, 0, 24, 1))
	add_wall(Rect2i(0, 17, 24, 1))
	add_wall(Rect2i(0, 1, 1, 16))
	add_wall(Rect2i(23, 1, 1, 16))

	# Counters and a wall stub that stops you shoving the table left
	add_wall(Rect2i(16, 3, 5, 2))
	add_wall(Rect2i(15, 10, 6, 2))
	add_wall(Rect2i(3, 9, 1, 5))

	# Roommate's route (debug line only, the real Path2D comes in stage 5)
	debug_path = [
		Vector2i(2, 2), Vector2i(12, 2), Vector2i(12, 8),
		Vector2i(6, 8), Vector2i(6, 14), Vector2i(18, 14),
	]

	# Beat 1: a chair on the path, push it aside (holdable)
	# add_pushable(Vector2i(12, 5), Vector2i(1, 1), 1.0, Color(0.85, 0.65, 0.3), LevelBase.Realm.PHYSICAL, true)

	# Beat 2: the big table on the path. Two chairs block its right side,
	# so move them up and down first, then push the table right 3 cells.
	# add_pushable(Vector2i(5, 10), Vector2i(3, 3), 3.0, Color(0.6, 0.4, 0.25), LevelBase.Realm.PHYSICAL, false)
	# add_pushable(Vector2i(8, 10))
	# add_pushable(Vector2i(8, 12))

	# Decoration: off-path chairs you can ignore
	# add_pushable(Vector2i(3, 5))
	# add_pushable(Vector2i(3, 6))

	# Dream floor: lay a platform under the roommate's whole route so every cell
	# he walks is valid, leaving one intentional gap at x = 7, 8 on row 2 that
	# the player must bridge.
	# One connected play area covering the player spawn (4,3), the row-2 corridor
	# the roommate crosses, and the staging space below the gap where the player
	# stands to push the bridges up. The only hole left is the gap at (7,2)/(8,2).
	add_dream_floor(Rect2i(2, 2, 11, 5))   # x = 2..12, y = 2..6 big connected block
	add_dream_floor(Rect2i(12, 2, 1, 7))   # down col 12, y = 2..8
	add_dream_floor(Rect2i(6, 8, 7, 1))    # row 8, x = 6..12
	add_dream_floor(Rect2i(6, 8, 1, 7))    # down col 6, y = 8..14
	add_dream_floor(Rect2i(6, 14, 13, 1))  # row 14, x = 6..18 to the exit

	# Carve the two gap cells back out of the block above - these are the holes
	# the player must bridge, and must NOT be floor until the bridges arrive.
	remove_dream_floor(Vector2i(7, 2))
	remove_dream_floor(Vector2i(8, 2))

	# Bridge pieces: push them up into the row-2 gap to complete the path.
	for x in [7, 8]:
		var bridge := add_pushable(Vector2i(x, 4), Vector2i(1, 1), 1.0, Color(0.4, 0.85, 0.8), LevelBase.Realm.DREAM, true)
		bridge.is_floor = true

	add_player(Vector2i(4, 3))
	# The sleepwalker follows the authored route (same line drawn for debug).
	add_roommate(debug_path)
