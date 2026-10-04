class_name Roommate
extends Node2D

# The sleepwalker. Walks a fixed route of cells at a steady pace, holding the
# same position in both realms (swapping only changes the world around him).
#
# Lose conditions (shared timeline - judged on the real world state, not the
# realm you happen to be viewing):
#   - a solid obstacle sits on the cell he is entering in the physical world
#   - the cell he is on in the dream has no standable floor (you failed the
#     platform puzzle) -> he drops into the void
# Win: he reaches the final waypoint untouched.
#
# Top-down 2D. Hazard detection is grid-based to match the rest of the project;
# the body is an AnimatedSprite2D child so its art can be swapped independently.
# The sprite needs animations named walk_down, walk_up, walk_left, walk_right.

const SPEED := 24.0  # slow sleepwalker pace; player (96) is ~4x faster
const FALL_DROP_CELLS := 2.0
const FALL_OUT_TIME := 0.35
const FALL_SPIN := TAU * 1.0
const SLEEP_Z_COLORS := {
	LevelBase.Realm.PHYSICAL: Color("#173b78"),
	LevelBase.Realm.DREAM: Color("#ff5bbd"),
}
const SLEEP_Z_INTERVAL := 0.75
const SLEEP_Z_LIFETIME := 1.5

signal won
signal lost(reason: String)

@export var route: Array[Vector2i] = []  # authored path in cells

var level: LevelBase
var waypoints: PackedVector2Array = PackedVector2Array()
var index := 0  # waypoint we are walking toward
var finished := false
var dead := false
var falling := false  # dream-fail death animation in progress
var fall_t := 0.0
var fall_from := Vector2.ZERO

var _facing_anim := "walk_down"  # last direction he was heading
var _anim_base_scale := Vector2.ONE
var _sleep_z_timer := 0.25
var _sleep_z_particles: Array[Label] = []

# Finds the AnimatedSprite2D automatically: a child named "AnimatedSprite2D" or
# "BodyVisual" first, otherwise any AnimatedSprite2D child.
@onready var _anim: AnimatedSprite2D = _find_sprite()

func _find_sprite() -> AnimatedSprite2D:
	for node_name in ["AnimatedSprite2D", "BodyVisual"]:
		var found := get_node_or_null(node_name) as AnimatedSprite2D
		if found != null:
			return found
	for child in get_children():
		if child is AnimatedSprite2D:
			return child
	return null

# True if any visual child exists, so the fallback square isn't drawn on top.
func _has_art() -> bool:
	return _anim != null or get_node_or_null("BodyVisual") != null

func setup(p_level: LevelBase, p_route: Array[Vector2i]) -> void:
	level = p_level
	route = p_route
	_rebuild_waypoints()
	_connect_realm_changed()

func _ready() -> void:
	# Allow either setup() (code spawn) or an inspector-authored route.
	if waypoints.is_empty() and route.size() > 0:
		_rebuild_waypoints()
	_connect_realm_changed()
	if _anim != null:
		_anim_base_scale = _anim.scale
	_update_animation()
	queue_redraw()

func _process(delta: float) -> void:
	if level == null:
		return
	_update_sleep_z_particles(delta)

func _connect_realm_changed() -> void:
	if level != null and not level.realm_changed.is_connected(_on_realm_changed):
		level.realm_changed.connect(_on_realm_changed)

func _on_realm_changed(_new_realm: LevelBase.Realm) -> void:
	var outline_color: Color = SLEEP_Z_COLORS[level.realm]
	for particle in _sleep_z_particles:
		if is_instance_valid(particle):
			particle.add_theme_color_override("font_outline_color", outline_color)

func _update_sleep_z_particles(delta: float) -> void:
	if not dead and not falling:
		_sleep_z_timer -= delta
		if _sleep_z_timer <= 0.0:
			_spawn_sleep_z()
			_sleep_z_timer = SLEEP_Z_INTERVAL

func _spawn_sleep_z() -> void:
	var particle := Label.new()
	particle.text = "Z"
	particle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	particle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	particle.add_theme_font_size_override("font_size", randi_range(9, 13))
	particle.add_theme_color_override("font_color", Color("#f4f2ff"))
	particle.add_theme_color_override(
		"font_outline_color",
		SLEEP_Z_COLORS[level.realm]
	)
	particle.add_theme_constant_override("outline_size", 2)
	particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particle.size = Vector2(20.0, 18.0)
	add_child(particle)
	particle.position = Vector2(randf_range(-9.0, 9.0) - 10.0, -32.0)
	_sleep_z_particles.append(particle)

	var lifetime := randf_range(1.1, SLEEP_Z_LIFETIME)
	var tween := create_tween().set_parallel()
	tween.tween_property(
		particle,
		"position",
		particle.position + Vector2(randf_range(-8.0, 8.0), -27.0),
		lifetime
	)
	tween.tween_property(particle, "modulate:a", 0.0, lifetime)
	tween.chain().tween_callback(_remove_sleep_z.bind(particle))

func _remove_sleep_z(particle: Label) -> void:
	_sleep_z_particles.erase(particle)
	particle.queue_free()

func _rebuild_waypoints() -> void:
	waypoints = PackedVector2Array()
	for cell in route:
		waypoints.append(Grid.cell_to_center(cell))
	if waypoints.size() > 0:
		position = waypoints[0]
		index = 1  # start toward the second point

func _physics_process(delta: float) -> void:
	if level == null:
		return
	_update_animation()
	if level.player == null or not level.player.has_moved:
		return
	if falling:
		_update_fall(delta)
		return
	if finished or dead:
		return
	if index >= waypoints.size():
		return

	# Walk toward the current waypoint at a steady pace.
	var target := waypoints[index]
	var to_target := target - position
	var dist := to_target.length()
	var step := SPEED * delta
	if step >= dist:
		position = target
		index += 1
		if index >= waypoints.size():
			_finish()
	else:
		position += to_target / dist * step

	_check_hazards()
	queue_redraw()

# ---------- animation ----------

# Walking only while the hour is running and he still has somewhere to go.
func _is_walking() -> bool:
	return (
		level != null
		and level.player != null
		and level.player.has_moved
		and not finished
		and not dead
		and not falling
		and index < waypoints.size()
	)

# Picks the walk strip from the direction he is heading. Plays while walking,
# rests on the first frame (still facing the same way) when he is not.
func _update_animation() -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	if index < waypoints.size():
		var d := waypoints[index] - position
		if d.length() > 0.01:
			if absf(d.x) > absf(d.y):
				_facing_anim = "walk_right" if d.x > 0.0 else "walk_left"
			else:
				_facing_anim = "walk_down" if d.y > 0.0 else "walk_up"
	if not _anim.sprite_frames.has_animation(_facing_anim):
		return
	if _is_walking():
		if _anim.animation != _facing_anim or not _anim.is_playing():
			_anim.play(_facing_anim)
	else:
		_anim.animation = _facing_anim
		_anim.stop()
		_anim.frame = 0

func current_cell() -> Vector2i:
	return Grid.pos_to_cell(position)

# Judged on actual world state, not the realm currently being viewed.
func _check_hazards() -> void:
	var cell := current_cell()

	# A removable obstacle left on his path in the physical world kills him.
	# Walls shouldn't be authored onto the route, so only Pushables count.
	var phys := level.blocker_at(cell, LevelBase.Realm.PHYSICAL)
	if phys is Pushable:
		_die("hit an obstacle in the real world")
		return

	# No standable floor beneath him in the dream = failed platform puzzle.
	if not level.is_dream_floor(cell):
		_begin_fall()
		return

	# A deadly solid object sitting in the dream (non-floor) also kills.
	var dream_obj := level.blocker_at(cell, LevelBase.Realm.DREAM)
	if dream_obj is Pushable and not dream_obj.is_floor:
		_die("hit something in the dream")

func _finish() -> void:
	finished = true
	won.emit()
	queue_redraw()

func _die(reason: String) -> void:
	if dead or falling:
		return
	dead = true
	lost.emit(reason)
	queue_redraw()

func kill(reason: String) -> void:
	_die(reason)

# Dream fall is a loss, with a short drop-into-the-void animation first.
func _begin_fall() -> void:
	if dead or falling:
		return
	falling = true
	fall_t = 0.0
	fall_from = position
	if _anim != null:
		_anim.rotation = 0.0
		_anim.scale = _anim_base_scale
		_anim.modulate.a = 1.0
	queue_redraw()

func _update_fall(delta: float) -> void:
	fall_t += delta / FALL_OUT_TIME
	var t := clampf(fall_t, 0.0, 1.0)
	position.y = fall_from.y + FALL_DROP_CELLS * Grid.CELL * t
	if _anim != null:
		_anim.rotation = FALL_SPIN * t
		_anim.scale = _anim_base_scale * (1.0 - t)
		_anim.modulate.a = 1.0 - t
	queue_redraw()
	if t >= 1.0:
		falling = false
		_die("fell through a gap in the dream")

# Fallback visual if no sprite child exists (e.g. pure-code spawn).
func _draw() -> void:
	if _has_art():
		return
	var s := 20.0
	var half := s / 2.0
	var body := Color(0.9, 0.85, 0.5)
	if dead:
		body = Color(0.8, 0.2, 0.2)
	elif finished:
		body = Color(0.4, 0.9, 0.5)
	draw_rect(Rect2(-half, -half, s, s), body)
	if index < waypoints.size() and not finished and not dead and not falling:
		var dir := (waypoints[index] - position).normalized()
		draw_circle(dir * half, 3.0, Color.BLACK)