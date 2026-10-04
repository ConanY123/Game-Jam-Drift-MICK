class_name Door
extends Pushable

# A door uses the player's push interaction once to swing open. It becomes
# inactive and non-blocking when the swing finishes.
#
# Default realm is Physical (the interact verb: close a door, pull a lever).
# Self-contained: this adds no requirements to player.gd / level_base.gd.

@export var open := false  # the first interaction opens and deactivates it
@export_range(0.0, 270.0, 90.0) var start_angle_degrees := 0.0
@export_enum("Clockwise", "Counter-clockwise") var swing_direction := 0

const LEAF_LENGTH := float(Grid.CELL - 2)
const LEAF_THICKNESS := float(Grid.CELL) * 0.3
const LEAF_COLLISION_THICKNESS := 2.0
const SWING_ANGLE_DEGREES := 90.0
const SWING_DURATION := 0.25

var _leaf_angle := start_angle_degrees
var _swing_tween: Tween
var inactive := false

func _ready() -> void:
	super._ready()  # keep Pushable's self-registration with the parent level
	_leaf_angle = start_angle_degrees
	if open:
		_leaf_angle = _open_angle()
	if level != null:
		level.unregister(self, realm)
		if not open:
			level.register(self, _collision_cells(_leaf_angle), realm)
		else:
			inactive = true
	_refresh()

func can_interact(_dir: Vector2i) -> bool:
	if moving or inactive or open or level == null:
		return false
	for c in _collision_cells(_open_angle()):
		if level.in_push_ban(c):
			return false
		if not level.is_free(c, self, realm):
			return false
	return true

# The player calls this when the interact timer completes against us. Return
# true so the player's key-lock triggers (one press = one interaction).
func try_push(dir: Vector2i) -> bool:
	if not can_interact(dir):
		return false
	open = true
	_refresh()
	level.unregister(self, realm)
	_animate_swing(_open_angle())
	return true

func _open_angle() -> float:
	var direction := -1.0 if swing_direction == 0 else 1.0
	return start_angle_degrees + SWING_ANGLE_DEGREES * direction

func _collision_cells(angle_degrees: float) -> Array[Vector2i]:
	var angle := deg_to_rad(-angle_degrees)
	var corners := [
		Vector2.ZERO,
		Vector2(LEAF_LENGTH, 0.0),
		Vector2(0.0, LEAF_COLLISION_THICKNESS),
		Vector2(LEAF_LENGTH, LEAF_COLLISION_THICKNESS),
	]
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for corner in corners:
		var rotated: Vector2 = corner.rotated(angle)
		min_point = min_point.min(rotated)
		max_point = max_point.max(rotated)

	var min_cell := Grid.pos_to_cell(min_point + Vector2(0.01, 0.01))
	var max_cell := Grid.pos_to_cell(max_point - Vector2(0.01, 0.01))
	var cells: Array[Vector2i] = []
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			cells.append(cell + Vector2i(x, y))
	return cells

func overlaps_player_hitbox(player_center: Vector2, hitbox_size: Vector2) -> bool:
	if moving:
		return false
	return _overlaps_player_hitbox_at(player_center, hitbox_size, _leaf_angle)

func _overlaps_player_hitbox_at(
	player_center: Vector2,
	hitbox_size: Vector2,
	angle_degrees: float
) -> bool:
	var angle := deg_to_rad(-angle_degrees)
	var forward := Vector2.RIGHT.rotated(angle)
	var side := Vector2.DOWN.rotated(angle)
	var leaf_center := Vector2(
		LEAF_LENGTH * 0.5,
		LEAF_COLLISION_THICKNESS * 0.5
	).rotated(angle)
	var local_player_center := to_local(level.to_global(player_center))
	var separation := local_player_center - leaf_center
	var player_half := hitbox_size * 0.5
	var leaf_half := Vector2(LEAF_LENGTH, LEAF_COLLISION_THICKNESS) * 0.5

	for axis in [Vector2.RIGHT, Vector2.DOWN, forward, side]:
		var player_radius := (
			player_half.x * absf(axis.x)
			+ player_half.y * absf(axis.y)
		)
		var leaf_radius := (
			leaf_half.x * absf(axis.dot(forward))
			+ leaf_half.y * absf(axis.dot(side))
		)
		if absf(separation.dot(axis)) >= player_radius + leaf_radius:
			return false
	return true

func _animate_swing(target_angle: float) -> void:
	if _swing_tween != null and _swing_tween.is_running():
		_swing_tween.kill()
	moving = true
	_swing_tween = create_tween()
	_swing_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_swing_tween.tween_method(
		_set_leaf_angle,
		_leaf_angle,
		target_angle,
		SWING_DURATION
	)
	_swing_tween.tween_callback(_finish_swing.bind(target_angle))

func _finish_swing(target_angle: float) -> void:
	var target_cells := _collision_cells(target_angle)
	if open:
		for c in target_cells:
			if not level.is_free(c, self, realm):
				open = false
				_refresh()
				level.register(self, _collision_cells(start_angle_degrees), realm)
				_animate_swing(start_angle_degrees)
				return
		inactive = true
		level.unregister(self, realm)
	else:
		level.register(self, target_cells, realm)
	moving = false

func _set_leaf_angle(angle: float) -> void:
	_leaf_angle = angle
	queue_redraw()

func _draw() -> void:
	if level == null:
		return
	var leaf_color := color
	if inactive:
		leaf_color = leaf_color.darkened(0.3)
	if level.realm == realm:
		leaf_color.a = 0.75 if open else 1.0
	elif realm == LevelBase.Realm.PHYSICAL:
		if open:
			return
		leaf_color.a = 0.35
	else:
		return

	var hinge := Vector2.ZERO
	draw_set_transform(hinge, deg_to_rad(-_leaf_angle), Vector2.ONE)
	var leaf := Rect2(0.0, 0.0, LEAF_LENGTH, LEAF_THICKNESS)
	draw_rect(leaf, leaf_color)
	draw_rect(leaf, Color("#1d60ad", leaf_color.a), false, 1.0)
	draw_circle(Vector2.ZERO, LEAF_THICKNESS * 0.3, Color("#1d60ad", leaf_color.a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _refresh() -> void:
	queue_redraw()
