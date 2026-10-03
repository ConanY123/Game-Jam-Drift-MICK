class_name Slidable
extends Pushable

# A Pushable that, once shoved, keeps sliding in the pushed direction one cell
# at a time until something blocks it (a wall, another object, or the edge of
# the field). Think shopping carts: give them a nudge and they roll.
#
# It extends Pushable so every `is Pushable` check in the player, roommate and
# level code treats it exactly like a normal box - the only difference is how
# far a single push travels. Apply this script to a Node2D the same way you'd
# apply pushable.gd (place it under a level, optionally with a Sprite2D child).

@export var slide_speed := 10.0  # cells per second while rolling (visual tween)
@export var max_slide_cells := 64  # safety cap so a bad level can't loop forever

# True if the whole footprint would be free when the object sits at `origin`.
func _footprint_free(origin: Vector2i) -> bool:
	for c in get_cells(origin):
		if not level.is_free(c, self, realm) or level.in_push_ban(c):
			return false
	return true

# Override: instead of moving a single cell, roll until blocked.
func try_push(dir: Vector2i) -> bool:
	if moving:
		return false
	# Walk forward one cell at a time to find how far we can slide before being
	# blocked. We stop at the last free cell (just short of the obstacle).
	var target := cell
	var steps := 0
	while steps < max_slide_cells:
		var next := target + dir
		if not _footprint_free(next):
			break
		target = next
		steps += 1

	if steps == 0:
		return false  # couldn't move even one cell: wall right in front

	# Claim the destination cells right away; the tween is only visual.
	level.unregister(self, realm)
	cell = target
	level.register(self, get_cells(cell), realm)
	moving = true

	# Tween across the whole slide at a constant speed, so a long roll takes
	# longer than a short one.
	var dest := Grid.cell_to_pos(cell)
	var duration := maxf(float(steps) / slide_speed, 0.05)
	var tween := create_tween()
	tween.tween_property(self, "position", dest, duration)
	tween.tween_callback(func(): moving = false)
	return true
