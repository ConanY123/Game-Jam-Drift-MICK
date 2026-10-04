class_name EnergyDrink
extends Pushable

# A dream-only pickup. Tap interact next to it and your stamina is maxed out.
#
# - Place ONE of these under the level (e.g. under the "Dream" node). By
#   default, where you drag it in the editor does not matter: it picks its own
#   spot. Enable `fixed_position` to keep the authored position instead.
# - It does not exist until you enter the dream. On entering, if it is not
#   already out, it appears on a random painted dream-floor tile.
# - Leaving and re-entering the dream leaves it where it was (unless that spot
#   has become blocked in the meantime, then it picks a new one).
# - Once used it disappears, and a new one appears in a new random spot the
#   next time you enter the dream.
# - It is registered only in the dream map, so it can't be seen or touched in
#   the physical realm. It extends Pushable (like Door does) so the player's
#   existing interact pipeline and Z hint bubble work with no player changes.
#
# Keep `realm` on Dream and `holdable` off (the scene already does this).

@export var random_seed := 0  # 0 = different every run, any other number = repeatable
@export var route_buffer := 0  # extra cells of space to keep around the roommate's path
@export var avoid_blocking_paths := true  # never drop it where it would wall off part of the floor
@export var fixed_position := false  # keep the authored dream-world position; no respawn after use

const NO_CELL := Vector2i(-9999, -9999)
const NEIGHBORS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var _active := false
var _rng := RandomNumberGenerator.new()


func setup(p_level: LevelBase, p_cell: Vector2i) -> void:
	realm = LevelBase.Realm.DREAM
	super.setup(p_level, p_cell)
	if fixed_position:
		_active = true
		level.realm_changed.connect(_on_realm_changed)
		_refresh()
		return
	# Pushable.setup registered the editor position. We don't exist yet.
	level.unregister(self, realm)
	_active = false
	if random_seed != 0:
		_rng.seed = random_seed
	else:
		_rng.randomize()
	level.realm_changed.connect(_on_realm_changed)
	_refresh()


func _on_realm_changed(new_realm: int) -> void:
	if fixed_position:
		_refresh()
		return
	if new_realm != LevelBase.Realm.DREAM or level.player == null:
		return
	if _active and not _spot_is_still_good():
		_remove()
	if not _active:
		_spawn()


# ---------- interaction (same pipeline as Door) ----------

# One tap is enough: the player's mash timer adds 0.12 per press.
func hold_time() -> float:
	return 0.01


func can_push(_dir: Vector2i) -> bool:
	return false  # it never slides


func can_interact(_dir: Vector2i) -> bool:
	return _active and level != null


func try_push(dir: Vector2i) -> bool:
	if not can_interact(dir):
		return false
	var p := level.player
	if p != null:
		p.stamina = p.MAX_STAMINA
		p.stamina_changed.emit(1.0)
	_remove()
	return true


# ---------- showing / hiding ----------

func _refresh() -> void:
	visible = _active and level != null and level.realm == realm
	queue_redraw()


func _place(c: Vector2i) -> void:
	cell = c
	position = Grid.cell_to_pos(c)
	level.register(self, get_cells(c), realm)
	_active = true
	_refresh()


func _remove() -> void:
	level.unregister(self, realm)
	_active = false
	_refresh()


# ---------- choosing a spot ----------

func _spawn() -> void:
	var start := _player_start_cell()
	var reach := _reachable(start, NO_CELL)
	var preferred_candidates: Array[Vector2i] = []
	var remaining_candidates: Array[Vector2i] = []
	_collect_candidates(start, reach, _banned_cells(), preferred_candidates, remaining_candidates)

	if _try_spawn_from_candidates(preferred_candidates, start, reach, avoid_blocking_paths):
		return
	if _try_spawn_from_candidates(remaining_candidates, start, reach, avoid_blocking_paths):
		return
	if avoid_blocking_paths:
		if _try_spawn_from_candidates(preferred_candidates, start, reach, false):
			return
		if _try_spawn_from_candidates(remaining_candidates, start, reach, false):
			return

	preferred_candidates.clear()
	remaining_candidates.clear()
	_collect_candidates(start, reach, {}, preferred_candidates, remaining_candidates)
	if _try_spawn_from_candidates(preferred_candidates, start, reach, avoid_blocking_paths):
		push_warning("EnergyDrink: using a reserved roommate-route tile because no safer spot was available.")
		return
	if _try_spawn_from_candidates(remaining_candidates, start, reach, avoid_blocking_paths):
		push_warning("EnergyDrink: using a reserved roommate-route tile because no safer spot was available.")
		return
	if avoid_blocking_paths:
		if _try_spawn_from_candidates(preferred_candidates, start, reach, false):
			push_warning("EnergyDrink: using a reserved roommate-route tile because no safer spot was available.")
			return
		if _try_spawn_from_candidates(remaining_candidates, start, reach, false):
			push_warning("EnergyDrink: using a reserved roommate-route tile because no safer spot was available.")
			return
	push_warning("EnergyDrink: no valid spot found on the dream floor.")


func _collect_candidates(
	start: Vector2i,
	reach: Dictionary,
	banned: Dictionary,
	preferred_candidates: Array[Vector2i],
	remaining_candidates: Array[Vector2i]
) -> void:
	for c: Vector2i in level.dream_floor.keys():
		if c == start or banned.has(c) or _player_overlaps(c):
			continue
		var physical_blocker := level.blocker_at(c, LevelBase.Realm.PHYSICAL)
		if physical_blocker != null and not (
			level.realm == LevelBase.Realm.DREAM and physical_blocker is Goose
		):
			continue
		if level.blocker_at(c, LevelBase.Realm.DREAM) != null:
			continue
		if _touches(c, reach):
			var distance := absi(c.x - start.x) + absi(c.y - start.y)
			if distance >= 2 and distance <= 4:
				preferred_candidates.append(c)
			else:
				remaining_candidates.append(c)

func _try_spawn_from_candidates(
	candidates: Array[Vector2i],
	start: Vector2i,
	reach: Dictionary,
	preserve_paths: bool
) -> bool:
	var remaining: Array[Vector2i] = candidates.duplicate()
	while not remaining.is_empty():
		var i := _rng.randi_range(0, remaining.size() - 1)
		var pick := remaining[i]
		remaining.remove_at(i)
		var without := _reachable(start, pick)
		if not _touches(pick, without):
			continue
		if preserve_paths:
			var lost := reach.size() - without.size() - (1 if reach.has(pick) else 0)
			if lost > 0:
				continue
		_place(pick)
		return true
	return false


# When we come back to a drink that is already out: is it still usable?
func _spot_is_still_good() -> bool:
	var start := _player_start_cell()
	if start == cell or _player_overlaps(cell):
		return false
	var physical_blocker := level.blocker_at(cell, LevelBase.Realm.PHYSICAL)
	if physical_blocker != null and not (
		level.realm == LevelBase.Realm.DREAM and physical_blocker is Goose
	):
		return false
	return _touches(cell, _reachable(start, cell))


# Cells the drink should stay off: the roommate's route.
func _banned_cells() -> Dictionary:
	var banned := {}
	for c in _route_cells():
		for dx in range(-route_buffer, route_buffer + 1):
			for dy in range(-route_buffer, route_buffer + 1):
				banned[c + Vector2i(dx, dy)] = true
	return banned


# Every cell the roommate's center passes through on his way along the route.
func _route_cells() -> Array[Vector2i]:
	var route: Array = level.debug_path
	var rm := level.roommate as Roommate
	if rm != null and not rm.route.is_empty():
		route = rm.route
	var cells: Array[Vector2i] = []
	for i in route.size():
		var a := Grid.cell_to_center(route[i])
		var b := a
		if i + 1 < route.size():
			b = Grid.cell_to_center(route[i + 1])
		var steps := maxi(ceili(a.distance_to(b) / (Grid.CELL * 0.25)), 1)
		for s in range(steps + 1):
			cells.append(Grid.pos_to_cell(a.lerp(b, float(s) / steps)))
	return cells


# ---------- walking checks for the player (in the dream) ----------

# Where the player will be standing once they arrive in the dream.
func _player_start_cell() -> Vector2i:
	var p := level.player
	var c := Grid.pos_to_cell(p.position)
	if level.dream_floor.has(c):
		return c
	return Grid.pos_to_cell(level.closest_dream_floor(p.position))


func _player_overlaps(c: Vector2i) -> bool:
	var p := level.player
	if p == null:
		return false
	var hitbox := Vector2(p.HITBOX_SIZE, p.HITBOX_SIZE)
	var player_rect := Rect2(p.position - hitbox / 2.0, hitbox)
	var cell_rect := Rect2(Grid.cell_to_pos(c), Vector2(Grid.CELL, Grid.CELL))
	return player_rect.intersects(cell_rect)


# Can the player stand here? Needs painted floor, nothing physical in the way,
# and no solid dream object. Dream pieces don't count: the player walks through them.
func _walkable(c: Vector2i, blocked: Vector2i) -> bool:
	if c == blocked or not level.dream_floor.has(c):
		return false
	var physical_blocker := level.blocker_at(c, LevelBase.Realm.PHYSICAL)
	if physical_blocker != null and not (
		level.realm == LevelBase.Realm.DREAM and physical_blocker is Goose
	):
		return false
	var b := level.blocker_at(c, LevelBase.Realm.DREAM)
	if b == null:
		return true
	return b is Pushable and b != self


# Every cell the player can walk to from `start`, treating `blocked` as a wall.
func _reachable(start: Vector2i, blocked: Vector2i) -> Dictionary:
	var seen := {}
	if not _walkable(start, blocked):
		return seen
	var queue: Array[Vector2i] = [start]
	seen[start] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in NEIGHBORS:
			var n := c + d
			if not seen.has(n) and _walkable(n, blocked):
				seen[n] = true
				queue.append(n)
	return seen


# Is at least one neighbouring cell somewhere the player can stand?
func _touches(c: Vector2i, reach: Dictionary) -> bool:
	for d: Vector2i in NEIGHBORS:
		if reach.has(c + d):
			return true
	return false
