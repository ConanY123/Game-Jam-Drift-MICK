@tool
class_name TreadmillPlatform
extends Node2D

# A dream-floor platform driven by a Treadmill.
#
# This is a self-contained scene (treadmill_platform.tscn). It owns two
# TileMapLayer children built from Source 4 of tileset1 (Tilemap-Dream.png):
#   - DreamTiles: the visible platform, shown in the dream realm.
#   - GhostTiles: a faint copy shown in the physical realm so the player can
#     see where the dream floor is. Neither layer is a wall; the platform only
#     registers its cells as dream floor, so the player and roommate can stand
#     on it but nothing is ever blocked by it.
#
# Place the instance in a level (anywhere; snap it to the 32px grid). Its
# position is the top-left cell of the platform at rest. Link it to a treadmill
# by dragging that Treadmill node into "Treadmill" in the Inspector
# (Treadmill1 -> Platform1, Treadmill2 -> Platform2, ...). While the treadmill
# runs, the platform slides `distance` cells in `direction`; when it stops, it
# slides back to its start at `return_speed`.

enum Direction { RIGHT, LEFT, DOWN, UP }
enum Orientation { HORIZONTAL, VERTICAL }

@export var treadmill: Treadmill

@export_group("Shape")
@export_range(1, 24, 1) var length := 3:
	set(v):
		length = v
		_rebuild_tiles()
@export_range(1, 8, 1) var thickness := 1:
	set(v):
		thickness = v
		_rebuild_tiles()
@export var orientation := Orientation.HORIZONTAL:
	set(v):
		orientation = v
		_rebuild_tiles()

@export_group("Motion")
@export var direction := Direction.RIGHT:
	set(v):
		direction = v
		queue_redraw()
@export_range(0, 24, 1) var distance := 3:
	set(v):
		distance = v
		queue_redraw()
## Cells per second while the treadmill is running.
@export_range(0.1, 20.0, 0.1) var speed := 2.0
## Cells per second on the way back once the treadmill stops.
@export_range(0.1, 20.0, 0.1) var return_speed := 2.0
## On: only moves while someone (player or roommate) is on the powered belt.
## Off: moves whenever the treadmill has outlet power.
@export var needs_runner := true

@export_group("Look")
@export var source_id := 4  # Tilemap-Dream.png in tileset1.tres
@export var atlas_coords := Vector2i(6, 1):
	set(v):
		atlas_coords = v
		_rebuild_tiles()
@export_range(0.0, 1.0, 0.05) var ghost_alpha := 0.35:
	set(v):
		ghost_alpha = v
		if _ghost_tiles != null:
			_ghost_tiles.modulate.a = v

@onready var _dream_tiles: TileMapLayer = get_node_or_null("DreamTiles")
@onready var _ghost_tiles: TileMapLayer = get_node_or_null("GhostTiles")

var level: LevelBase
var start_cell := Vector2i.ZERO
var progress := 0.0  # cells travelled from the start, 0..distance
var _registered: Array[Vector2i] = []

func _ready() -> void:
	_rebuild_tiles()
	if Engine.is_editor_hint():
		return
	level = _find_level()
	if level == null:
		push_error("TreadmillPlatform '%s' is not inside a level." % name)
		set_physics_process(false)
		return
	if treadmill == null:
		push_warning("TreadmillPlatform '%s' has no Treadmill linked; it will never move." % name)
	start_cell = Grid.pos_to_cell(level.to_local(global_position) + Vector2.ONE)
	_sync_floor(0)
	_update_realm_visibility()
	level.realm_changed.connect(func(_r): _update_realm_visibility())

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or level == null:
		return
	var target := float(distance) if _is_driven() else 0.0
	if not is_equal_approx(progress, target):
		var rate := speed if target > progress else return_speed
		progress = move_toward(progress, target, rate * delta)
		_sync_floor(progress)
	# Smoothly follow the (fractional) progress so the tiles glide.
	position = Grid.cell_to_pos(start_cell) + Vector2(step()) * progress * Grid.CELL
	if show_path:
		queue_redraw()  # keep the path anchored to the world as the node moves

func _is_driven() -> bool:
	if treadmill == null or not is_instance_valid(treadmill):
		return false
	return treadmill.is_running() if needs_runner else treadmill.powered

# ---------- cells ----------

func footprint() -> Vector2i:
	if orientation == Orientation.HORIZONTAL:
		return Vector2i(length, thickness)
	return Vector2i(thickness, length)

func step() -> Vector2i:
	match direction:
		Direction.LEFT:
			return Vector2i.LEFT
		Direction.DOWN:
			return Vector2i.DOWN
		Direction.UP:
			return Vector2i.UP
	return Vector2i.RIGHT

func _local_cells() -> Array[Vector2i]:
	var size := footprint()
	var result: Array[Vector2i] = []
	for x in size.x:
		for y in size.y:
			result.append(Vector2i(x, y))
	return result

# The grid cells the platform floor occupies at a given (rounded) offset.
func cells_at(offset: int) -> Array[Vector2i]:
	var origin := start_cell + step() * offset
	var result: Array[Vector2i] = []
	for c in _local_cells():
		result.append(origin + c)
	return result

# ---------- dream-floor registration ----------

# Keeps level.dream_floor in sync with where the platform currently sits.
func _sync_floor(offset: float) -> void:
	var next := cells_at(roundi(offset))
	for c in _registered:
		if not next.has(c):
			level.dream_floor.erase(c)
	for c in next:
		level.dream_floor[c] = true
	_registered = next

# ---------- tiles / visuals ----------

# Rebuilds both child tile layers to match the current shape. Local cells only;
# the node's position is what moves them in the world.
func _rebuild_tiles() -> void:
	if _dream_tiles == null:
		_dream_tiles = get_node_or_null("DreamTiles")
		_ghost_tiles = get_node_or_null("GhostTiles")
	if _dream_tiles == null or _ghost_tiles == null:
		return
	_ghost_tiles.modulate.a = ghost_alpha
	for layer in [_dream_tiles, _ghost_tiles]:
		layer.clear()
		for c in _local_cells():
			layer.set_cell(c, source_id, atlas_coords)
	queue_redraw()

func _update_realm_visibility() -> void:
	if _dream_tiles != null:
		_dream_tiles.visible = level.realm == LevelBase.Realm.DREAM
	if _ghost_tiles != null:
		_ghost_tiles.visible = level.realm == LevelBase.Realm.PHYSICAL

func _find_level() -> LevelBase:
	var node := get_parent()
	while node != null and not node is LevelBase:
		node = node.get_parent()
	return node as LevelBase

# ---------- path visual ----------

## Draw the travel path (rest spot -> end spot) in-game, not just the editor.
@export_group("Path Visual")
@export var show_path := true
@export var path_color := Color(1.0, 0.85, 0.4, 0.5)

# Visible both in the editor (anchored at the node) and at runtime. At runtime
# the node glides, so everything is drawn relative to the fixed start cell by
# subtracting the node's current travel offset.
func _draw() -> void:
	if not show_path or distance <= 0:
		return
	var size := Vector2(footprint() * Grid.CELL)
	var travel := Vector2(step() * distance * Grid.CELL)
	# Offset of the rest position from the node's current position, in local space.
	var rest_local := Vector2.ZERO
	if not Engine.is_editor_hint():
		rest_local = Grid.cell_to_pos(start_cell) - position
	var end_local := rest_local + travel
	# Dashed corridor between the two endpoints.
	var corridor_a := rest_local.min(end_local)
	var corridor_b := (rest_local + size).max(end_local + size)
	draw_rect(Rect2(corridor_a, corridor_b - corridor_a), Color(path_color, path_color.a * 0.25))
	# Endpoints: rest (solid) and destination (outline).
	draw_rect(Rect2(rest_local, size), path_color, false, 2.0)
	draw_rect(Rect2(end_local, size), Color(path_color, path_color.a * 0.7), false, 2.0)
	draw_line(rest_local + size * 0.5, end_local + size * 0.5, path_color, 2.0)
