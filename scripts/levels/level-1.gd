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

	# Beat 1: a chair on the path, push it aside
	add_pushable(Vector2i(12, 5))

	# Beat 2: the big table on the path. Two chairs block its right side,
	# so move them up and down first, then push the table right 3 cells.
	add_pushable(Vector2i(5, 10), Vector2i(3, 3), 3.0, Color(0.6, 0.4, 0.25), false)
	add_pushable(Vector2i(8, 10))
	add_pushable(Vector2i(8, 12))

	# Decoration: off-path chairs you can ignore
	add_pushable(Vector2i(3, 5))
	add_pushable(Vector2i(3, 6))

	add_player(Vector2i(4, 3))

	#test dream realm
	add_pushable(Vector2i(12, 5), Vector2i(1, 1), 1.0, Color(0.6, 0.3, 0.9), true, LevelBase.Realm.DREAM)
