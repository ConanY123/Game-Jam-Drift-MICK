class_name Grid

# One place for every grid number. Change them here only.
const CELL := 32
const FIELD_COLS := 24
const FIELD_ROWS := 18
const STRIP_COLS := 8  # UI strip beside the play field (stamina, side window)

static func cell_to_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL)

static func cell_to_center(cell: Vector2i) -> Vector2:
	return cell_to_pos(cell) + Vector2(CELL, CELL) / 2.0

static func pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i((pos / CELL).floor())

static func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < FIELD_COLS and cell.y < FIELD_ROWS
