class_name Door
extends Pushable

# A door is a Pushable that opens (and can close) instead of sliding a cell.
# It reuses the player's existing push pipeline: walking into it and holding /
# mashing "interact" fills the same timer, and when that timer completes the
# player calls try_push(dir) - which we override to toggle open/closed instead
# of moving.
#
# Closed: solid in its realm (registered in the occupancy map), so it blocks the
#   player and kills the roommate if he reaches it.
# Open:   unregistered from the occupancy map, so the player and the roommate
#   pass straight through. It stays in place, just drawn faded.
#
# Default realm is Physical (the interact verb: close a door, pull a lever).
# Self-contained: this adds no requirements to player.gd / level_base.gd.

@export var open := false  # start closed by default; the puzzle is to open it

func _ready() -> void:
	super._ready()  # keep Pushable's self-registration with the parent level
	# If authored as already-open in the editor, free its cells immediately.
	if open and level != null:
		level.unregister(self, realm)
	_refresh()

# The player calls this when the interact timer completes against us. Rather
# than move a cell, flip the door state. Return true so the player's key-lock
# triggers (one press = one toggle, no repeat until the key is released).
func try_push(dir: Vector2i) -> bool:
	# Honour the same no-interact-near-the-roommate rule push uses.
	for c in get_cells(cell):
		if level.in_push_ban(c):
			return false
	open = not open
	if open:
		level.unregister(self, realm)
	else:
		# Only re-close if every cell is clear (nobody standing in the doorway).
		for c in get_cells(cell):
			if not level.is_free(c, self, realm):
				open = true  # stayed open; closing was blocked
				return false
		level.register(self, get_cells(cell), realm)
	_refresh()
	queue_redraw()
	return true

func _draw() -> void:
	if level == null:
		return
	var rect := Rect2(Vector2(1, 1), Vector2(size * Grid.CELL) - Vector2(2, 2))
	var has_sprite := get_node_or_null("Sprite2D") != null

	# Only draw a fallback when there's no sprite and the door is in-realm.
	if level.realm == realm:
		if not has_sprite:
			if open:
				# Open: just an outline so you can see where it was.
				draw_rect(rect, Color(color, 0.9), false, 2.0)
			else:
				draw_rect(rect, color)
	elif realm == LevelBase.Realm.PHYSICAL:
		# Seen from the dream: faint, like other physical objects.
		if not open:
			draw_rect(rect, Color(color, 0.15))
			draw_rect(rect, Color(color, 0.8), false, 2.0)

# Keep the sprite (if any) in sync with open/closed as well as realm.
func _refresh() -> void:
	super._refresh()
	var sprite := get_node_or_null("Sprite2D")
	if sprite != null and level != null and level.realm == realm:
		# Fade the sprite when open so it reads as "passable".
		sprite.modulate.a = 0.35 if open else 1.0
