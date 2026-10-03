class_name Arrow
extends Node2D

# A projectile fired by the player's bow. Travels in a straight line until it
# hits a monster (banishes it), hits a wall, or leaves the field - then frees.
#
# Movement and hit tests are in pixel space (like the player/monster). Monster
# hits are duck-typed via has_method("kill"), so there's no compile-time
# dependency on the Monster class.

const SPEED := 320.0  # fast - clearly faster than anything it chases
const LENGTH := 16.0  # drawn shaft length
const HIT_RADIUS := 13.0  # how close to a monster counts as a hit

var level: LevelBase
var dir := Vector2.RIGHT  # unit vector; set on spawn

func setup(p_level: LevelBase, p_dir: Vector2) -> void:
	level = p_level
	if p_dir.length() > 0.0:
		dir = p_dir.normalized()
	rotation = dir.angle()

func _physics_process(delta: float) -> void:
	if level == null:
		queue_free()
		return
	position += dir * SPEED * delta

	# Off the field? Give it one cell of slack, then despawn.
	var cell := Grid.pos_to_cell(position)
	if not Grid.in_bounds(cell):
		queue_free()
		return

	# Hit a wall in the physical realm (walls are solid in both; the level
	# itself is the blocker). Walls stop the arrow.
	var b := level.blocker_at(cell, LevelBase.Realm.PHYSICAL)
	if b == level:
		queue_free()
		return

	# Hit a monster? Banish it and despawn. Scan the level's children for any
	# node close enough that can be killed.
	for child in level.get_children():
		if child == self:
			continue
		if not child.has_method("kill"):
			continue
		if child.get("dying"):  # already being banished
			continue
		if child is CanvasItem and not child.visible:
			continue  # hidden (e.g. a dream monster while in the physical realm)
		if position.distance_to(child.position) <= HIT_RADIUS:
			child.call("kill")
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	# Drawn along local +X (rotation points it in the travel direction).
	var tip := Vector2(LENGTH * 0.5, 0)
	var tail := Vector2(-LENGTH * 0.5, 0)
	draw_line(tail, tip, Color(0.95, 0.9, 0.6), 2.0)
	# arrowhead
	draw_line(tip, tip + Vector2(-4, -3), Color(0.95, 0.9, 0.6), 2.0)
	draw_line(tip, tip + Vector2(-4, 3), Color(0.95, 0.9, 0.6), 2.0)
