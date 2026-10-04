extends Node2D

const SIZE := 24.0
const HITBOX_SIZE := 18.0
const HITBOX_RADIUS := HITBOX_SIZE * 0.5
const GOOSE_PUSH_REACH_EXTRA := 16.0
const SPEED := 96.0
const MASH_GAIN := 0.12
const MASH_DECAY := 0.5
const MAX_STAMINA := 7.0
const DREAM_STAMINA_REGEN := 0.0
const MOVING_STAMINA_REGEN_MULTIPLIER := 0.5
const PHYSICAL_RETURN_STAMINA_FRACTION := 0.35

var level: LevelBase
var stamina := MAX_STAMINA
var has_moved := false
var falling := false

func _move_axis(offset: Vector2) -> Node:
	if offset == Vector2.ZERO:
		return null
	var next_position := position + offset
	var blocker := _blocker_at(next_position)
	if blocker == null:
		blocker = _goose_in_push_range(next_position, offset)
	if blocker == null or _is_traversable_dream_block(blocker):
		position += offset
	return blocker

func _goose_in_push_range(center: Vector2, movement: Vector2) -> Goose:
	if level.realm == LevelBase.Realm.DREAM:
		return null
	var realms: Array[int] = [level.realm]
	var checked: Dictionary = {}
	for in_realm in realms:
		for blocker in level.solids[in_realm].values():
			if not blocker is Goose or checked.has(blocker):
				continue
			checked[blocker] = true
			var goose := blocker as Goose
			var goose_center := (
				level.to_local(goose.global_position)
				+ Vector2.ONE * (Grid.CELL * 0.5)
			)
			if movement.dot(goose_center - position) <= 0.0:
				continue
			if goose.overlaps_player_circle(
				center,
				HITBOX_RADIUS + GOOSE_PUSH_REACH_EXTRA
			):
				return goose
	return null

func _is_traversable_dream_block(blocker: Node) -> bool:
	return (
		level.realm == LevelBase.Realm.DREAM
		and blocker is Pushable
		and blocker.realm == LevelBase.Realm.DREAM
		and not (blocker is EnergyDrink)
	)

func _blocker_at(center: Vector2) -> Node:
	var blocker: Node = _blocker_in(center, level.realm)
	if blocker == null and level.realm == LevelBase.Realm.DREAM:
		blocker = _blocker_in(center, LevelBase.Realm.PHYSICAL)
	return blocker

func _blocker_in(center: Vector2, in_realm: int) -> Node:
	var search_radius := HITBOX_RADIUS + Goose.HITBOX_RADIUS
	var half := Vector2.ONE * search_radius
	var min_cell := Grid.pos_to_cell(center - half)
	var max_cell := Grid.pos_to_cell(center + half - Vector2(0.01, 0.01))
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell := Vector2i(x, y)
			var blocker := level.blocker_at(cell, in_realm)
			if blocker != null:
				if blocker is Goose:
					if level.realm == LevelBase.Realm.DREAM:
						continue
					if not blocker.overlaps_player_circle(center, HITBOX_RADIUS):
						continue
				elif blocker is Door:
					if not blocker.overlaps_player_circle(
						center,
						HITBOX_RADIUS
					):
						continue
				elif not _circle_overlaps_cell(center, cell):
					continue
				return blocker
	return null

func _circle_overlaps_cell(center: Vector2, cell: Vector2i) -> bool:
	var cell_origin := Vector2(Grid.cell_to_pos(cell))
	var closest_point := center.clamp(
		cell_origin,
		cell_origin + Vector2.ONE * Grid.CELL
	)
	return center.distance_squared_to(closest_point) < HITBOX_RADIUS * HITBOX_RADIUS

func is_overlapping(in_realm: int) -> bool:
	return _blocker_in(position, in_realm) != null

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
			continue
		InputMap.add_action(action)
		for key in map[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
