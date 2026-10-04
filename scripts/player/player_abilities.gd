extends "res://scripts/player/player_interactions.gd"

const FALL_DROP_CELLS := 2.0
const FALL_OUT_TIME := 0.35
const FALL_IN_TIME := 0.45
const FALL_SPIN := TAU * 1.0
const ARROW_SCENE := preload("res://scenes/objects/archery/arrow.tscn")
const SHOOT_COOLDOWN := 0.3

enum FallPhase { NONE, OUT, IN }
enum FallEdge { VOID, TOP, FRONT, SIDE }

var has_bow := false
var aiming := false
var aim_dir := Vector2.RIGHT
var shoot_cd := 0.0
var fall_phase := FallPhase.NONE
var fall_edge := FallEdge.VOID
var fall_t := 0.0
var fall_from := Vector2.ZERO
var land_target := Vector2.ZERO
var last_ground_position := Vector2.ZERO
var draw_spin := 0.0
var draw_scale := 1.0
var draw_alpha := 1.0

func _begin_fall() -> void:
	fall_edge = _detect_fall_edge(position - last_ground_position) as FallEdge
	falling = true
	fall_phase = FallPhase.OUT
	fall_t = 0.0
	fall_from = position
	land_target = level.closest_dream_floor(position)
	draw_spin = 0.0
	draw_scale = 1.0
	draw_alpha = 1.0
	push_target = null
	push_timer = 0.0
	interact_locked = false

func _detect_fall_edge(movement_from_ground: Vector2) -> int:
	if absf(movement_from_ground.y) >= absf(movement_from_ground.x):
		if movement_from_ground.y < 0.0:
			return FallEdge.TOP
		if movement_from_ground.y > 0.0:
			return FallEdge.FRONT
	elif movement_from_ground.x != 0.0:
		return FallEdge.SIDE
	return FallEdge.VOID

func _record_ground_position() -> void:
	if (
		not falling
		and level != null
		and level.realm == LevelBase.Realm.DREAM
		and level.is_dream_floor(Grid.pos_to_cell(position))
	):
		last_ground_position = position

func _end_fall() -> void:
	falling = false
	fall_phase = FallPhase.NONE
	draw_spin = 0.0
	draw_scale = 1.0
	draw_alpha = 1.0

func _update_fall(delta: float) -> void:
	match fall_phase:
		FallPhase.OUT:
			fall_t += delta / FALL_OUT_TIME
			var t := clampf(fall_t, 0.0, 1.0)
			position.y = fall_from.y + FALL_DROP_CELLS * Grid.CELL * t
			draw_spin = FALL_SPIN * t
			draw_scale = 1.0 - t
			draw_alpha = 1.0 - t
			if t >= 1.0:
				fall_phase = FallPhase.IN
				fall_t = 0.0
				fall_from = Vector2(land_target.x, -SIZE)
				position = fall_from
				_on_fall_return_started()
		FallPhase.IN:
			fall_t += delta / FALL_IN_TIME
			var t := clampf(fall_t, 0.0, 1.0)
			position.x = land_target.x
			position.y = lerpf(fall_from.y, land_target.y, t)
			draw_spin = FALL_SPIN * t
			draw_scale = t
			draw_alpha = t
			if t >= 1.0:
				position = land_target
				_end_fall()
		_:
			_end_fall()

func _on_fall_return_started() -> void:
	pass

func _update_bow() -> bool:
	if Input.is_action_pressed("interact"):
		var steer := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if steer.length() > 0.1:
			if absf(steer.x) >= absf(steer.y):
				aim_dir = Vector2(signf(steer.x), 0)
			else:
				aim_dir = Vector2(0, signf(steer.y))
		aiming = true
		push_target = null
		push_timer = 0.0
		return true
	if aiming:
		aiming = false
		if shoot_cd <= 0.0:
			_fire_arrow()
			shoot_cd = SHOOT_COOLDOWN
		return true
	return false

func _fire_arrow() -> void:
	var arrow := ARROW_SCENE.instantiate()
	arrow.position = position + aim_dir * (SIZE * 0.5 + 2.0)
	level.add_child(arrow)
	arrow.call("setup", level, aim_dir)
