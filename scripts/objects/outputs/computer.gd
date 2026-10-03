class_name Computer
extends "res://scripts/objects/outputs/signal_output.gd"

const FOOTPRINT := Vector2i.ONE
const AURA_SIZE := Vector2i(3, 2)
const ROOMMATE_SIZE := Vector2(20.0, 20.0)
const AURA_DEATH_REASON := "was caught in a computer's signal"

@export_range(0, 270, 90) var aura_rotation_degrees := 0
@export var start_on := false

func _ready() -> void:
	size = FOOTPRINT
	can_be_pushed = true
	initially_powered = start_on
	super._ready()

func _on_power_changed(_is_powered: bool) -> void:
	queue_redraw()

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
	var alpha := 1.0 if level.realm == realm else 0.15
	var footprint_pixels := Vector2(size * Grid.CELL)
	if powered:
		draw_rect(_aura_rect(), Color(1.0, 0.12, 0.12, 0.22 * alpha))
	draw_rect(
		Rect2(Vector2.ONE, footprint_pixels - Vector2(2.0, 2.0)),
		Color("#3478d4", alpha)
	)
	draw_rect(
		Rect2(Vector2.ONE, footprint_pixels - Vector2(2.0, 2.0)),
		Color("#142a48", alpha),
		false,
		2.0
	)
