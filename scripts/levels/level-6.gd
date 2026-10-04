extends LevelBase

# Level 6 - "Dana Porter"
#
# "Book = intelligent puzzle of intelligence." A serpentine walk through the
# library stacks. Geometry is painted in level-6.tscn's TileMapLayers (walls,
# dream floor, cliff faces, border frame); objects and the roommate's route are
# placed in the scene too. The route is drawn on the "RoommatePath" Path2D.
#
# The sleepwalker takes about 90 seconds to cross three corridors. Every
# computer is a real obstacle: either armed from the start, or a trap that a
# lever you had to flip for an earlier computer arms. Wiring, in walking order:
#
#   READING ROOM (bottom, leftwards)
#     Chairs and book carts sit on his route; each push costs stamina (the carts
#     are heavy), so the chores leave you nearly empty. K0 is an unwired,
#     permanently armed computer: the only way to defuse it is to push it away.
#
#   THE CHASMS (middle, rightwards)
#     Two gaps in the dream floor. Each needs a shelf block pushed in from both
#     sides. Dream pushes refill stamina, which you need before you can leave the
#     dream again.
#     LeverL1 (physical):  D3 is safe only while L1 is ON, D2 only while it is OFF.
#
#   THE STACKS (top, leftwards)
#     LeverL3 (physical):  T5 safe only while ON, T4 only while OFF, T3 only ON.
#     LeverL2 (dream):     T1 safe only while ON, T2 only while OFF.
#
# Each lever has to be flipped two or three times, in order, and the two top
# levers live in different realms, so you also have to plan the realm switches
# (each one takes a second, and leaving the dream needs 35% stamina).

func build() -> void:
	# Dream floor comes from the painted DreamFloorLayer. The fallback only
	# fills a rectangle if that layer is empty, so the roommate always has
	# ground while the level is being blocked out.
	var dream_floor_layer := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream_floor_layer == null or dream_floor_layer.get_used_cells().is_empty():
		add_dream_floor(Rect2i(2, 2, 20, 14))

	# Where the player starts: bottom right, next to where the roommate enters.
	add_player(Vector2i(18, 15))

	# Spawn the sleepwalker on the route drawn on the RoommatePath node.
	add_roommate_from_path("RoommatePath")
