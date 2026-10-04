extends CanvasLayer

var _pause_button: Button
var _dark_overlay: ColorRect
var _pause_panel: PanelContainer
var _resume_button: Button
var _paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	var window := get_window()
	if window != null:
		window.min_size = Vector2i(1024, 576)
	_build_ui()
	_set_paused(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.text = ""
	_pause_button.tooltip_text = "Pause"
	_pause_button.custom_minimum_size = Vector2(52, 52)
	_pause_button.focus_mode = Control.FOCUS_NONE
	var pause_button_style := StyleBoxFlat.new()
	pause_button_style.bg_color = Color(0.0, 0.0, 0.0, 0.62)
	pause_button_style.corner_radius_top_left = 5
	pause_button_style.corner_radius_top_right = 5
	pause_button_style.corner_radius_bottom_left = 5
	pause_button_style.corner_radius_bottom_right = 5
	_pause_button.add_theme_stylebox_override("normal", pause_button_style)
	for bar_offset in [-7, 2]:
		var pause_bar := ColorRect.new()
		pause_bar.set_anchors_preset(Control.PRESET_CENTER)
		pause_bar.offset_left = bar_offset
		pause_bar.offset_top = -11
		pause_bar.offset_right = bar_offset + 5
		pause_bar.offset_bottom = 11
		pause_bar.color = Color.WHITE
		pause_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pause_button.add_child(pause_bar)
	_pause_button.pressed.connect(_toggle_pause)
	_pause_button.position = Vector2(24, 24)
	add_child(_pause_button)

	_dark_overlay = ColorRect.new()
	_dark_overlay.name = "PauseDarkOverlay"
	_dark_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark_overlay.color = Color(0.0, 0.0, 0.0, 0.6)
	_dark_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_dark_overlay.visible = false
	add_child(_dark_overlay)

	_pause_panel = PanelContainer.new()
	_pause_panel.name = "PausePanel"
	_pause_panel.anchor_left = 0.5
	_pause_panel.anchor_top = 0.5
	_pause_panel.anchor_right = 0.5
	_pause_panel.anchor_bottom = 0.5
	_pause_panel.offset_left = -220
	_pause_panel.offset_top = -130
	_pause_panel.offset_right = 220
	_pause_panel.offset_bottom = 130
	_pause_panel.visible = false
	add_child(_pause_panel)

	var panel_box := VBoxContainer.new()
	panel_box.name = "PanelBox"
	panel_box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel_box.add_theme_constant_override("separation", 28)
	_pause_panel.add_child(panel_box)

	var title := Label.new()
	title.name = "PauseTitle"
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	panel_box.add_child(title)

	_resume_button = Button.new()
	_resume_button.name = "ResumeButton"
	_resume_button.text = "RESUME"
	_resume_button.custom_minimum_size = Vector2(220, 80)
	_resume_button.focus_mode = Control.FOCUS_ALL
	_resume_button.add_theme_font_size_override("font_size", 26)
	_resume_button.pressed.connect(_toggle_pause)
	panel_box.add_child(_resume_button)

func _toggle_pause() -> void:
	_set_paused(not _paused)

func _set_paused(value: bool) -> void:
	_paused = value
	get_tree().paused = value
	_dark_overlay.visible = value
	_pause_panel.visible = value
	if value:
		_resume_button.grab_focus()
