extends Pushable

@export var linked_platform: NodePath
@export_range(0, 2, 1) var power_radius := 1

@onready var idle_sprite: Sprite2D = $IdleSprite
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var powered := false

func _ready() -> void:
	size = Vector2i(2, 1)
	holdable = true
	if idle_sprite != null:
		idle_sprite.visible = true
	if animated_sprite != null:
		animated_sprite.visible = false
		animated_sprite.sprite_frames = _build_frames()
		animated_sprite.animation = "run"
	super._ready()
	_update_power_state()
	set_process(true)

func _process(_delta: float) -> void:
	if level == null:
		return
	_update_power_state()

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("run")
	frames.set_animation_loop("run", true)
	if idle_sprite != null and idle_sprite.texture != null:
		frames.add_frame("run", idle_sprite.texture, 0.12)
		frames.add_frame("run", idle_sprite.texture, 0.12)
		frames.add_frame("run", idle_sprite.texture, 0.12)
	return frames

func _update_power_state() -> void:
	var next_powered := _is_near_outlet()
	if next_powered == powered:
		return
	powered = next_powered
	_update_visuals()
	_apply_platform_power()

func _apply_platform_power() -> void:
	if linked_platform.is_empty():
		return
	var p := get_node_or_null(linked_platform)
	if p == null:
		return
	if p.has_method("set_powered"):
		p.call("set_powered", powered)

func _update_visuals() -> void:
	if idle_sprite != null:
		idle_sprite.visible = not powered
	if animated_sprite != null:
		animated_sprite.visible = powered
		if powered:
			animated_sprite.play("run")
		else:
			animated_sprite.stop()
			animated_sprite.frame = 0

func _is_near_outlet() -> bool:
	if level == null:
		return false

	var treadmill_cell := cell
	var outlet_nodes := get_tree().get_nodes_in_group("signal_sources")
	for outlet in outlet_nodes:
		if outlet == null:
			continue
		var outlet_pos: Vector2 = outlet.global_position
		var outlet_cell := Grid.pos_to_cell(level.to_local(outlet_pos))
		if abs(outlet_cell.x - treadmill_cell.x) <= power_radius and abs(outlet_cell.y - treadmill_cell.y) <= power_radius:
			return true

	for child in level.get_children():
		if child == null:
			continue
		if child.name.to_lower().contains("outlet"):
			var outlet_cell := Grid.pos_to_cell(level.to_local(child.global_position))
			if abs(outlet_cell.x - treadmill_cell.x) <= power_radius and abs(outlet_cell.y - treadmill_cell.y) <= power_radius:
				return true
	return false
