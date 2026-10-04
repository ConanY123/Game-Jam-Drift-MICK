extends LevelBase

func _ready() -> void:
	level_number = 8
	super._ready()


func build() -> void:
	# Reuse the level's painted route so the roommate sprite walks the authored path.
	add_player(Vector2i(2, 14))
	add_roommate_from_path("RoommatePath")
