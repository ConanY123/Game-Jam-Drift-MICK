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

@onready var _anim: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

var powered := false
var _roommate_on := false
var _roommate_entry := Vector2.ZERO

func _init() -> void:
	base_size = Vector2i(2, 1)  # one 64x32 frame; scene values still override

func _ready() -> void:
	super._ready()
	_update_power(true)

func _physics_process(delta: float) -> void:
	if level == null:
		return
	_update_power()
	var r := level.roommate as Roommate
	if r != null:
		_track_roommate(r)
	_apply_belt(delta)

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
	for source in get_tree().get_nodes_in_group("signal_sources"):
		if not (source is Node2D) or not _is_outlet(source):
			continue
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

# ---------- running (drives linked TreadmillPlatforms) ----------

# Powered AND someone is on the belt: the roommate, or the player standing in
# the walk lane in the treadmill's realm.
func is_running() -> bool:
	if not powered or level == null:
		return false
	if _roommate_on:
		return true
	var p := level.player
	return (
		p != null
		and not p.falling
		and level.realm == realm
		and body_on_walkway(p.position, p.hitbox_half())
	)

# ---------- player ----------

# The treadmill is a physical-world object: no pushing/interacting while the
# player is viewing the dream realm.
func can_interact(dir: Vector2i) -> bool:
	if level != null and level.realm != realm:
		return false
	return super.can_interact(dir)

func _apply_belt(delta: float) -> void:
	if not powered or moving or level.realm != realm or level.gameplay_locked():
		return
	var p := level.player
	if p == null or p.falling:
		return
	if not body_on_walkway(p.position, p.hitbox_half()):
		return
	# Goes through the player's own collision, so the belt can't shove them
	# into a wall behind the entrance.
	p._move_axis(-forward_axis() * belt_speed * delta)

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
