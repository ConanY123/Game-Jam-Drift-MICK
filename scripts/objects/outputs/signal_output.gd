class_name SignalOutput
extends "res://scripts/objects/pushables/pushable.gd"

@export var can_be_pushed := false
@export var initially_powered := false
@export var invert_signal := false
@export var toggle_on_source_toggle := false

var powered := false

func _ready() -> void:
	super._ready()
	powered = initially_powered
	_on_power_changed(powered)

func can_push(dir: Vector2i) -> bool:
	return can_be_pushed and super.can_push(dir)

func can_interact(dir: Vector2i) -> bool:
	return can_be_pushed and super.can_interact(dir)

func turn_on() -> void:
	set_powered(true)

func turn_off() -> void:
	set_powered(false)

func toggle_power() -> void:
	set_powered(not powered)

func apply_initial_signal(source_is_on: bool) -> void:
	set_powered(source_is_on != invert_signal)

func set_powered(value: bool) -> void:
	if powered == value:
		return
	powered = value
	_on_power_changed(powered)

func _on_power_changed(_is_powered: bool) -> void:
	pass
