class_name BowPickup
extends Node2D

# A bow lying on the ground. Walk the player over it to pick it up: the player
# gains has_bow (unlocking aim+shoot) and this pickup frees itself.
#
# Non-blocking - it never registers in the occupancy map, you just walk onto it.
# Self-contained: it only reads/sets fields on the player.

const PICKUP_RADIUS := 18.0

var level: LevelBase

func setup(p_level: LevelBase) -> void:
	level = p_level

func _ready() -> void:
	if level == null and get_parent() is LevelBase:
		level = get_parent()
	# Snap to the center of whatever cell we were dropped on in the editor.
	position = Grid.cell_to_center(Grid.pos_to_cell(position))
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if level == null or level.player == null:
		return
	var p := level.player
	if position.distance_to(p.position) <= PICKUP_RADIUS:
		p.set("has_bow", true)
		queue_free()

func _draw() -> void:
	# Simple bow glyph: an arc plus a string, so it reads without art.
	var wood := Color(0.6, 0.4, 0.2)
	var string := Color(0.9, 0.9, 0.85)
	draw_arc(Vector2.ZERO, 10.0, -PI / 2.2, PI / 2.2, 16, wood, 2.0)
	draw_line(Vector2(0, -9), Vector2(0, 9), string, 1.0)
