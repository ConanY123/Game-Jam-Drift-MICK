extends Node

# The array index is the zero-based level number; the tutorial is level 0.
const LEVEL_SCENES: Array[String] = [
	"res://scenes/levels/level-0.tscn",
	"res://scenes/levels/level-1.tscn",
	"res://scenes/levels/level-2.tscn",
	"res://scenes/levels/level-3.tscn",
	"res://scenes/levels/level-4.tscn",
	"res://scenes/levels/level-5.tscn",
]

signal all_levels_completed

var current_level := 0

func advance_level() -> void:
	var next_level := current_level + 1
	if next_level >= LEVEL_SCENES.size():
		all_levels_completed.emit()
		return

	var previous_level := current_level
	current_level = next_level
	var error := get_tree().change_scene_to_file(LEVEL_SCENES[current_level])
	if error != OK:
		current_level = previous_level
		push_error("Could not load level %d: %s" % [next_level, error_string(error)])
