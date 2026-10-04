extends "res://scripts/player/player_state.gd"

const INTERACTION_HINT_IN_SPEED := 7.0
const INTERACTION_HINT_OUT_SPEED := 9.0

signal stamina_changed(fraction: float)

var push_target: Pushable
var push_dir := Vector2i.ZERO
var push_timer := 0.0
var interact_locked := false
var _nearby_interactable: Pushable
var _nearby_interactable_dir := Vector2i.ZERO
var _nearby_signal_source: Node
var _interaction_hint_time := 0.0
var _facing_dir := Vector2i.DOWN
var _interaction_hint_progress := 0.0
var _interaction_hint_holdable := true

func _update_push(target: Pushable, dir: Vector2i, delta: float) -> void:
	if interact_locked:
		push_timer = 0.0
		return

	if (
		target != null
		and target.realm != level.realm
		and not target.interactable_in_any_realm()
	):
		target = null
	if target != null and not target.can_interact(dir):
		if target != push_target:
			push_target = null
		push_timer = 0.0
		return
	if target == null:
		push_target = null
		push_timer = 0.0
		return
	if target != push_target or dir != push_dir:
		push_target = target
		push_dir = dir
		push_timer = 0.0

	if target.holdable:
		if not Input.is_action_pressed("interact"):
			push_timer = 0.0
			return
		push_timer += delta
	elif Input.is_action_just_pressed("interact"):
		push_timer += MASH_GAIN
	else:
		var proportional := minf(push_timer / target.hold_time(), 0.9)
		push_timer = maxf(push_timer - delta * MASH_DECAY * proportional, 0.0)

	if push_timer >= target.hold_time():
		push_timer = 0.0
		if target.try_push(dir):
			interact_locked = true
			if level.realm == LevelBase.Realm.PHYSICAL:
				_spend_stamina(target.weight)
			elif target.realm == LevelBase.Realm.DREAM:
				_restore_stamina(target.weight * 2.0)

func _spend_stamina(amount: float) -> void:
	stamina = clampf(stamina - amount, 0.0, MAX_STAMINA)
	stamina_changed.emit(stamina / MAX_STAMINA)
	if is_zero_approx(stamina) and level.realm == LevelBase.Realm.PHYSICAL:
		level.switch_realm()

func drain_stamina(amount: float) -> void:
	if is_zero_approx(stamina):
		return
	_spend_stamina(amount)

func _restore_stamina(amount: float) -> void:
	stamina = clampf(stamina + amount, 0.0, MAX_STAMINA)
	stamina_changed.emit(stamina / MAX_STAMINA)

func _recover_stamina(delta: float) -> void:
	if level.realm != LevelBase.Realm.DREAM or stamina >= MAX_STAMINA:
		return
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var recovery_multiplier := (
		MOVING_STAMINA_REGEN_MULTIPLIER
		if movement.length_squared() > 0.0
		else 1.0
	)
	stamina = minf(
		stamina + DREAM_STAMINA_REGEN * recovery_multiplier * delta,
		MAX_STAMINA
	)
	stamina_changed.emit(stamina / MAX_STAMINA)

func can_switch_to_physical() -> bool:
	return stamina >= MAX_STAMINA * PHYSICAL_RETURN_STAMINA_FRACTION

func _pressing_into_pushable() -> bool:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() < 0.1:
		return false
	var probe := SPEED * 0.05
	for offset in [
		Vector2(signf(input.x) * probe, 0),
		Vector2(0, signf(input.y) * probe),
	]:
		if offset == Vector2.ZERO:
			continue
		var blocker := _blocker_in(position + offset, level.realm)
		if blocker is Pushable and blocker.realm == level.realm:
			return true
	return false

func _update_interaction_hint(delta: float) -> void:
	_interaction_hint_time += delta
	_nearby_interactable = null
	_nearby_interactable_dir = Vector2i.ZERO
	_nearby_signal_source = null
	var reach := SIZE * 0.5 + 1.0
	var facing := _facing_dir
	var clockwise := Vector2i(-facing.y, facing.x)
	var directions: Array[Vector2i] = [
		facing,
		clockwise,
		-clockwise,
		-facing,
	]
	if not level.gameplay_locked() and not falling:
		for direction in directions:
			var offset := Vector2(direction) * reach
			var candidate := _blocker_in(position + offset, level.realm)
			if direction == facing and candidate != null:
				if (
					candidate is Pushable
					and candidate.realm == level.realm
					and candidate.can_interact(direction)
				):
					_nearby_interactable = candidate
					_nearby_interactable_dir = direction
					_interaction_hint_holdable = candidate.holdable
				break
			if (
				candidate is Pushable
				and candidate.realm == level.realm
				and candidate.can_interact(direction)
			):
				_nearby_interactable = candidate
				_nearby_interactable_dir = direction
				_interaction_hint_holdable = candidate.holdable
				break

		if _nearby_interactable == null:
			var player_cell := Grid.pos_to_cell(position)
			for direction in directions:
				var probe := position + Vector2(direction) * reach
				if _blocker_in(probe, level.realm) != null:
					continue
				var adjacent_cell := player_cell + direction
				for source: Node in get_tree().get_nodes_in_group("signal_sources"):
					if (
						source.get("manually_toggleable") == true
						and bool(source.call("can_interact_in_realm", level.realm))
						and Grid.pos_to_cell(level.to_local(source.global_position)) == adjacent_cell
					):
						_nearby_signal_source = source
						_interaction_hint_holdable = false
						break
				if _nearby_signal_source != null:
					break

	var target_progress := (
		1.0
		if _nearby_interactable != null or _nearby_signal_source != null
		else 0.0
	)
	var animation_speed := (
		INTERACTION_HINT_IN_SPEED
		if target_progress > _interaction_hint_progress
		else INTERACTION_HINT_OUT_SPEED
	)
	_interaction_hint_progress = move_toward(
		_interaction_hint_progress,
		target_progress,
		animation_speed * delta
	)
	if _interaction_hint_progress > 0.0 or target_progress > 0.0:
		queue_redraw()
