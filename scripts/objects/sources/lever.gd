class_name Lever
extends "res://scripts/objects/sources/signal_source.gd"

const LEVER_SIZE := 26.0

func _ready() -> void:
	manually_toggleable = true
	super._ready()

func _draw() -> void:
	var color := Color("#37c96b") if is_on else Color("#e34b4b")
	draw_rect(
		Rect2(
			Vector2.ONE * (Grid.CELL - LEVER_SIZE) * 0.5,
			Vector2.ONE * LEVER_SIZE
		),
		color
	)
	draw_rect(
		Rect2(
			Vector2.ONE * (Grid.CELL - LEVER_SIZE) * 0.5,
			Vector2.ONE * LEVER_SIZE
		),
		Color("#222222"),
		false,
		2.0
	)
