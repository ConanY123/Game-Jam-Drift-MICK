class_name RoommatePathOverlay
extends Node2D

var cells: Array[Vector2i] = []

func set_cells(path_cells: Array[Vector2i]) -> void:
	cells = path_cells.duplicate()
	queue_redraw()

func _draw() -> void:
	if cells.size() < 2:
		return

	var points := PackedVector2Array()
	for cell in cells:
		points.append(Grid.cell_to_center(cell))

	draw_polyline(points, Color(1.0, 1.0, 1.0, 0.55), 3.0, true)
	for point in points:
		draw_circle(point, 4.0, Color(1.0, 1.0, 1.0, 0.55))
