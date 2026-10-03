class_name StaminaBar
extends CanvasLayer

# Stamina readout and time controls in the right-hand UI strip. The level
# instantiates this and calls setup(level); we hook the player's stamina_changed
# signal and resize the gradient fill.
#
# Self-contained: it only reads the player's stamina fraction via the signal.

@onready var _fill: TextureRect = $Panel/BarBG/Fill
@onready var _label: Label = $Panel/Label
@onready var _speed_button: Button = $SpeedButton
@onready var _fast_forward_button: Button = $FastForwardButton
@onready var _edge_effect: ColorRect = $EdgeEffect
@onready var _edge_material: ShaderMaterial = $EdgeEffect.material

const FULL_WIDTH := 168.0  # six-cell panel width minus its 12px side margins
const BAR_HEIGHT := 20.0  # bar fill height (matches the scene)
const LOW_FRACTION := 0.35  # design doc warns around 35%
const LOW_STAMINA_EFFECT_START := 0.6
const DREAM_LOW_STAMINA_EFFECT_STRENGTH := 0.38
const STAMINA_BAR_TWEEN_DURATION := 0.6
const EDGE_EFFECT_TWEEN_DURATION := 1
const REALM_ATTEMPT_PULSE_DURATION := 0.55
const NORMAL_TIME_SCALE := 1.0
const FAST_TIME_SCALE := 2.0
const FAST_FORWARD_TIME_SCALE := 16.0

var _fast_forward_held := false
var _two_x_enabled := false
var _player: Player
var _level: LevelBase
var _effect_time := 0.0
var _fill_tween: Tween
var _edge_effect_tween: Tween
var _realm_attempt_tween: Tween
var _stamina_display_initialized := false

func _ready() -> void:
	_speed_button.toggled.connect(_on_speed_button_toggled)
	_fast_forward_button.button_down.connect(_on_fast_forward_button_down)
	_fast_forward_button.button_up.connect(_on_fast_forward_button_up)
	_edge_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(_update_edge_effect_size)
	_update_edge_effect_size()
	_update_world_effect()

func _update_edge_effect_size() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_edge_material.set_shader_parameter("effect_size_px", viewport_size)

func _process(delta: float) -> void:
	_effect_time += delta
	_edge_material.set_shader_parameter("effect_time", _effect_time)

func _exit_tree() -> void:
	_fast_forward_held = false
	Engine.time_scale = NORMAL_TIME_SCALE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_fast_forward_held = false
		_fast_forward_button.set_pressed_no_signal(false)
		_update_speed_state()

func _input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.keycode == KEY_X
		and event.pressed
		and not event.echo
	):
		_two_x_enabled = not _two_x_enabled
		_speed_button.set_pressed_no_signal(_two_x_enabled)
		_update_speed_state()

func setup(level: LevelBase) -> void:
	# build() runs before the level instantiates this, so the player exists.
	_level = level
	_player = level.player
	if _player == null:
		return
	_player.stamina_changed.connect(_on_stamina_changed)
	level.realm_changed.connect(_on_realm_changed)
	level.realm_switch_failed_low_stamina.connect(_on_realm_switch_attempted)
	# Start showing the current value (full at level start).
	_on_stamina_changed(_player.stamina / Player.MAX_STAMINA)
	_update_world_effect()

func _on_stamina_changed(fraction: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	# The Fill's texture draws at native width (STRETCH_KEEP) anchored left and
	# the BarBG clips it, so shrinking the rect reveals the gradient left->right.
	var target_size := Vector2(FULL_WIDTH * f, BAR_HEIGHT)
	if _stamina_display_initialized:
		if _fill_tween != null and _fill_tween.is_running():
			_fill_tween.kill()
		_fill_tween = create_tween()
		_fill_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_fill_tween.tween_property(
			_fill,
			"size",
			target_size,
			STAMINA_BAR_TWEEN_DURATION
		)
	else:
		_fill.size = target_size
		_stamina_display_initialized = true
	_update_fill_tint(f)
	_label.text = "STAMINA"
	_update_world_effect()

func _update_fill_tint(fraction: float) -> void:
	if (
		_level != null
		and _player != null
		and _level.realm == LevelBase.Realm.DREAM
		and not _player.can_switch_to_physical()
	):
		_fill.modulate = Color(0.65, 0.65, 0.65, 1.0)
	elif fraction <= LOW_FRACTION:
		_fill.modulate = Color(1, 0.75, 0.85, 1.0)
	else:
		_fill.modulate = Color(1, 1, 1, 1.0)

func _on_realm_changed(_new_realm: int) -> void:
	if _player != null:
		_update_fill_tint(_player.stamina / Player.MAX_STAMINA)
	_update_world_effect()

func _update_world_effect() -> void:
	if _player == null or _level == null:
		_animate_edge_strength(0.0)
		return

	var target_strength := 0.0
	if _level.realm == LevelBase.Realm.PHYSICAL:
		var fraction := _player.stamina / Player.MAX_STAMINA
		var warning_range := 1.0 - LOW_STAMINA_EFFECT_START
		target_strength = clampf(
			(LOW_STAMINA_EFFECT_START - fraction) / warning_range,
			0.0,
			1.0
		)
		_edge_material.set_shader_parameter("effect_mode", 0)
	else:
		_edge_material.set_shader_parameter("effect_mode", 1)
		if not _player.can_switch_to_physical():
			target_strength = DREAM_LOW_STAMINA_EFFECT_STRENGTH
	_animate_edge_strength(target_strength)

func _on_realm_switch_attempted() -> void:
	if _level == null or _level.realm != LevelBase.Realm.DREAM:
		return
	if _realm_attempt_tween != null and _realm_attempt_tween.is_running():
		_realm_attempt_tween.kill()
	_set_realm_attempt_pulse(0.0)
	_realm_attempt_tween = create_tween()
	_realm_attempt_tween.tween_method(
		_set_realm_attempt_pulse,
		0.0,
		1.0,
		REALM_ATTEMPT_PULSE_DURATION * 0.3
	)
	_realm_attempt_tween.tween_method(
		_set_realm_attempt_pulse,
		1.0,
		0.0,
		REALM_ATTEMPT_PULSE_DURATION * 0.7
	)

func _set_realm_attempt_pulse(amount: float) -> void:
	_edge_material.set_shader_parameter("attempt_strength", amount)
	_edge_material.set_shader_parameter(
		"attempt_size_px",
		lerpf(110.0, 96.0, amount)
	)

func _animate_edge_strength(target_strength: float) -> void:
	if _edge_effect_tween != null and _edge_effect_tween.is_running():
		_edge_effect_tween.kill()
	var current_strength: Variant = _edge_material.get_shader_parameter("strength")
	var start_strength := float(current_strength) if current_strength != null else 0.0
	_edge_effect_tween = create_tween()
	_edge_effect_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_edge_effect_tween.tween_method(
		func(strength: float) -> void:
			_edge_material.set_shader_parameter("strength", strength),
		start_strength,
		target_strength,
		EDGE_EFFECT_TWEEN_DURATION
	)

func _on_speed_button_toggled(enabled: bool) -> void:
	_two_x_enabled = enabled
	_update_speed_state()

func _on_fast_forward_button_down() -> void:
	_fast_forward_held = true
	_update_speed_state()

func _on_fast_forward_button_up() -> void:
	_fast_forward_held = false
	_update_speed_state()

func _update_speed_state() -> void:
	if _fast_forward_held:
		Engine.time_scale = FAST_FORWARD_TIME_SCALE
	else:
		Engine.time_scale = FAST_TIME_SCALE if _two_x_enabled else NORMAL_TIME_SCALE
