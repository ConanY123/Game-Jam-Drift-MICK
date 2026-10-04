extends Control

const PLAYER_SCENE_PATH := "res://scenes/actors/player.tscn"
const ROOMMATE_SCENE: PackedScene = preload("res://scenes/actors/roommate.tscn")
const LEVEL_ZERO_SCENE: PackedScene = preload("res://scenes/levels/level-0.tscn")
const TITLE_FALLBACK_FONT: FontFile = preload("res://fonts/AlexBrush-Regular.ttf")
const LEVEL_ZERO := "res://scenes/levels/level-0.tscn"
const TITLE_LIFT := 32.0 * 1.6 * 0.125
const TITLE_EXTRA_LIFT := 2.0 * Grid.CELL
const DIALOGUE: Array[Dictionary] = [
	{
		"speaker": "ROOMMATE",
		"focus": "roommate",
		"text": "It's getting late... it's 12 AM and my finals exam is tomorrow...",
	},
	{
		"speaker": "YOU",
		"focus": "player",
		"text": "You should get some sleep.",
	},
	{
		"speaker": "ROOMMATE",
		"focus": "roommate",
		"text": "Yeah, I should... I really need 8 hours. I definitely won't be able to write my test without my full sleep.",
	},
	{
		"speaker": "YOU",
		"focus": "player",
		"text": "Better get to bed now then.",
	},
	{
		"speaker": "ROOMMATE",
		"focus": "roommate",
		"text": "Alright, good night. Make sure I don't wake up tonight.",
	},
]
const INNER_MONOLOGUE: Array[String] = [
	"I guess I'll spend the night making sure he doesn't wake up...",
]

var _stage: Node2D
var _player: Node2D
var _roommate: Node2D
var _player_sprite: AnimatedSprite2D
var _roommate_sprite: AnimatedSprite2D

var _dialogue_panel: PanelContainer
var _speaker_label: Label
var _dialogue_label: Label
var _continue_button: Button
var _fade_rect: ColorRect
var _title_top: Label
var _title_bottom: Label
var _title_prompt: Label
var _dialogue_index := 0
var _monologue_index := -1
var _transition_started := false
var _cinematic_busy := false
var _title_card_active := false
var _gameplay_ui: Node
var _pause_button: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_disable_gameplay_ui()
	_build_stage()
	_build_backdrop()
	_spawn_characters()
	_build_dialogue_panel()
	_show_line()

func _exit_tree() -> void:
	if is_instance_valid(_gameplay_ui):
		_gameplay_ui.set_process_input(true)
	# The pause icon stays hidden; Escape still pauses once input is re-enabled.

func _disable_gameplay_ui() -> void:
	_gameplay_ui = get_node_or_null("/root/GameplayUI")
	if _gameplay_ui != null:
		_gameplay_ui.set_process_input(false)
		_pause_button = _gameplay_ui.get_node_or_null("PauseButton") as Control
		if _pause_button != null:
			_pause_button.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _title_card_active:
			if event.keycode == KEY_Z:
				_start_level_zero()
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_Z, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_advance_dialogue()
			get_viewport().set_input_as_handled()

func _build_stage() -> void:
	_stage = Node2D.new()
	_stage.name = "LevelZeroRoomStage"
	var view_size := get_viewport_rect().size
	_stage.position = Vector2((view_size.x - 768.0) * 0.5, 0.0)
	add_child(_stage)

	var room := LEVEL_ZERO_SCENE.instantiate() as Node2D
	room.name = "LevelZeroRoomVisuals"
	room.set_script(null)
	_stage.add_child(room)

func _build_backdrop() -> void:
	var shade := ColorRect.new()
	shade.name = "NightShade"
	shade.color = Color(0.015, 0.025, 0.06, 0.3)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_fade_rect = ColorRect.new()
	_fade_rect.name = "FadeToBlack"
	_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_rect)

	var title_center := Control.new()
	title_center.name = "TitleCenter"
	title_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_center.visible = false
	add_child(title_center)

	var title_font := SystemFont.new()
	title_font.font_names = PackedStringArray(["The Augusta", "Alex Brush"])
	title_font.allow_system_fallback = true
	_title_top = _create_title_word(
		"LUCID",
		title_font,
		-154.0 - TITLE_LIFT - TITLE_EXTRA_LIFT
	)
	_title_bottom = _create_title_word(
		"DRIFT",
		title_font,
		92.0 - TITLE_LIFT - TITLE_EXTRA_LIFT
	)
	title_center.add_child(_title_top)
	title_center.add_child(_title_bottom)

	_title_prompt = Label.new()
	_title_prompt.name = "TitlePrompt"
	_title_prompt.anchor_left = 0.0
	_title_prompt.anchor_top = 0.84
	_title_prompt.anchor_right = 1.0
	_title_prompt.anchor_bottom = 0.92
	_title_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_prompt.text = "PRESS Z TO BEGIN"
	_title_prompt.add_theme_font_size_override("font_size", 18)
	_title_prompt.add_theme_color_override("font_color", Color.WHITE)
	_title_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_prompt.modulate.a = 0.0
	title_center.add_child(_title_prompt)

	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.position = Vector2(52, 34)
	time_label.text = "12:00 AM  /  EXAM EVE"
	time_label.add_theme_color_override("font_color", Color(0.78, 0.85, 0.92, 0.9))
	time_label.add_theme_font_size_override("font_size", 15)
	add_child(time_label)

func _spawn_characters() -> void:
	var player_scene := ResourceLoader.load(
		PLAYER_SCENE_PATH,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as PackedScene
	if player_scene == null or not player_scene.can_instantiate():
		push_error("Could not load a valid cutscene player from %s." % PLAYER_SCENE_PATH)
		return
	_player = player_scene.instantiate() as Node2D
	if _player == null:
		push_error("The cutscene player scene did not instantiate a Node2D.")
		return
	_player.name = "CutscenePlayer"
	_player.position = Vector2(300, 288)
	_player.scale = Vector2(1.6, 1.6)
	_player.set_physics_process(false)
	_player.set_process_input(false)
	_player.set_process_unhandled_input(false)
	_stage.add_child(_player)

	_roommate = ROOMMATE_SCENE.instantiate() as Node2D
	_roommate.name = "CutsceneRoommate"
	_roommate.position = Vector2(420, 288)
	_roommate.scale = Vector2(1.6, 1.6)
	_roommate.set_physics_process(false)
	_roommate.set_process_input(false)
	_roommate.set_process_unhandled_input(false)
	_stage.add_child(_roommate)

	_player_sprite = _player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_player_sprite.animation = "walk_right"
	_player_sprite.stop()
	_player_sprite.frame = 0
	_roommate_sprite = _roommate.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_roommate_sprite.animation = "walk_left"
	_roommate_sprite.stop()
	_roommate_sprite.frame = 0

func _create_title_word(word: String, font: Font, vertical_offset: float) -> Label:
	var label := Label.new()
	label.name = "Title" + word.capitalize()
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -400
	label.offset_top = vertical_offset
	label.offset_right = 400
	label.offset_bottom = vertical_offset + 112
	label.text = word
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 94)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate.a = 0.0
	return label

func _build_dialogue_panel() -> void:
	_dialogue_panel = PanelContainer.new()
	var panel := _dialogue_panel
	panel.name = "DialoguePanel"
	panel.anchor_left = 0.055
	panel.anchor_top = 0.665
	panel.anchor_right = 0.945
	panel.anchor_bottom = 0.955
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.085, 0.94)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.45, 0.68, 0.78, 0.75)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margins := MarginContainer.new()
	for side in ["left", "right"]:
		margins.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margins)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margins.add_child(column)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color(0.48, 0.82, 0.91))
	_speaker_label.add_theme_font_size_override("font_size", 14)
	column.add_child(_speaker_label)

	_dialogue_label = Label.new()
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	_dialogue_label.add_theme_font_size_override("font_size", 23)
	_dialogue_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_dialogue_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)

	var hint := Label.new()
	hint.text = "Z / SPACE / ENTER"
	hint.add_theme_color_override("font_color", Color(0.65, 0.72, 0.8))
	hint.add_theme_font_size_override("font_size", 13)
	actions.add_child(hint)

	_continue_button = Button.new()
	_continue_button.text = "CONTINUE"
	_continue_button.custom_minimum_size = Vector2(150, 38)
	_continue_button.pressed.connect(_advance_dialogue)
	actions.add_child(_continue_button)

func _show_line() -> void:
	var line: Dictionary = DIALOGUE[_dialogue_index]
	_speaker_label.text = str(line["speaker"])
	_dialogue_label.text = str(line["text"])
	_continue_button.text = "CONTINUE"
	_set_speaker_focus(str(line["focus"]))

func _set_speaker_focus(focus: String) -> void:
	_player_sprite.modulate = Color.WHITE if focus == "player" else Color(0.58, 0.65, 0.74)
	_roommate_sprite.modulate = Color.WHITE if focus == "roommate" else Color(0.58, 0.65, 0.74)

func _begin_player_closeup() -> void:
	_cinematic_busy = true
	_dialogue_panel.visible = false
	_monologue_index = 0
	_zoom_to_player(2.35, 1.45)

func _show_monologue_line() -> void:
	_dialogue_panel.visible = true
	_speaker_label.text = "YOU"
	_dialogue_label.text = INNER_MONOLOGUE[_monologue_index]
	_continue_button.text = "CONTINUE"
	_player_sprite.modulate = Color.WHITE

func _zoom_to_player(target_scale: float, duration: float) -> void:
	_cinematic_busy = true
	var view_size := get_viewport_rect().size
	var target_position := view_size * 0.5 - _player.position * target_scale
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_stage, "scale", Vector2.ONE * target_scale, duration)
	tween.tween_property(_stage, "position", target_position, duration)
	tween.set_parallel(false)
	tween.tween_callback(func():
		_cinematic_busy = false
		_show_monologue_line()
	)

func _begin_title_fade() -> void:
	_cinematic_busy = true
	_dialogue_panel.visible = false
	for child in get_children():
		if child is Label and child.name == "TimeLabel":
			child.visible = false
	var title_center := get_node("TitleCenter") as Control
	title_center.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_fade_rect, "color:a", 0.88, 1.25)
	tween.tween_property(_title_top, "modulate:a", 1.0, 1.35)
	tween.tween_property(_title_bottom, "modulate:a", 1.0, 1.35)
	tween.set_parallel(false)
	tween.tween_interval(0.5)
	tween.tween_property(_title_prompt, "modulate:a", 1.0, 0.5)
	tween.tween_callback(func(): _title_card_active = true)

func _advance_dialogue() -> void:
	if _transition_started or _cinematic_busy:
		return
	if _monologue_index < 0:
		if _dialogue_index < DIALOGUE.size() - 1:
			_dialogue_index += 1
			_show_line()
		else:
			_begin_player_closeup()
		return
	if _monologue_index == 0:
		_begin_title_fade()

func _start_level_zero() -> void:
	if _transition_started:
		return
	_transition_started = true
	_title_card_active = false
	call_deferred("_load_level_zero")

func _load_level_zero() -> void:
	var error := get_tree().change_scene_to_file(LEVEL_ZERO)
	if error != OK:
		_transition_started = false
		_title_card_active = true
		push_error("Could not load Level 0: %s" % error_string(error))
