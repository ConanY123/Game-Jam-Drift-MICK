class_name MovingPlatform
extends "res://scripts/objects/outputs/signal_output.gd"

@export_enum("Horizontal", "Vertical") var orientation := 0
# Destinations are grid coordinates for the center cell of the platform.
@export var off_destination := Vector2i.ZERO
@export var on_destination := Vector2i.ZERO
# Movement speed in grid cells per second.
@export_range(0.1, 20.0, 0.1) var speed := 2.0

var _center_cell := Vector2i.ZERO
var _destination_position := Vector2.ZERO


func _ready() -> void:
	_set_footprint()
	super._ready()


func can_push(_dir: Vector2i) -> bool:
	return false


func can_interact(_dir: Vector2i) -> bool:
	return false


func setup(p_level: LevelBase, p_center_cell: Vector2i) -> void:
	_center_cell = p_center_cell
	_set_footprint()
	super.setup(p_level, p_center_cell - _center_offset())
	position = Grid.cell_to_center(_center_cell)
	_destination_position = position


func _set_footprint() -> void:
	size = Vector2i(3, 1) if orientation == 0 else Vector2i(1, 3)


func _center_offset() -> Vector2i:
	return Vector2i(1, 0) if orientation == 0 else Vector2i(0, 1)


func _on_power_changed(is_powered: bool) -> void:
	var destination := on_destination if is_powered else off_destination
	_destination_position = Grid.cell_to_center(destination)
	moving = not position.is_equal_approx(_destination_position)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if level == null or not moving:
		return

	var next_position := position.move_toward(
		_destination_position,
		speed * Grid.CELL * delta
	)
	var next_center_cell := Grid.pos_to_cell(
		next_position - Vector2.ONE * (Grid.CELL / 2.0)
	)
	if next_center_cell != _center_cell and not _claim_footprint(next_center_cell):
		return

	position = next_position
	if position.is_equal_approx(_destination_position):
		position = _destination_position
		moving = false
	queue_redraw()


func _claim_footprint(center_cell: Vector2i) -> bool:
	var next_origin := center_cell - _center_offset()
	var next_cells := get_cells(next_origin)
	for cell_to_claim in next_cells:
		if not level.is_free(cell_to_claim, self, realm) or level.in_push_ban(cell_to_claim):
			return false

	level.unregister(self, realm)
	_center_cell = center_cell
	cell = next_origin
	level.register(self, next_cells, realm)
	return true


func _draw() -> void:
	if level == null:
		return
	if level.realm != realm and realm == LevelBase.Realm.DREAM:
		return

	var alpha := 1.0 if level.realm == realm else 0.15
	var footprint_size := Vector2(size * Grid.CELL)
	var rect := Rect2(-footprint_size * 0.5 + Vector2.ONE, footprint_size - Vector2(2.0, 2.0))
	draw_rect(rect, Color(color, alpha))
	draw_rect(rect, Color("#173746", alpha), false, 2.0)
