class_name Pushable
extends Node2D

# Grid-snapped object. Chair = size (1, 1), table = size (3, 3).

@export var size := Vector2i(1, 1)
@export var weight := 1.0  # scales hold time (and stamina cost later)
@export var color := Color(0.85, 0.65, 0.3)
@export var holdable := true  # if true, player can hold instead of spamming
@export var is_floor := false  # a dream piece that counts as ground for the roommate
@export_enum("Physical", "Dream") var realm := 0

var cell := Vector2i.ZERO  # top-left cell
var level: LevelBase
var moving := false

func setup(p_level: LevelBase, p_cell: Vector2i) -> void:
	level = p_level
	cell = p_cell
	# Floor objects sit below the roommate route overlay. Other pushables keep
	# the normal layer so they can obscure the route when they overlap it.
	z_index = -2 if is_floor else 0
	position = Grid.cell_to_pos(cell)
	level.register(self, get_cells(cell), realm)
	level.realm_changed.connect(func(_r): _refresh())
	_refresh()

func _ready() -> void:
	if level != null:
		return
	var node := get_parent()
	while node != null and not node is LevelBase:
		node = node.get_parent()
	if node != null:
		setup(node, Grid.pos_to_cell(node.to_local(global_position)))

# Sprite follows the same realm rules as the drawn rectangle
func _refresh() -> void:
	var sprite := _get_sprite_visual()
	if sprite != null:
		if level.realm == realm:
			sprite.visible = true
			sprite.modulate.a = 1.0
		elif realm == LevelBase.Realm.PHYSICAL:
			sprite.visible = true
			sprite.modulate.a = 0.35  # physical object seen from the dream
		else:
			sprite.visible = false  # dream object seen from the physical realm
	queue_redraw()

func _get_sprite_visual() -> CanvasItem:
	var sprite := get_node_or_null("Sprite2D") as CanvasItem
	if sprite == null:
		sprite = get_node_or_null("AnimatedSprite2D") as CanvasItem
	return sprite

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

func is_supported_by_dream_floor() -> bool:
	if realm != LevelBase.Realm.DREAM:
		return true
	if level == null:
		return false
	for c in get_cells(cell):
		if level.dream_floor.has(c):
			return true
	return false

func can_push(dir: Vector2i) -> bool:
	if moving or dir == Vector2i.ZERO or level == null or not is_supported_by_dream_floor():
		return false
	for c in get_cells(cell + dir):
		if not level.is_free(c, self, realm) or level.in_push_ban(c):
			return false
	return true

func can_interact(dir: Vector2i) -> bool:
	return can_push(dir)

func try_push(dir: Vector2i) -> bool:
	if not can_push(dir):
		return false
	var push_sfx := get_node_or_null("PushSfx") as AudioStreamPlayer2D
	if push_sfx != null:
		push_sfx.play()
	var target := cell + dir
	var new_cells := get_cells(target)
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
	var has_sprite := _get_sprite_visual() != null
	if level.realm == realm:
		if not has_sprite: 
			draw_rect(rect, color)
	elif realm == LevelBase.Realm.PHYSICAL:
		# Physical object seen from the dream: faint, still solid, but not touchable.
		draw_rect(rect, Color(color, 0.35))
