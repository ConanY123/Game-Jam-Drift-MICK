class_name Treadmill
extends Walkable

# Treadmill. The belt half (entrance side) is walkable; see Walkable for the
# entrance / side / depth rules. The art faces left, so the entrance is the
# left edge of the unrotated sprite and follows the node when you rotate it.
#
# Powered (an outlet within power_radius tiles of any footprint cell):
#   - the AnimatedSprite2D plays
#   - the belt pushes the player back toward the entrance at belt_speed. At the
#     default (player SPEED) walking forward = standing still, standing still =
#     carried out, walking out = carried out twice as fast
#   - the roommate gets stuck on it until it is pushed off him
# Unpowered:
#   - no animation, no belt
#   - the roommate walks onto it and crashes (game over) once he has walked
#     unpowered_crash_fraction of the way through

@export_range(0, 3, 1) var power_radius := 1
@export var belt_speed := 96.0
@export_range(0.0, 1.0, 0.05) var unpowered_crash_fraction := 0.8

# Signal outputs the treadmill drives while it is running (same contract as
# SignalSource): each path should point to a node with turn_on()/turn_off(),
# e.g. a MovingPlatform. Running the belt turns them on; stopping turns them off.
@export var outputs: Array[NodePath] = []

# Optional specific outlet that powers this treadmill. When set, only that
# outlet counts (and only while it's within power_radius). When left empty, any
# outlet in range powers it (the old proximity behaviour).
@export var outlet: NodePath

@onready var _anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var powered := false
var _running := false
var _roommate_on := false
var _roommate_entry := Vector2.ZERO
var _added_floor := {}  # dream-floor cells this treadmill added (to clean up on push)

func _init() -> void:
	base_size = Vector2i(2, 1)  # one 64x32 frame; scene values still override

func _ready() -> void:
	super._ready()
	_update_power(true)
	_mark_dream_floor()

# The treadmill is standable in the dream too, so the player (and roommate) can
# run on it there without falling through. Mark its footprint as dream floor and
# keep it in sync when the treadmill is pushed to new cells. Only cells the
# treadmill itself added are cleared later, never pre-existing authored floor.
func _mark_dream_floor() -> void:
	for c in get_cells(cell):
		if not level.dream_floor.has(c):
			_added_floor[c] = true
			level.dream_floor[c] = true

func _clear_dream_floor() -> void:
	for c in _added_floor.keys():
		level.dream_floor.erase(c)
	_added_floor.clear()

func try_push(dir: Vector2i) -> bool:
	_clear_dream_floor()
	var pushed := super.try_push(dir)
	_mark_dream_floor()
	return pushed

func _physics_process(delta: float) -> void:
	if level == null:
		return
	_update_power()
	var r := level.roommate as Roommate
	if r != null:
		_track_roommate(r)
	_apply_belt(delta)
	_update_outputs()

# ---------- signal output (drives MovingPlatform etc.) ----------

# Emits turn_on/turn_off to the linked outputs when the running state flips.
func _update_outputs() -> void:
	var now := is_running()
	if now == _running:
		return
	_running = now
	for path in outputs:
		var node := get_node_or_null(path)
		if node == null:
			continue
		if now and node.has_method("turn_on"):
			node.call("turn_on")
		elif not now and node.has_method("turn_off"):
			node.call("turn_off")

# ---------- power ----------

func _update_power(force := false) -> void:
	var next := _near_outlet()
	if next == powered and not force:
		return
	powered = next
	if _anim == null:
		return
	if powered:
		_anim.play()
	else:
		_anim.stop()
		_anim.frame = 0

func _near_outlet() -> bool:
	var cells := get_cells(cell)
	# Explicit link: only the assigned outlet can power this treadmill.
	if not outlet.is_empty():
		var linked := get_node_or_null(outlet) as Node2D
		return linked != null and _outlet_in_range(linked, cells)
	# Otherwise any outlet within range powers it.
	for source in get_tree().get_nodes_in_group("signal_sources"):
		if not (source is Node2D) or not _is_outlet(source):
			continue
		if _outlet_in_range(source, cells):
			return true
	return false

func _outlet_in_range(source: Node2D, cells: Array[Vector2i]) -> bool:
	var outlet_cell := Grid.pos_to_cell(level.to_local(source.global_position))
	for c in cells:
		if absi(c.x - outlet_cell.x) <= power_radius and absi(c.y - outlet_cell.y) <= power_radius:
			return true
	return false

func _is_outlet(node: Node) -> bool:
	return (
		node.name.to_lower().contains("outlet")
		or node.scene_file_path.to_lower().contains("outlet")
	)

# ---------- running (drives linked signal outputs) ----------

# True while something is actively driving the belt, which is what powers the
# linked signal outputs. The treadmill must be powered by a nearby outlet first;
# with power, it runs when either:
#   - the roommate is stuck on the belt, OR
#   - the player is on the walkway and running on it.
func is_running() -> bool:
	if level == null or not powered:
		return false
	if _roommate_on:
		return true
	return _player_running()

# The player is standing in the walk lane and actively moving (running on the
# belt). Works in either realm, so running on it in the dream drives outputs too.
func _player_running() -> bool:
	var p := level.player
	if p == null or p.falling or level.gameplay_locked():
		return false
	if not body_on_walkway(p.position, p.hitbox_half()):
		return false
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return input.length() > 0.1

# ---------- player ----------

# The treadmill can be pushed/interacted with from either realm.
func interactable_in_any_realm() -> bool:
	return true

func _apply_belt(delta: float) -> void:
	if not powered or moving or level.gameplay_locked():
		return
	var p := level.player
	if p == null or p.falling:
		return
	if not body_on_walkway(p.position, p.hitbox_half()):
		return
	# The belt drags the player back toward the entrance, but only enough that
	# they can still make headway when they actively run inward. When idle, the
	# belt carries them out; when running against it, they advance (slowly).
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var pushing_in := input.dot(forward_axis()) > 0.1
	var drag := belt_speed * (0.5 if pushing_in else 1.0)
	# Goes through the player's own collision, so the belt can't shove them
	# into a wall behind the entrance.
	p._move_axis(-forward_axis() * drag * delta)

# ---------- roommate ----------

func _track_roommate(r: Roommate) -> void:
	if covers_cell(r.current_cell()):
		if not _roommate_on:
			_roommate_on = true
			_roommate_entry = r.position
	else:
		_roommate_on = false

func holds_roommate(roommate: Node2D) -> bool:
	_track_roommate(roommate as Roommate)
	return powered and _roommate_on

func roommate_hazard(roommate: Node2D) -> String:
	var r := roommate as Roommate
	_track_roommate(r)
	if powered or not _roommate_on:
		return ""
	var dir := _axis(r.move_direction())
	if dir == Vector2.ZERO:
		return ""
	var extent := absf(dir.x) * size.x * Grid.CELL + absf(dir.y) * size.y * Grid.CELL
	if (r.position - _roommate_entry).dot(dir) >= extent * unpowered_crash_fraction:
		return "crashed into the treadmill"
	return ""

func _axis(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2.ZERO
	if absf(v.x) >= absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))
