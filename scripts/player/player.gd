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
const FALL_DROP_CELLS := 2.0  # how far (in cells) the little drop-out travels
const FALL_OUT_TIME := 0.35  # seconds for the spin-shrink-fade-out
const FALL_IN_TIME := 0.45  # seconds for the drop back in from the top
const FALL_SPIN := TAU * 2.0  # total rotation across each phase (2 turns)

enum FallPhase { NONE, OUT, IN }

var level: LevelBase
var push_target: Pushable
var push_dir := Vector2i.ZERO
var push_timer := 0.0
var locked_to: Pushable  # box just pushed; key must be released before using another

# Dream-gap fall: drop a little while spinning + fading out, then fall back in
# from the top spinning + fading in, landing on the nearest floor.
# This only wastes time for the player (unlike the roommate, who fails).
var facing := Vector2i(0, 1)  # last movement direction, for door interaction
var falling := false
var fall_phase := FallPhase.NONE
var fall_t := 0.0  # 0..1 progress within the current phase
var fall_from := Vector2.ZERO  # phase start position
var land_target := Vector2.ZERO  # where to land once we've wrapped around
# Visual-only transform applied in _draw while falling.
var draw_spin := 0.0
var draw_scale := 1.0
var draw_alpha := 1.0

func _ready() -> void:
	_setup_input()
	if level != null:
		# Leaving the dream mid-fall cancels it (no gaps in the physical world).
		level.realm_changed.connect(_on_realm_changed)

func _on_realm_changed(new_realm: int) -> void:
	if falling and new_realm == LevelBase.Realm.PHYSICAL:
		_end_fall()

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

	# Remember facing so we know which door to use when standing still.
	if input != Vector2.ZERO:
		facing = Vector2i(roundi(input.x), roundi(input.y))

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

	# Door toggle takes priority over pushing when you tap interact next to one,
	# so bumping a closed door opens it instead of trying to "push" it.
	if Input.is_action_just_pressed("interact") and _try_toggle_door(hit_x, hit_y):
		push_target = null
		push_timer = 0.0
		queue_redraw()
		return

	_update_push(target, dir, delta)
	queue_redraw()

# Toggle a door we're bumping into, or the one in the cell we're facing.
# Returns true if a door was toggled.
func _try_toggle_door(hit_x: Node, hit_y: Node) -> bool:
	# A closed door we just walked into shows up as a blocker.
	var bumped: Door = null
	if hit_x is Door:
		bumped = hit_x
	elif hit_y is Door:
		bumped = hit_y
	if bumped != null and bumped.realm == level.realm:
		bumped.toggle()
		return true

	# Otherwise look at the cell we're facing (needed to close an open door,
	# which isn't solid and so never blocks us).
	var here := Grid.pos_to_cell(position)
	for probe in [here + facing, here]:
		var d := level.blocker_at(probe, level.realm)
		if d is Door:
			d.toggle()
			return true
		# Open doors aren't in the solids map, so scan children for one here.
		var open_door := _open_door_at(probe)
		if open_door != null:
			open_door.toggle()
			return true
	return false

func _open_door_at(cell: Vector2i) -> Door:
	for child in level.get_children():
		if child is Door and child.is_open and child.realm == level.realm:
			if child.get_cells().has(cell):
				return child
	return null

# ---------- dream-gap fall ----------

func _begin_fall() -> void:
	falling = true
	fall_phase = FallPhase.OUT
	fall_t = 0.0
	fall_from = position
	# Lock in where we'll land: the nearest standable dream floor to here.
	land_target = level.closest_dream_floor(position)
	draw_spin = 0.0
	draw_scale = 1.0
	draw_alpha = 1.0
	# Clear any push state so we don't resume shoving mid-fall.
	push_target = null
	push_timer = 0.0
	locked_to = null

func _end_fall() -> void:
	falling = false
	fall_phase = FallPhase.NONE
	draw_spin = 0.0
	draw_scale = 1.0
	draw_alpha = 1.0

func _update_fall(delta: float) -> void:
	match fall_phase:
		FallPhase.OUT:
			fall_t += delta / FALL_OUT_TIME
			var t := clampf(fall_t, 0.0, 1.0)
			# Drop a few cells while spinning, shrinking and fading to nothing.
			position.y = fall_from.y + FALL_DROP_CELLS * Grid.CELL * t
			draw_spin = FALL_SPIN * t
			draw_scale = 1.0 - t
			draw_alpha = 1.0 - t
			if t >= 1.0:
				# Switch to re-entry: start above the top over the landing column.
				fall_phase = FallPhase.IN
				fall_t = 0.0
				fall_from = Vector2(land_target.x, -SIZE)
				position = fall_from
		FallPhase.IN:
			fall_t += delta / FALL_IN_TIME
			var t := clampf(fall_t, 0.0, 1.0)
			# Fall from above the top down to the landing floor, spinning,
			# growing and fading back in as we arrive.
			position.x = land_target.x
			position.y = lerpf(fall_from.y, land_target.y, t)
			draw_spin = FALL_SPIN * t
			draw_scale = t
			draw_alpha = t
			if t >= 1.0:
				position = land_target
				_end_fall()
		_:
			_end_fall()

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
	# You can only push objects that belong to the realm you're currently in.
	# (A physical object is still solid in the dream, but intangible - can't be
	# shoved there; likewise dream objects can only be pushed from the dream.)
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
	var body := Color(0.35, 0.8, 1.0)
	if falling:
		# Spin + shrink/grow + fade are all driven by the fall state.
		draw_set_transform(Vector2.ZERO, draw_spin, Vector2(draw_scale, draw_scale))
		body.a = draw_alpha
	draw_rect(Rect2(-half, -half, SIZE, SIZE), body)
	if falling:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)  # reset for anything after
		return
	if push_target != null:  # little progress bar while you push
		var t := clampf(push_timer / push_target.hold_time(), 0.0, 1.0)
		draw_rect(Rect2(-half, -half - 8, SIZE * t, 3), Color.WHITE)