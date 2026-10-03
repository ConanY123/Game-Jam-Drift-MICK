class_name LevelBase
extends Node2D

# Base for every level. Owns the occupancy map and draws the debug grid.
# A level script extends this and overrides build().

@export var debug_grid := true

enum Realm { 
	PHYSICAL, 
	DREAM 
}
signal realm_changed(new_realm: Realm)
signal level_won
signal level_lost(reason: String)

const ROOMMATE_SCENE := preload("res://scenes/actors/roommate.tscn")
const RESULT_OVERLAY_SCENE := preload("res://scenes/ui/result_overlay.tscn")

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
	build()
	_update_layers()
	realm_changed.connect(func(_r): _update_layers())
	var overlay := RESULT_OVERLAY_SCENE.instantiate()
	add_child(overlay)
	overlay.call("setup", self)
	queue_redraw()

func build() -> void:
	pass  # levels override this

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		AudioManager.play_level_music()
		get_tree().reload_current_scene()
	elif event.is_action_pressed("switch_realm"):
		switch_realm()

func switch_realm() -> void:
	realm = Realm.DREAM if realm == Realm.PHYSICAL else Realm.PHYSICAL
	realm_changed.emit(realm)
	queue_redraw()

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

func add_player(cell: Vector2i) -> Player:
	var p := Player.new()
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
	var dream := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream != null:
		for c in dream.get_used_cells():
			dream_floor[c] = true

func _update_layers() -> void:
	var floor_layer := get_node_or_null("FloorLayer") as TileMapLayer
	if floor_layer != null:
		floor_layer.visible = realm == Realm.PHYSICAL
	var dream_layer := get_node_or_null("DreamFloorLayer") as TileMapLayer
	if dream_layer != null:
		dream_layer.visible = realm == Realm.DREAM
# Instantiates the roommate scene on a route of cells and forwards his result.
func add_roommate(route: Array[Vector2i]) -> Node2D:
	var r := ROOMMATE_SCENE.instantiate()
	add_child(r)
	r.call("setup", self, route)
	r.connect("won", func(): level_won.emit())
	r.connect("lost", func(reason: String): level_lost.emit(reason))
	roommate = r
	return r

# ---------- debug drawing ----------

func _draw() -> void:
	if debug_path.size() < 2:
		return
	var points := PackedVector2Array()
	for cell in debug_path:
		points.append(Grid.cell_to_center(cell))
	draw_polyline(points, Color(1.0, 1.0, 1.0, 0.8), 3.0, true)
	for point in points:
		draw_circle(point, 4.0, Color(1.0, 0.9, 0.3, 0.95))
