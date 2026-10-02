class_name Player
extends Node2D

# Free movement, solid against walls and objects (all read from the grid).
# Walking into a Pushable and pressing interact shoves it one cell.
# holdable objects: hold the key. Non-holdable objects: mash the key.

const SIZE := 24.0  # smaller than a cell so you can slip through 1-cell gaps
const SPEED := 96.0  # 3 cells per second, about 2x the roommate
const MASH_GAIN := 0.1  # seconds of progress per key press
const MASH_DECAY := 0.5  # progress lost per second when not pressing
const FALL_SPEED := 480.0  # how fast you drop while falling through a dream gap

var level: LevelBase
var push_target: Pushable
var push_dir := Vector2i.ZERO
var push_timer := 0.0
var locked_to: Pushable  # box just pushed; key must be released before using another

# Dream-gap fall: slide off the bottom, wrap to the top, land on nearest floor.
# This only wastes time for the player (unlike the roommate, who fails).
var falling := false
var land_target := Vector2.ZERO  # where to land once we've wrapped around
var wrapped := false  # have we already looped past the bottom edge?

func _ready() -> void:
	_setup_input()
	if level != null:
		# Leaving the dream mid-fall cancels it (no gaps in the physical world).
		level.realm_changed.connect(_on_realm_changed)

func _on_realm_changed(new_realm: int) -> void:
	if falling and new_realm == LevelBase.Realm.PHYSICAL:
		falling = false
		wrapped = false

func _physics_process(delta: float) -> void:
	if level == null:
		return

	# Falling takes over everything: no walking, no pushing until we land.
	if falling:
		_update_fall(delta)
		queue_redraw()
		return

	# Standing over a dream gap? Start the fall this frame.
	if level.player_over_dream_gap():
		_begin_fall()
		queue_redraw()
		return

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
	queue_redraw()

# ---------- dream-gap fall ----------

func _begin_fall() -> void:
	falling = true
	wrapped = false
	# Lock in where we'll land: the nearest standable dream floor to here.
	land_target = level.closest_dream_floor(position)
	# Clear any push state so we don't resume shoving mid-fall.
	push_target = null
	push_timer = 0.0
	locked_to = null

func _update_fall(delta: float) -> void:
	var field_bottom := Grid.FIELD_ROWS * Grid.CELL
	position.y += FALL_SPEED * delta

	if not wrapped:
		# Keep dropping until fully off the bottom, then reappear above the top.
		if position.y - SIZE / 2.0 > field_bottom:
			wrapped = true
			# Snap X to the landing column and re-enter from above the screen.
			position.x = land_target.x
			position.y = -SIZE / 2.0
	else:
		# Falling back down toward the landing floor.
		if position.y >= land_target.y:
			position = land_target
			falling = false
			wrapped = false

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
	if level.realm == LevelBase.Realm.DREAM:
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
	var body := Color(0.35, 0.8, 1.0)
	if falling:
		body = Color(0.35, 0.8, 1.0, 0.6)  # faded while tumbling through the void
	draw_rect(Rect2(-half, -half, SIZE, SIZE), body)
	if push_target != null and not falling:  # little progress bar while you push
		var t := clampf(push_timer / push_target.hold_time(), 0.0, 1.0)
		draw_rect(Rect2(-half, -half - 8, SIZE * t, 3), Color.WHITE)