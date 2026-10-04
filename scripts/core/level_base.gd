class_name LevelBase
extends Node2D

# Base for every level. Owns the occupancy map and draws the debug grid.
# A level script extends this and overrides build().

@export var debug_grid := true
@export var level_number: int = 1
@export_group("Intro Caption")
@export var caption_title := ""
@export_range(0.0, 6.0, 0.1) var caption_hold := 2.0
@export_group("")
@export_range(0.0, 5.0, 0.1) var death_transition_duration := 1.0
@export_range(0.0, 5.0, 0.1) var death_screen_duration := 1.25
@export_range(0.0, 5.0, 0.1) var reset_transition_duration := 1.0
@export_range(0.0, 5.0, 0.1) var realm_transition_duration := 0.8
@export_range(0.0, 5.0, 0.1) var completion_transition_duration := 1.0

# The pink wall tiles are a second atlas source in the same TileSet,
# laid out exactly like the normal one.
const DREAM_WALL_SOURCE_ID := 6  # change to the pink source's ID
const PHYSICAL_WALL_SOURCE_ID := 0
const MERGED_WALL_ATLAS_OFFSET := Vector2i(15, 0)

var _wall_cells := {}  # Vector2i -> [source_id, atlas_coords, alternative]

enum Realm { 
	PHYSICAL, 
	DREAM 
}
signal realm_changed(new_realm: Realm)
signal realm_switch_failed_low_stamina
signal level_won
signal level_lost(reason: String)

const ROOMMATE_SCENE := preload("res://scenes/actors/roommate.tscn")
const RESULT_OVERLAY_SCENE := preload("res://scenes/ui/result_overlay.tscn")
const STAMINA_BAR_SCENE := preload("res://scenes/ui/stamina_bar.tscn")
const LEVEL_CAPTION_SCENE := preload("res://scenes/ui/level_caption.tscn")
const ROOMMATE_PATH_OVERLAY_SCRIPT := preload("res://scripts/core/roommate_path_overlay.gd")

var realm := Realm.PHYSICAL
var roommate: Node2D

# Vector2i -> Node. The level itself is stored for static walls.
var solids := {
	Realm.PHYSICAL: {},
	Realm.DREAM: {},
}
var wall_rects: Array[Rect2i] = []
var debug_path: Array[Vector2i] = []  # placeholder until the roommate exists

var dream_floor := {}  # Vector2i -> true
var player: Player
var roommate_path_overlay: RoommatePathOverlay
var result_overlay: Node
var _level_ended := false

func add_dream_floor(rect: Rect2i) -> void:
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			dream_floor[Vector2i(x, y)] = true

# Punch a single cell back out of the dream floor (e.g. a gap the player must
# bridge). Note: this only clears authored floor, not bridge pushables.
func remove_dream_floor(cell: Vector2i) -> void:
	dream_floor.erase(cell)

func closest_dream_floor(pos: Vector2) -> Vector2:
	if dream_floor.is_empty():
		return pos
	var best_cell := Vector2i.ZERO
	var best_dist_sq := INF
	for cell in dream_floor.keys():
		var d2 := pos.distance_squared_to(Grid.cell_to_center(cell))
		if d2 < best_dist_sq:
			best_dist_sq = d2
			best_cell = cell
	return Grid.cell_to_center(best_cell)

# Can the roommate stand here in the dream?
func is_dream_floor(cell: Vector2i) -> bool:
	if dream_floor.has(cell):
		return true
	for platform in get_tree().get_nodes_in_group("moving_platforms"):
		if not platform is MovingPlatform:
			continue
		if platform.level == self and platform.supports_cell(cell):
			return true
	var b = solids[Realm.DREAM].get(cell)
	return b is Pushable and b.is_floor

# True when the player is standing over a dream gap (no floor) and should fall.
# Only meaningful in the dream realm. In the physical realm the ground is solid.
func player_over_dream_gap() -> bool:
	if player == null or realm != Realm.DREAM:
		return false
	var cell := Grid.pos_to_cell(player.position)
	if not Grid.in_bounds(cell):
		return true
	return not is_dream_floor(cell)

func _ready() -> void:
	_load_tilemaps()
	roommate_path_overlay = ROOMMATE_PATH_OVERLAY_SCRIPT.new()
	# Keep the route above floor objects, but below ordinary obstacles.
	roommate_path_overlay.z_index = -1
	roommate_path_overlay.z_as_relative = false
	add_child(roommate_path_overlay)
	build()
	_update_layers()
	realm_changed.connect(func(_r): _update_layers())
	AudioManager.set_dream_reverb(realm == Realm.DREAM, 0.0)
	AudioManager.set_dream_music_quieter(realm == Realm.DREAM, 0.0)
	var overlay := RESULT_OVERLAY_SCENE.instantiate()
	add_child(overlay)
	result_overlay = overlay
	var stamina_bar := STAMINA_BAR_SCENE.instantiate()
	add_child(stamina_bar)
	stamina_bar.call("setup", self)
	_show_intro_caption()
	AudioManager.play_music(level_number)   # start this level's track (runs on load + every retry)
	level_won.connect(_on_level_won)
	level_lost.connect(_on_level_lost)
	queue_redraw()

func build() -> void:
	pass  # levels override this

# Shows the themed title card at level start. Each level sets caption_title /
# caption_subtitle in the editor (or in build()). Empty title = no card.
func _show_intro_caption() -> void:
	if caption_title.strip_edges().is_empty():
		return
	var caption := LEVEL_CAPTION_SCENE.instantiate()
	add_child(caption)
	caption.call(
		"show_caption",
		caption_title,
		"",
		caption_hold,
		_level_time_label()
	)

func _level_time_label() -> String:
	var level_manager := get_node("/root/LevelManager")
	var level_index: int = level_manager.current_level
	var hour := posmod(level_index, 12)
	if hour == 0:
		hour = 12
	var period := "AM" if level_index < 12 else "PM"
	return "%d:00 %s" % [hour, period]

func gameplay_locked() -> bool:
	var transitions := get_node_or_null("/root/TransitionManager")
	return _level_ended or (
		transitions != null and transitions.call("is_transitioning")
	)

func _unhandled_input(event: InputEvent) -> void:
	if _level_ended:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		_play_transition(reset_transition_duration, _reset_level)
	elif event.is_action_pressed("switch_realm"):
		switch_realm()

func switch_realm() -> void:
	if (
		realm == Realm.DREAM
		and player != null
		and not player.can_switch_to_physical()
	):
		realm_switch_failed_low_stamina.emit()
		return
	var wipe_color := Color(0.9294, 0.2157, 0.7255, 1.0)
	var edge_color := Color(1.0, 0.55, 0.85, 1.0)
	if realm == Realm.DREAM:
		wipe_color = Color(0.08, 0.16, 0.36, 1.0)
		edge_color = Color(0.38, 0.7, 1.0, 1.0)
	_play_transition(
		realm_transition_duration,
		_apply_realm_switch,
		wipe_color,
		edge_color
	)

func _apply_realm_switch() -> void:
	realm = Realm.DREAM if realm == Realm.PHYSICAL else Realm.PHYSICAL
	realm_changed.emit(realm)
	AudioManager.set_dream_reverb(
		realm == Realm.DREAM,
		realm_transition_duration * 0.5
	)
	AudioManager.set_dream_music_quieter(
		realm == Realm.DREAM,
		realm_transition_duration * 0.5
	)
	queue_redraw()

func _reset_level() -> bool:
	get_node("/root/AudioManager").call("play_music", level_number)
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("Could not reload level: %s" % error_string(error))
		return false
	return true

func _on_level_won() -> void:
	if _level_ended:
		return
	_level_ended = true
	_play_transition(
		completion_transition_duration,
		_complete_level,
		Color(0.12, 0.28, 0.16, 1.0),
		Color(0.55, 1.0, 0.65, 1.0)
	)

func _on_level_lost(reason: String) -> void:
	if _level_ended:
		return
	_level_ended = true
	result_overlay.call("show_loss", reason)
	_restart_after_death()

func _restart_after_death() -> void:
	await get_tree().create_timer(death_screen_duration).timeout
	_play_transition(
		death_transition_duration,
		_reset_level,
		Color.BLACK,
		Color.BLACK,
		true
	)

func _play_transition(
	duration: float,
	action: Callable,
	wipe_color := Color(0.015, 0.02, 0.055, 1.0),
	edge_color := Color(0.35, 0.85, 1.0, 1.0),
	wait_for_scene_change := false
) -> void:
	get_node("/root/TransitionManager").call(
		"play",
		duration,
		action,
		wipe_color,
		edge_color,
		wait_for_scene_change
	)

func _complete_level() -> void:
	result_overlay.call("show_win")
	get_node("/root/LevelManager").call("advance_level")

# ---------- occupancy ----------

func register(obj: Node, cells: Array[Vector2i], in_realm: int) -> void:
	for c in cells:
		solids[in_realm][c] = obj

func unregister(obj: Node, in_realm: int) -> void:
	var map: Dictionary = solids[in_realm]
	for c in map.keys():
		if map[c] == obj:
			map.erase(c)

# Returns null if the cell is free, otherwise whatever blocks it.
# Defaults to the physical map, which is the one the player collides with.
func blocker_at(cell: Vector2i, in_realm: int = Realm.PHYSICAL) -> Node:
	if not Grid.in_bounds(cell):
		return self
	return solids[in_realm].get(cell)

func is_free(cell: Vector2i, ignore: Node = null, in_realm: int = Realm.PHYSICAL) -> bool:
	var b := blocker_at(cell, in_realm)
	return b == null or b == ignore

# Hook for the roommate later: no pushing into his path zone.
func in_push_ban(_cell: Vector2i) -> bool:
	return false

# ---------- building helpers ----------

func add_wall(rect: Rect2i) -> void:
	wall_rects.append(rect)
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			solids[Realm.PHYSICAL][Vector2i(x, y)] = self
			solids[Realm.DREAM][Vector2i(x, y)] = self

func add_pushable(cell: Vector2i, size := Vector2i(1, 1), weight := 1.0, color := Color(0.85, 0.65, 0.3), in_realm: int = Realm.PHYSICAL, holdable := false) -> Pushable:
	var p := Pushable.new()
	p.size = size
	p.weight = weight
	p.color = color
	p.realm = in_realm
	p.holdable = holdable
	p.position = Grid.cell_to_pos(cell)
	add_child(p)  # its _ready registers it with this level
	return p

func add_slidable(cell: Vector2i, size := Vector2i(1, 1), weight := 1.0, color := Color(0.4, 0.7, 0.85), in_realm: int = Realm.PHYSICAL, holdable := false) -> Slidable:
	var s := Slidable.new()
	s.size = size
	s.weight = weight
	s.color = color
	s.realm = in_realm
	s.holdable = holdable
	s.position = Grid.cell_to_pos(cell)
	add_child(s)  # its _ready registers it with this level
	return s

const PLAYER_SCENE := preload("res://scenes/actors/player.tscn")

func add_player(cell: Vector2i) -> Player:
	var p := PLAYER_SCENE.instantiate() as Player
	p.level = self
	p.position = Grid.cell_to_center(cell)
	player = p
	add_child(p)
	return p

# ---------- tilemaps ----------
func _load_tilemaps() -> void:
	var walls := get_node_or_null("WallLayer") as TileMapLayer
	if walls != null:
		for c in walls.get_used_cells():
			solids[Realm.PHYSICAL][c] = self
			solids[Realm.DREAM][c] = self
			_wall_cells[c] = [
				walls.get_cell_source_id(c),
				walls.get_cell_atlas_coords(c),
				walls.get_cell_alternative_tile(c),
			]
	var dream := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream != null:
		for c in dream.get_used_cells():
			dream_floor[c] = true

func _update_layers() -> void:
	var physical_background := get_node_or_null("PhysicalBackground") as CanvasItem
	if physical_background != null:
		physical_background.visible = realm == Realm.PHYSICAL
		physical_background.z_index = -20
	var dream_background := get_node_or_null("DreamBackground") as CanvasItem
	if dream_background != null:
		dream_background.visible = realm == Realm.DREAM
		dream_background.z_index = -20
	var floor_layer := get_node_or_null("FloorLayer") as TileMapLayer
	if floor_layer != null:
		floor_layer.visible = realm == Realm.DREAM
		floor_layer.z_index = -12
	var dream_layer := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream_layer != null:
		dream_layer.visible = realm == Realm.DREAM
		dream_layer.z_index = -10
	var wall_layer := get_node_or_null("WallLayer") as TileMapLayer
	if wall_layer != null:
		for c in _wall_cells:
			var data: Array = _wall_cells[c]
			var original_source: int = data[0]
			var atlas_coords: Vector2i = data[1]
			if original_source == 2 or original_source == 3:
				atlas_coords += MERGED_WALL_ATLAS_OFFSET
			var source := (
				DREAM_WALL_SOURCE_ID
				if realm == Realm.DREAM
				else PHYSICAL_WALL_SOURCE_ID
			)
			wall_layer.set_cell(c, source, atlas_coords, data[2])

# Instantiates the roommate scene on a route of cells and forwards his result.
func add_roommate(route: Array[Vector2i]) -> Node2D:
	debug_path = route
	if roommate_path_overlay != null:
		roommate_path_overlay.set_cells(route)
	var r := ROOMMATE_SCENE.instantiate()
	r.z_index = 10
	r.z_as_relative = false
	add_child(r)
	r.call("setup", self, route)
	r.connect("won", func(): level_won.emit())
	r.connect("lost", func(reason: String): level_lost.emit(reason))
	roommate = r
	return r

# ---------- editor-authored roommate path (Path2D) ----------

# Reads a Path2D's curve points, snaps each to a grid cell, and returns the
# route as cells. Draw the path visually in the editor by adding a Path2D node
# (default name "RoommatePath") and dropping points on it, instead of
# hardcoding a route array.
#
# Returns an empty array if the node is missing or has fewer than 2 points, so
# the caller can fall back to a hardcoded route if desired.
func route_from_path2d(path_node_name := "RoommatePath") -> Array[Vector2i]:
	var path := get_node_or_null(path_node_name) as Path2D
	var cells: Array[Vector2i] = []
	if path == null or path.curve == null:
		push_warning("route_from_path2d: no Path2D named '%s'" % path_node_name)
		return cells
	var curve := path.curve
	for i in range(curve.point_count):
		# Curve points are local to the Path2D. Apply the node's full transform
		# (position, scale, rotation) so a point lands on the same world cell the
		# editor renders it at.
		var world := path.transform * curve.get_point_position(i)
		var cell := Grid.pos_to_cell(world)
		# Skip accidental duplicates (two points landing on the same cell).
		if cells.is_empty() or cells[cells.size() - 1] != cell:
			cells.append(cell)
	if cells.size() < 2:
		push_warning("route_from_path2d: '%s' needs at least 2 points on distinct cells" % path_node_name)
	return cells

# Convenience: build the route from an editor Path2D and spawn the roommate on
# it, mirroring hardcoded `add_roommate(route)`. Also stores the cells in
# debug_path so the base _draw() still renders the route line for debugging.
func add_roommate_from_path(path_node_name := "RoommatePath") -> Node2D:
	var cells := route_from_path2d(path_node_name)
	debug_path = cells
	if roommate_path_overlay != null:
		roommate_path_overlay.set_cells(cells)
	queue_redraw()
	if cells.size() < 2:
		return null
	return add_roommate(cells)

# ---------- debug drawing ----------

func _draw() -> void:
	if debug_grid:
		var field_size := Vector2(
			Grid.FIELD_COLS * Grid.CELL,
			Grid.FIELD_ROWS * Grid.CELL
		)
		var grid_color := Color(1.0, 1.0, 1.0, 0.16)
		for column in range(Grid.FIELD_COLS + 1):
			var x := float(column * Grid.CELL)
			draw_line(Vector2(x, 0.0), Vector2(x, field_size.y), grid_color)
		for row in range(Grid.FIELD_ROWS + 1):
			var y := float(row * Grid.CELL)
			draw_line(Vector2(0.0, y), Vector2(field_size.x, y), grid_color)
