extends CanvasLayer

const WIPE_SHADER := preload("res://shaders/screen_wipe.gdshader")
const SCENE_CHANGE_TIMEOUT := 10.0

var _wipe: ColorRect
var _material: ShaderMaterial
var _transitioning := false
var _waiting_for_scene_change := false
var _scene_changed := false
var _scene_before_transition_id := 0

func is_transitioning() -> bool:
	return _transitioning

func _ready() -> void:
	layer = 100
	get_tree().scene_changed.connect(_on_scene_changed)
	_wipe = ColorRect.new()
	_wipe.name = "ScreenWipe"
	_wipe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wipe.mouse_filter = Control.MOUSE_FILTER_STOP
	_wipe.visible = false
	_material = ShaderMaterial.new()
	_material.shader = WIPE_SHADER
	_wipe.material = _material
	add_child(_wipe)

func play(
	duration: float,
	on_covered: Callable,
	wipe_color := Color(0.015, 0.02, 0.055, 1.0),
	edge_color := Color(0.35, 0.85, 1.0, 1.0),
	wait_for_scene_change := false
) -> void:
	if _transitioning:
		return
	_transitioning = true
	_wipe.visible = true
	_material.set_shader_parameter("progress", 0.0)
	_material.set_shader_parameter("opening", false)
	_material.set_shader_parameter("wipe_color", wipe_color)
	_material.set_shader_parameter("edge_color", edge_color)

	var half_duration := maxf(duration, 0.0) * 0.5
	var tween := create_tween()
	tween.tween_method(
		Callable(self, "_set_progress").bind(false),
		0.0,
		1.0,
		half_duration
	)
	tween.tween_callback(func():
		_run_covered_action(on_covered, half_duration, wait_for_scene_change)
	)

func _run_covered_action(
	action: Callable,
	open_duration: float,
	wait_for_scene_change: bool
) -> void:
	_waiting_for_scene_change = wait_for_scene_change
	_scene_changed = false
	var current_scene := get_tree().current_scene
	_scene_before_transition_id = (
		current_scene.get_instance_id() if current_scene != null else 0
	)
	var action_result: Variant
	if action.is_valid():
		action_result = action.call()
	if wait_for_scene_change and action_result != false:
		var start_time := Time.get_ticks_msec()
		while not _scene_changed and not _replacement_scene_is_ready():
			if (Time.get_ticks_msec() - start_time) / 1000.0 >= SCENE_CHANGE_TIMEOUT:
				push_error("Timed out waiting for the replacement scene during transition.")
				break
			await get_tree().process_frame
	_waiting_for_scene_change = false

	var tween := create_tween()
	tween.tween_method(
		Callable(self, "_set_progress").bind(true),
		0.0,
		1.0,
		open_duration
	)
	tween.tween_callback(func():
		_wipe.visible = false
		_transitioning = false
	)

func _on_scene_changed() -> void:
	if _waiting_for_scene_change:
		_scene_changed = true

func _replacement_scene_is_ready() -> bool:
	var current_scene := get_tree().current_scene
	return (
		current_scene != null
		and current_scene.get_instance_id() != _scene_before_transition_id
	)

func _set_progress(progress: float, opening: bool) -> void:
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("opening", opening)
