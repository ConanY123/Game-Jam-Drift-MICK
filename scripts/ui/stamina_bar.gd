class_name StaminaBar
extends CanvasLayer

# Stamina readout, sitting in the right-hand UI strip (play field is 768px wide;
# the strip runs 768..1024). Mirrors result_overlay's pattern: the level
# instantiates this and calls setup(level); we hook the player's
# stamina_changed signal and resize the gradient fill.
#
# Self-contained: it only reads the player's stamina fraction via the signal.

@onready var _fill: TextureRect = $Panel/BarBG/Fill
@onready var _label: Label = $Panel/Label
@onready var _speed_button: Button = $SpeedButton

const FULL_WIDTH := 200.0  # px width of the bar at 100% (matches the scene)
const BAR_HEIGHT := 20.0  # bar fill height (matches the scene)
const LOW_FRACTION := 0.25  # design doc warns around 25%
const NORMAL_TIME_SCALE := 1.0
const FAST_TIME_SCALE := 2.0

var _speed_button_held := false
var _speed_key_held := false

func _ready() -> void:
	_speed_button.button_down.connect(_on_speed_button_down)
	_speed_button.button_up.connect(_on_speed_button_up)

func _exit_tree() -> void:
	_speed_button_held = false
	_speed_key_held = false
	_update_speed_state()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_speed_button_held = false
		_speed_key_held = false
		_update_speed_state()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_X:
		_speed_key_held = event.pressed
		_update_speed_state()

func setup(level: LevelBase) -> void:
	# build() runs before the level instantiates this, so the player exists.
	var player := level.player
	if player == null:
		return
	player.stamina_changed.connect(_on_stamina_changed)
	# Start showing the current value (full at level start).
	_on_stamina_changed(player.stamina / Player.MAX_STAMINA)

func _on_stamina_changed(fraction: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	# The Fill's texture draws at native width (STRETCH_KEEP) anchored left and
	# the BarBG clips it, so shrinking the rect reveals the gradient left->right.
	_fill.size = Vector2(FULL_WIDTH * f, BAR_HEIGHT)
	# Keep the blue->pink gradient; just push toward a warning pink tint when low
	# so there's still a danger cue without breaking the palette.
	if f <= LOW_FRACTION:
		_fill.modulate = Color(1, 0.75, 0.85, 1.0)
	else:
		_fill.modulate = Color(1, 1, 1, 1.0)
	_label.text = "STAMINA"

func _on_speed_button_down() -> void:
	_speed_button_held = true
	_update_speed_state()

func _on_speed_button_up() -> void:
	_speed_button_held = false
	_update_speed_state()

func _update_speed_state() -> void:
	var speed_up := _speed_button_held or _speed_key_held
	Engine.time_scale = FAST_TIME_SCALE if speed_up else NORMAL_TIME_SCALE
	_speed_button.text = (
		"2× SPEED ACTIVE (X)"
		if speed_up
		else "HOLD X FOR 2× SPEED"
	)
