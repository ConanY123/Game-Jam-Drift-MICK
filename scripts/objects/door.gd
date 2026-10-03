class_name Door
extends Node2D

# A grid door. Closed = registered as solid (blocks player + roommate); open =
# unregistered so everyone passes through. Toggled by the player walking up and
# pressing interact. Public open()/close()/toggle() so a button or lever can
# drive it later. Belongs to a realm like Pushable.

@export var size := Vector2i(1, 1)
@export var color := Color(0.55, 0.4, 0.3)
@export var start_open := false
@export_enum("Physical", "Dream") var realm := 0

var cell := Vector2i.ZERO  # top-left cell
var level: LevelBase
var is_open := false

@onready var _body: Node2D = get_node_or_null("BodyVisual")

func setup(p_level: LevelBase, p_cell: Vector2i, p_start_open := false) -> void:
	level = p_level
	cell = p_cell
	start_open = p_start_open
	position = Grid.cell_to_pos(cell)
	is_open = start_open
	if not is_open:
		level.register(self, get_cells(), realm)
	level.realm_changed.connect(func(_r): queue_redraw())
	queue_redraw()

func get_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			cells.append(cell + Vector2i(x, y))
	return cells

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

func open() -> void:
	if is_open:
		return
	is_open = true
	level.unregister(self, realm)
	queue_redraw()

func close() -> void:
	if not is_open:
		return
	# Don't slam shut on top of something already standing in the doorway.
	for c in get_cells():
		if not level.is_free(c, self, realm):
			return
	is_open = false
	level.register(self, get_cells(), realm)
	queue_redraw()

func _draw() -> void:
	if _body != null or level == null:
		return
	var full := Rect2(Vector2(1, 1), Vector2(size * Grid.CELL) - Vector2(2, 2))
	if level.realm == realm:
		if is_open:
			# Open: just the frame so you can see the doorway.
			draw_rect(full, Color(color, 0.9), false, 3.0)
		else:
			draw_rect(full, color)
	elif realm == LevelBase.Realm.PHYSICAL:
		# Physical door seen from the dream: faint, like other physical objects.
		if not is_open:
			draw_rect(full, Color(color, 0.15))
			draw_rect(full, Color(color, 0.8), false, 2.0)
