extends Node2D

const SIZE := 24.0
const SPEED := 96.0
const MASH_GAIN := 0.12
const MASH_DECAY := 0.5
const MAX_STAMINA := 7.0
const DREAM_STAMINA_REGEN := 1.0
const MOVING_STAMINA_REGEN_MULTIPLIER := 0.5
const PHYSICAL_RETURN_STAMINA_FRACTION := 0.25

var level: LevelBase
var stamina := MAX_STAMINA
var has_moved := false
var falling := false

func _move_axis(offset: Vector2) -> Node:
	if offset == Vector2.ZERO:
		return null
	var blocker := _blocker_at(position + offset)
	if blocker == null or _is_traversable_dream_block(blocker):
		position += offset
	return blocker

func _is_traversable_dream_block(blocker: Node) -> bool:
	return (
		level.realm == LevelBase.Realm.DREAM
		and blocker is Pushable
		and blocker.realm == LevelBase.Realm.DREAM
	)

func _blocker_at(center: Vector2) -> Node:
	var blocker: Node = _blocker_in(center, level.realm)
	if blocker == null and level.realm == LevelBase.Realm.DREAM:
		blocker = _blocker_in(center, LevelBase.Realm.PHYSICAL)
	return blocker

func _blocker_in(center: Vector2, in_realm: int) -> Node:
	var half := Vector2(SIZE, SIZE) / 2.0
	var min_cell := Grid.pos_to_cell(center - half)
	var max_cell := Grid.pos_to_cell(center + half - Vector2(0.01, 0.01))
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var blocker := level.blocker_at(Vector2i(x, y), in_realm)
			if blocker != null:
				return blocker
	return null

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
