class_name LevelCaption
extends CanvasLayer

# Themed title card shown at the start of a level. LevelBase instantiates this
# and calls show_caption() with the level's title/subtitle. It fades in, holds,
# then fades out and frees itself so it never blocks gameplay input.
#
# Visuals follow the dream/physical realm language used elsewhere: a dark
# translucent veil, soft magenta title with a cyan subtitle underline accent.

const VEIL_COLOR := Color(0.04, 0.05, 0.11, 0.78)
const TITLE_COLOR := Color(0.98, 0.72, 0.92)      # soft dream magenta
const TITLE_SHADOW := Color(0.42, 0.78, 1.0, 0.55) # cyan glow
const SUBTITLE_COLOR := Color(0.72, 0.86, 1.0)
const RULE_COLOR := Color(0.6, 0.85, 1.0, 0.85)

@onready var _veil: ColorRect = $Veil
@onready var _box: VBoxContainer = $Center/Box
@onready var _title: Label = $Center/Box/Title
@onready var _rule: ColorRect = $Center/Box/Rule
@onready var _subtitle: Label = $Center/Box/Subtitle


func _ready() -> void:
	layer = 9  # below the result overlay (10) so win/lose always wins
	_veil.color = VEIL_COLOR
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_color_override("font_color", TITLE_COLOR)
	_title.add_theme_color_override("font_shadow_color", TITLE_SHADOW)
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 0)
	_title.add_theme_constant_override("shadow_outline_size", 14)
	_subtitle.add_theme_color_override("font_color", SUBTITLE_COLOR)
	_rule.color = RULE_COLOR
	visible = false


# fade_in / hold / fade_out are seconds. If title is empty, nothing shows.
func show_caption(
	title: String,
	subtitle: String = "",
	hold := 2.0,
	fade_in := 0.6,
	fade_out := 0.8
) -> void:
	if title.strip_edges().is_empty():
		queue_free()
		return
	# @onready children aren't resolved until the node is in the tree, so if we
	# were called the same frame we were added, wait one frame first.
	if not is_node_ready():
		await ready

	_title.text = title.to_upper()
	_subtitle.text = subtitle
	_subtitle.visible = not subtitle.strip_edges().is_empty()
	_rule.visible = _subtitle.visible

	visible = true
	_box.modulate.a = 0.0
	_veil.modulate.a = 0.0
	# Start slightly lifted and settle down for a gentle "surfacing" feel.
	_box.position.y = 12.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(_veil, "modulate:a", 1.0, fade_in)
	tween.tween_property(_box, "modulate:a", 1.0, fade_in)
	tween.tween_property(_box, "position:y", 0.0, fade_in)
	tween.set_parallel(false)

	tween.tween_interval(hold)

	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_veil, "modulate:a", 0.0, fade_out)
	tween.tween_property(_box, "modulate:a", 0.0, fade_out)
	tween.set_parallel(false)

	tween.tween_callback(queue_free)
