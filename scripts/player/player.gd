class_name Player
extends "res://scripts/player/player_abilities.gd"

func _ready() -> void:
	_setup_input()
	if level != null:
		level.realm_changed.connect(_on_realm_changed)

func _on_realm_changed(new_realm: int) -> void:
	if falling and new_realm == LevelBase.Realm.PHYSICAL:
		_end_fall()

func _physics_process(delta: float) -> void:
	if level == null:
		return
	_update_interaction_hint(delta)
	if level.gameplay_locked():
		_nearby_interactable = null
		return
	_recover_stamina(delta)

	if falling:
		_update_fall(delta)
		queue_redraw()
		return

	if level.player_over_dream_gap():
		_begin_fall()
		queue_redraw()
		return

	if shoot_cd > 0.0:
		shoot_cd -= delta
	if interact_locked and not Input.is_action_pressed("interact"):
		interact_locked = false

	if (
		not interact_locked
		and has_bow
		and (aiming or (push_target == null and not _pressing_into_pushable()))
	):
		if _update_bow():
			queue_redraw()
			return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length_squared() > 0.0:
		if absf(input.x) > absf(input.y):
			_facing_dir = Vector2i(int(signf(input.x)), 0)
		else:
			_facing_dir = Vector2i(0, int(signf(input.y)))
	var step := input * SPEED * delta
	var position_before_move := position

	var hit_x := _move_axis(Vector2(step.x, 0))
	var hit_y := _move_axis(Vector2(0, step.y))

	var target: Pushable
	var direction := Vector2i.ZERO
	if hit_x is Pushable:
		target = hit_x
		direction = Vector2i(int(signf(step.x)), 0)
	if hit_y is Pushable:
		target = hit_y
		direction = Vector2i(0, int(signf(step.y)))
	if target == null and input == Vector2.ZERO and push_target != null:
		target = push_target
		direction = push_dir
	_update_push(target, direction, delta)
	if position != position_before_move:
		has_moved = true
	queue_redraw()

func _draw() -> void:
	var half := SIZE / 2.0
	var body := Color(0.35, 0.8, 1.0)
	if falling:
		draw_set_transform(Vector2.ZERO, draw_spin, Vector2(draw_scale, draw_scale))
		body.a = draw_alpha
	draw_rect(Rect2(-half, -half, SIZE, SIZE), body)
	if falling:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if push_target != null:
		var progress := clampf(push_timer / push_target.hold_time(), 0.0, 1.0)
		draw_rect(Rect2(-half, -half - 8, SIZE * progress, 3), Color.WHITE)

	if _interaction_hint_progress > 0.0:
		_draw_interaction_hint(half)

	if has_bow:
		var reach := SIZE * 0.9
		var tip := aim_dir * reach
		var color := Color(0.95, 0.9, 0.6, 1.0 if aiming else 0.4)
		draw_line(Vector2.ZERO, tip, color, 2.0 if aiming else 1.0)
		draw_circle(tip, 2.5, color)

func _draw_interaction_hint(half: float) -> void:
	var pressed := (
		not _interaction_hint_holdable
		and fposmod(_interaction_hint_time, 0.3) < 0.06
	)
	var center_y := -half - 27.0
	center_y += lerpf(9.0, 0.0, _interaction_hint_progress)
	if pressed:
		center_y += 2.5
	var center := Vector2(0.0, center_y)
	var radius := 10.0
	draw_circle(
		center,
		radius,
		Color(0.08, 0.07, 0.13, 0.94 * _interaction_hint_progress)
	)
	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		32,
		Color(1.0, 1.0, 1.0, 0.95 * _interaction_hint_progress),
		1.5,
		true
	)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-radius, center.y + 5.0),
		"Z",
		HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0,
		13,
		Color(1.0, 1.0, 1.0, _interaction_hint_progress)
	)
