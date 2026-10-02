class_name Pushable
extends Node2D

# Grid-snapped object. Chair = size (1, 1), table = size (3, 3).

@export var size := Vector2i(1, 1)
@export var weight := 1.0  # scales hold time (and stamina cost later)
@export var color := Color(0.85, 0.65, 0.3)
@export var holdable := true  # if true, player can hold instead of spamming
@export_enum("Physical", "Dream") var realm := 0

var cell := Vector2i.ZERO  # top-left cell
var level: LevelBase
var moving := false

func setup(p_level: LevelBase, p_cell: Vector2i) -> void:
	level = p_level
	cell = p_cell
	position = Grid.cell_to_pos(cell)
	level.register(self, get_cells(cell), realm)
	level.realm_changed.connect(func(_r): queue_redraw())

# Swap this for a footprint array later if you want L-shaped desks.
func get_cells(origin: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			cells.append(origin + Vector2i(x, y))
	return cells

# Seconds the player must hold against it per cell pushed.
func hold_time() -> float:
	return 0.25 * weight

func try_push(dir: Vector2i) -> bool:
	if moving:
		return false
	var target := cell + dir
	var new_cells := get_cells(target)
	for c in new_cells:
		if not level.is_free(c, self, realm) or level.in_push_ban(c):
			return false
	# Claim the new cells right away; the tween is only visual.
	level.unregister(self, realm)
	cell = target
	level.register(self, new_cells, realm)
	moving = true
	var tween := create_tween()
	tween.tween_property(self, "position", Grid.cell_to_pos(cell), 0.12)
	tween.tween_callback(func(): moving = false)
	return true

func _draw() -> void:
	if level == null:
		return
	var rect := Rect2(Vector2(1, 1), Vector2(size * Grid.CELL) - Vector2(2, 2))
	if level.realm == realm:
		draw_rect(rect, color)
	elif realm == LevelBase.Realm.PHYSICAL:
		# Physical object seen from the dream: still solid, but not touchable
		draw_rect(rect, Color(color, 0.15))
		draw_rect(rect, Color(color, 0.8), false, 2.0)
	# Dream objects draw nothing while you are in the physical realm