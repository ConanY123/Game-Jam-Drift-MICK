class_name Goose
extends Pushable

# A pushable that patrols a straight horizontal or vertical line forever.
#
# - Place the goose on one END of its line in the editor. That cell is the
#   start of the patrol, and `start_direction` is the way it walks first.
# - Physical realm object: the player can push it only in the physical realm.
#   In the dream it is still visible (faint outline) and still blocks the
#   player, because the player already collides with the physical map there.
# - The roommate's existing hazard check (`phys is Pushable`) already kills him
#   if he touches it, so roommate.gd needs no changes.
#
# Keep `realm` on Physical in the inspector (the default).

const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const PUSH_SLIDE_TIME := 0.12  # seconds for a pushed goose to slide one cell
const NO_RETURN := -9999  # means "not knocked out of place"

@export_enum("Left", "Right", "Up", "Down") var start_direction := 0
# Number of tiles in the line, INCLUDING the one it starts on.
# 8 means it starts on tile 1 and walks to tile 8 before turning back.
@export var patrol_length := 8
@export var seconds_per_cell := 0.6  # time to walk one tile
@export var push_pause := 0.75  # how long it stands still after being pushed
@export var end_pause := 0.5  # how long it stands still at each end of the line
# After being pushed along its line, walk back to the spot it was knocked from.
@export var return_to_spot_after_push := true
@export var show_path := true  # draw the patrol line (handy while designing)

var _origin := Vector2i.ZERO  # the cell it started on (the line's anchor)
var _along := Vector2i.LEFT  # unit vector along the line
var _perp := Vector2i.DOWN  # unit vector across the line (sideways)
var _heading := 1  # +1 = walking along `_along`, -1 = walking back
var _dest_pos := Vector2.ZERO  # where the sprite is sliding to
var _speed := 0.0  # sprite slide speed in px/s
var _stepping := false  # true while a patrol step is in progress
var _pause_left := 0.0
var _frozen := false  # set once the level is won or lost
var _return_index := NO_RETURN  # spot on the line it must walk back to


func setup(p_level: LevelBase, p_cell: Vector2i) -> void:
	super.setup(p_level, p_cell)
	_origin = cell
	_along = DIRECTIONS[start_direction]
	_perp = Vector2i(absi(_along.y), absi(_along.x))
	_dest_pos = position
	level.level_won.connect(_freeze)
	level.level_lost.connect(_on_level_lost)


func _freeze() -> void:
	_frozen = true


func _on_level_lost(_reason: String) -> void:
	_freeze()


func _physics_process(delta: float) -> void:
	if level == null or _frozen:
		return
	# Same start rule as the roommate: nothing moves until the player does.
	if level.player == null or not level.player.has_moved:
		return

	_pause_left = maxf(_pause_left - delta, 0.0)

	# 1. Keep sliding toward wherever we are headed.
	if position != _dest_pos:
		position = position.move_toward(_dest_pos, _speed * delta)
		queue_redraw()
		if position != _dest_pos:
			return
		_finish_step()

	# 2. Standing still after a push.
	if _pause_left > 0.0:
		return

	# 3. Start the next step, or wait here if it is blocked.
	var step := _choose_step()
	if step == Vector2i.ZERO:
		return
	var target := cell + step
	if _can_enter(target):
		_begin_step(target)
	elif (
		_off_line() == 0
		and _return_index == NO_RETURN
		and level.blocker_at(target, realm) is Goose
	):
		# Another goose is in the way: head back the other way.
		_turn_around_if_possible()


# Decides which way to go next. Getting back onto the line always comes first.
func _choose_step() -> Vector2i:
	var off_line := _off_line()
	if off_line != 0:
		return -_perp * signi(off_line)
	if _return_index != NO_RETURN:
		var gap := _return_index - _along_index()
		if gap != 0:
			return _along * signi(gap)
		_return_index = NO_RETURN  # back where it was knocked from
	if patrol_length <= 1:
		return Vector2i.ZERO
	var next_index := _along_index() + _heading
	if next_index < 0 or next_index > patrol_length - 1:
		# Reached the end of the line: turn around, resting first if asked to.
		_heading = -_heading
		if end_pause > 0.0:
			_pause_left = end_pause
			return Vector2i.ZERO
	return _along * _heading


# How many cells sideways from its line it is (0 = on the line).
func _off_line() -> int:
	var rel := cell - _origin
	return rel.x * _perp.x + rel.y * _perp.y


# Where it is along the line: 0 = the start tile, patrol_length - 1 = far end.
func _along_index() -> int:
	var rel := cell - _origin
	return rel.x * _along.x + rel.y * _along.y


# Every cell on this goose's patrol line (other objects use this to stay clear).
func patrol_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in patrol_length:
		cells.append(_origin + _along * i)
	return cells


# Only turns if the way back is still on the line, so a goose pinned against
# the end of its line just waits instead of flip-flopping.
func _turn_around_if_possible() -> void:
	var back_index := _along_index() - _heading
	if back_index >= 0 and back_index <= patrol_length - 1:
		_heading = -_heading


func _can_enter(target: Vector2i) -> bool:
	if not level.is_free(target, self, realm):
		return false
	return not _player_overlaps_cell(target)


func _player_overlaps_cell(c: Vector2i) -> bool:
	var p := level.player
	if p == null:
		return false
	var hitbox := Vector2(p.HITBOX_SIZE, p.HITBOX_SIZE)
	var player_rect := Rect2(p.position - hitbox / 2.0, hitbox)
	var cell_rect := Rect2(Grid.cell_to_pos(c), Vector2(Grid.CELL, Grid.CELL))
	return player_rect.intersects(cell_rect)


# While walking, the goose blocks BOTH the cell it is leaving and the one it is
# entering, so what you see matches what blocks you.
func _begin_step(target: Vector2i) -> void:
	var both: Array[Vector2i] = [cell, target]
	level.unregister(self, realm)
	level.register(self, both, realm)
	cell = target
	_dest_pos = Grid.cell_to_pos(cell)
	_speed = Grid.CELL / seconds_per_cell
	_stepping = true


func _finish_step() -> void:
	if not _stepping:
		return
	_stepping = false
	level.unregister(self, realm)
	level.register(self, get_cells(cell), realm)


# Unlike a chair, a goose can be pushed while it is mid-step, so there is no
# `moving` check here. Everything else matches Pushable.can_push.
func can_push(dir: Vector2i) -> bool:
	if dir == Vector2i.ZERO or level == null:
		return false
	for c in get_cells(cell + dir):
		if not level.is_free(c, self, realm) or level.in_push_ban(c):
			return false
	return true


func try_push(dir: Vector2i) -> bool:
	if not can_push(dir):
		return false
	AudioManager.play_goose_honk()
	# Remember the spot it was knocked from. Only the first push counts, so a
	# second push before it gets back doesn't move that spot.
	if return_to_spot_after_push and _return_index == NO_RETURN:
		_return_index = _along_index()
	level.unregister(self, realm)
	cell += dir
	level.register(self, get_cells(cell), realm)
	_stepping = false  # cancels any patrol step in progress
	_dest_pos = Grid.cell_to_pos(cell)
	_speed = Grid.CELL / PUSH_SLIDE_TIME
	# The pause counts down while it slides, so add the slide time to it.
	_pause_left = PUSH_SLIDE_TIME + push_pause
	return true


func _draw() -> void:
	super._draw()
	if not show_path or level == null or level.realm != realm:
		return
	var start := Grid.cell_to_center(_origin) - position
	var end := Grid.cell_to_center(_origin + _along * (patrol_length - 1)) - position
	draw_line(start, end, Color(1.0, 1.0, 1.0, 0.25), 2.0)
	draw_circle(start, 3.0, Color(1.0, 1.0, 1.0, 0.35))
	draw_circle(end, 3.0, Color(1.0, 1.0, 1.0, 0.35))
