class_name ResultOverlay
extends CanvasLayer

# Minimal win/lose banner. Listens to the level and shows a message.
# Press R to restart (LevelBase already reloads the scene on R).

@onready var _title: Label = $Center/Box/Title
@onready var _sub: Label = $Center/Box/Sub

func setup(level: LevelBase) -> void:
	level.level_won.connect(_on_won)
	level.level_lost.connect(_on_lost)

func _ready() -> void:
	visible = false

func _on_won() -> void:
	_show("YOU KEPT HIM SAFE", "Press R to replay", Color(0.5, 1.0, 0.6))

func _on_lost(reason: String) -> void:
	_show("GAME OVER", "He %s. Press R to retry." % reason, Color(1.0, 0.5, 0.5))

func _show(title: String, subtitle: String, color: Color) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", color)
	_sub.text = subtitle
	visible = true
