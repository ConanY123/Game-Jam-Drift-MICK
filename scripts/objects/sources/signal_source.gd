class_name SignalSource
extends Node2D

signal turned_on
signal turned_off

@export_enum("Physical", "Dream") var realm := 0
@export var initially_on := false
@export var manually_toggleable := false
@export var outputs: Array[NodePath] = []

var level: Node
var is_on := false

func _ready() -> void:
	var parent_node := get_parent()
	while parent_node != null and not (
		parent_node.has_method("register")
		and parent_node.has_signal("realm_changed")
	):
		parent_node = parent_node.get_parent()
	if parent_node != null:
		level = parent_node
		level.connect("realm_changed", _on_realm_changed)
		_refresh()
	is_on = initially_on
	add_to_group("signal_sources")
	for output_path in outputs:
		var output_node := get_node_or_null(output_path)
		if output_node == null or not (
			output_node.has_method("turn_on")
			and output_node.has_method("turn_off")
		):
			push_error("SignalSource output path does not point to a signal output: %s" % output_path)
			continue
		if output_node.get("invert_signal") == true:
			turned_on.connect(Callable(output_node, "turn_off"))
			turned_off.connect(Callable(output_node, "turn_on"))
		else:
			turned_on.connect(Callable(output_node, "turn_on"))
			turned_off.connect(Callable(output_node, "turn_off"))
	call_deferred("_publish_initial_state")

func can_interact_in_realm(in_realm: int) -> bool:
	return realm == in_realm

func _on_realm_changed(_new_realm: int) -> void:
	_refresh()

func _refresh() -> void:
	if level == null:
		return
	var current_realm := int(level.get("realm"))
	visible = current_realm == realm or realm == 0
	modulate.a = 1.0 if current_realm == realm else 0.35
	queue_redraw()

func _publish_initial_state() -> void:
	if is_on:
		turned_on.emit()
	else:
		turned_off.emit()
	queue_redraw()

func set_on() -> void:
	_set_state(true)

func set_off() -> void:
	_set_state(false)

func toggle() -> void:
	_set_state(not is_on)

func _set_state(new_state: bool) -> void:
	if is_on == new_state:
		return
	is_on = new_state
	if is_on:
		turned_on.emit()
	else:
		turned_off.emit()
	queue_redraw()
