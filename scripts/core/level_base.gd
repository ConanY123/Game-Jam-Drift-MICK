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
const DOOR_SCENE := preload("res://scenes/objects/door.tscn")

var realm := Realm.PHYSICAL
var roommate: Roommate

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
	build()
	var overlay: ResultOverlay = RESULT_OVERLAY_SCENE.instantiate()
	add_child(overlay)
	overlay.setup(self)
	queue_redraw()

func build() -> void:
	pass  # levels override this

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
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
	add_child(p)
	p.setup(self, cell)
	return p

func add_door(cell: Vector2i, size := Vector2i(1, 1), start_open := false, color := Color(0.55, 0.4, 0.3), in_realm: int = Realm.PHYSICAL) -> Door:
	var d: Door = DOOR_SCENE.instantiate()
	d.size = size
	d.color = color
	d.realm = in_realm
	add_child(d)
	d.setup(self, cell, start_open)
	return d

func add_player(cell: Vector2i) -> Player:
	var p := Player.new()
	p.level = self
	p.position = Grid.cell_to_center(cell)
	player = p
	add_child(p)
	return p

# Instantiates the roommate scene on a route of cells and forwards his result.
func add_roommate(route: Array[Vector2i]) -> Roommate:
	var r: Roommate = ROOMMATE_SCENE.instantiate()
	add_child(r)
	r.setup(self, route)
	r.won.connect(func(): level_won.emit())
	r.lost.connect(func(reason: String): level_lost.emit(reason))
	roommate = r
	return r

# ---------- debug drawing ----------

func _draw() -> void:
	var field := Vector2(Grid.FIELD_COLS, Grid.FIELD_ROWS) * Grid.CELL

	var bg := Color(0.1, 0.12, 0.2)
	if realm == Realm.DREAM:
		bg = Color(0.05, 0.03, 0.1)  # void
	draw_rect(Rect2(Vector2.ZERO, field), bg)
	if realm == Realm.DREAM:
		for c in dream_floor:
			draw_rect(Rect2(Grid.cell_to_pos(c), Vector2(Grid.CELL, Grid.CELL)), Color(0.55, 0.4, 0.7))

	draw_rect(Rect2(Vector2(field.x, 0), Vector2(Grid.STRIP_COLS * Grid.CELL, field.y)), Color(0.06, 0.06, 0.1))
	for r in wall_rects:
		draw_rect(Rect2(Vector2(r.position * Grid.CELL), Vector2(r.size * Grid.CELL)), Color(0.35, 0.37, 0.45))
	if debug_grid:
		var line_color := Color(1, 1, 1, 0.12)
		for x in Grid.FIELD_COLS + 1:
			draw_line(Vector2(x, 0) * Grid.CELL, Vector2(x, Grid.FIELD_ROWS) * Grid.CELL, line_color)
		for y in Grid.FIELD_ROWS + 1:
			draw_line(Vector2(0, y) * Grid.CELL, Vector2(Grid.FIELD_COLS, y) * Grid.CELL, line_color)
	if debug_path.size() > 1:
		var pts := PackedVector2Array()
		for c in debug_path:
			pts.append(Grid.cell_to_center(c))
		draw_polyline(pts, Color(1, 1, 1, 0.5), 2.0)