class_name Player
extends Node2D

# Free movement, solid against walls and objects (all read from the grid).
# Walking into a Pushable and pressing interact shoves it one cell.
# holdable objects: hold the key. Non-holdable objects: mash the key.

const SIZE := 24.0  # smaller than a cell so you can slip through 1-cell gaps
const SPEED := 96.0  # 3 cells per second, about 2x the roommate
const MASH_GAIN := 0.1  # seconds of progress per key press
const MASH_DECAY := 0.5  # progress lost per second when not pressing

var level: LevelBase
var push_target: Pushable
var push_dir := Vector2i.ZERO
var push_timer := 0.0
var locked_to: Pushable  # box just pushed; key must be released before using another

func _ready() -> void:
	_setup_input()

func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var step := input * SPEED * delta

	# Axes move separately so you slide along walls.
	var hit_x := _move_axis(Vector2(step.x, 0))
	var hit_y := _move_axis(Vector2(0, step.y))

	var target: Pushable = null
	var dir := Vector2i.ZERO
	if hit_x is Pushable:
		target = hit_x
		dir = Vector2i(int(sign(step.x)), 0)
	if hit_y is Pushable:
		target = hit_y
		dir = Vector2i(0, int(sign(step.y)))
	_update_push(target, dir, delta)
	if level != null:
		level.ensure_player_is_on_safe_dream_floor()
	queue_redraw()

# Moves if free. Returns null on success, or whatever blocked us.
func _move_axis(offset: Vector2) -> Node:
	if offset == Vector2.ZERO:
		return null
	var blocker := _blocker_at(position + offset)
	if blocker == null:
		position += offset
	return blocker

func _blocker_at(center: Vector2) -> Node:
	# Current realm's objects first, then physical ones (they stay solid in the dream)
	var b: Node = _blocker_in(center, level.realm)
	if b == null and level.realm == LevelBase.Realm.DREAM:
		b = _blocker_in(center, LevelBase.Realm.PHYSICAL)
	return b

func _blocker_in(center: Vector2, in_realm: int) -> Node:
	var half := Vector2(SIZE, SIZE) / 2.0
	var min_cell := Grid.pos_to_cell(center - half)
	var max_cell := Grid.pos_to_cell(center + half - Vector2(0.01, 0.01))
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var b := level.blocker_at(Vector2i(x, y), in_realm)
			if b != null:
				return b
	return null

# True if the player would be standing inside something solid in that realm.
func is_overlapping(in_realm: int) -> bool:
	return _blocker_in(position, in_realm) != null

func _update_push(target: Pushable, dir: Vector2i, delta: float) -> void:
	# Physical objects stay solid in the dream but can't be touched there
	# You can only push objects that belong to the realm you are in
	if target != null and target.realm != level.realm:
		target = null
	# Releasing the key clears the lock.
	if not Input.is_action_pressed("interact"):
		locked_to = null
	# Key is still held from the last push, so other boxes are ignored.
	if target != null and locked_to != null and target != locked_to:
		target = null

	if target == null:
		push_target = null
		push_timer = 0.0
		return
	if target != push_target or dir != push_dir:
		push_target = target
		push_dir = dir
		push_timer = 0.0

	if target.holdable:
		if not Input.is_action_pressed("interact"):
			push_timer = 0.0
			return
		push_timer += delta
	else:
		if Input.is_action_just_pressed("interact"):
			push_timer += MASH_GAIN
		else:
			var proportinal = (push_timer / target.hold_time())
			push_timer = maxf(push_timer - delta * MASH_DECAY * proportinal, 0.0)

	if push_timer >= target.hold_time():
		push_timer = 0.0
		if target.try_push(dir):
			locked_to = target

func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"interact": [KEY_Z, KEY_SPACE],
		"switch_realm": [KEY_C],
	}
	for action in map:
		if InputMap.has_action(action):
			continue  # already added (scene reload)
		InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)

func _draw() -> void:
	var half := SIZE / 2.0
	draw_rect(Rect2(-half, -half, SIZE, SIZE), Color(0.35, 0.8, 1.0))
	if push_target != null:  # little progress bar while you push
		var t := clampf(push_timer / push_target.hold_time(), 0.0, 1.0)
		draw_rect(Rect2(-half, -half - 8, SIZE * t, 3), Color.WHITE)
