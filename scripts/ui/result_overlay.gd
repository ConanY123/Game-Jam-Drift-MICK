class_name ResultOverlay
extends CanvasLayer

# Minimal win/lose banner. LevelBase controls when each message is shown.

@onready var _title: Label = $Center/Box/Title
@onready var _sub: Label = $Center/Box/Sub


func _ready() -> void:
	visible = false

func show_win() -> void:
	_show("YOU KEPT HIM SAFE", "Press R to replay", Color(0.5, 1.0, 0.6))

func show_loss(reason: String) -> void:
	_show("", "", Color(1.0, 0.5, 0.5))
	get_node("/root/AudioManager").call("play_game_over")

func _show(title: String, subtitle: String, color: Color) -> void:
	_title.text = title
	_title.visible = not title.is_empty()
	_title.add_theme_color_override("font_color", color)
	_sub.text = subtitle
	visible = true
