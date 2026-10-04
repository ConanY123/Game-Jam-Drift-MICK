class_name Computer
extends "res://scripts/objects/outputs/signal_output.gd"

const FOOTPRINT := Vector2i.ONE
const AURA_SIZE := Vector2i(3, 2)
const ROOMMATE_SIZE := Vector2(20.0, 20.0)
const AURA_DEATH_REASON := "was caught in a computer's signal"

@export_range(0, 270, 90) var aura_rotation_degrees := 0
@export var start_on := false
@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	size = FOOTPRINT
	initially_powered = start_on
	super._ready()
	level.realm_changed.connect(_on_level_realm_changed)
	_update_sprite()

func _on_power_changed(_is_powered: bool) -> void:
	_update_sprite()
	queue_redraw()

func _on_level_realm_changed(_new_realm: int) -> void:
	_update_sprite()

func _update_sprite() -> void:
	if not is_node_ready():
		return
	var direction := posmod(aura_rotation_degrees, 360)
	var aura_showing := _is_aura_showing()
	var frame_index: int
	match direction:
		90, 270:
			frame_index = 2 if aura_showing else 3
		_:
			frame_index = 1 if aura_showing else 0
	_sprite.region_rect.position.x = float(frame_index * Grid.CELL)
	_sprite.flip_h = direction == 90

func _is_aura_showing() -> bool:
	return powered and level != null and not (
		level.realm != realm and realm == LevelBase.Realm.DREAM
	)

func _physics_process(_delta: float) -> void:
	if not powered or level == null or level.roommate == null:
		return
	if not level.roommate.has_method("kill"):
		return
	var roommate_position := to_local(level.roommate.global_position)
	var roommate_rect := Rect2(
		roommate_position - ROOMMATE_SIZE * 0.5,
		ROOMMATE_SIZE
	)
	if _aura_rect().intersects(roommate_rect):
		level.roommate.call("kill", AURA_DEATH_REASON)

func _aura_rect() -> Rect2:
	var footprint_pixels := Vector2(size * Grid.CELL)
	var aura_size := Vector2(AURA_SIZE * Grid.CELL)
	match posmod(aura_rotation_degrees, 360):
		0:
			return Rect2(
				Vector2((footprint_pixels.x - aura_size.x) * 0.5, -aura_size.y),
				aura_size
			)
		90:
			return Rect2(
				Vector2(footprint_pixels.x, (footprint_pixels.y - aura_size.x) * 0.5),
				Vector2(aura_size.y, aura_size.x)
			)
		180:
			return Rect2(
				Vector2((footprint_pixels.x - aura_size.x) * 0.5, footprint_pixels.y),
				aura_size
			)
		270:
			return Rect2(
				Vector2(-aura_size.y, (footprint_pixels.y - aura_size.x) * 0.5),
				Vector2(aura_size.y, aura_size.x)
			)
	return Rect2()

func _draw() -> void:
	if level == null:
		return
	if level.realm != realm and realm == LevelBase.Realm.DREAM:
		return
	var alpha := 1.0
	if level.realm != realm:
		alpha = 0.35 if (
			level.realm == LevelBase.Realm.DREAM and realm == LevelBase.Realm.PHYSICAL
		) else 0.15
	if _is_aura_showing():
		draw_rect(_aura_rect(), Color(1.0, 0.12, 0.12, 0.22 * alpha))
