extends LevelBase

# TEMPLATE for level 2 and onward. Copy this into a new level-N.gd and attach it
# to a level-N.tscn.
#
# The roommate's path is NEVER hardcoded here. Instead:
#   1. In the editor, add a Path2D node named "RoommatePath" to the level scene.
#   2. Use the curve tool to click points along the route the roommate walks.
#   3. That's it. The call below reads those points, snaps each to a grid cell
#      (accounting for the node's full transform), and spawns the roommate so he
#      walks the path you drew.
#
# To change the route later, just drag/add/remove points on RoommatePath in the
# editor. No code changes needed. See scripts/core/level_base.gd ->
# add_roommate_from_path() / route_from_path2d() for the plumbing.

func build() -> void:
	# Dream floor: paint standable cells in the DreamFloorLayer tilemap in the
	# editor. This code only fills a fallback rectangle if that layer is empty,
	# so the roommate always has something to walk on while you block the level.
	var dream_floor_layer := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream_floor_layer == null or dream_floor_layer.get_used_cells().is_empty():
		add_dream_floor(Rect2i(2, 2, 20, 14))

	# Place the player wherever the level starts them.
	add_player(Vector2i(4, 3))

	# Spawn the sleepwalker on the editor-drawn RoommatePath. No hardcoded route.
	# If the path is missing or has fewer than 2 points, a warning is pushed and
	# no roommate spawns, which makes the authoring mistake obvious in the editor.
	add_roommate_from_path("RoommatePath")
