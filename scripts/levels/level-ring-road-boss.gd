extends LevelBase


func _ready() -> void:
	level_number = 6
	caption_title = "THE RING ROAD NEVER ENDS"
	caption_hold = 1.3
	super._ready()


func build() -> void:
	# Keep the copied level's authored floor, wall, and background tiles intact.
	# Its dream-floor map already describes where the roommate can walk.
	var dream_floor_layer := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream_floor_layer == null or dream_floor_layer.get_used_cells().is_empty():
		add_dream_floor(Rect2i(2, 2, 20, 14))

	var route := route_from_path2d("RoommatePath")
	if route.size() < 2:
		push_warning("Ring Road needs at least two distinct RoommatePath points.")
		return
	debug_path = route
	add_player(Vector2i.ZERO)
	player.position = Vector2(180, 100)
	add_roommate(route)
