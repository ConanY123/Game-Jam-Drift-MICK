class_name LevelCaption
extends CanvasLayer

# Small arcade-style title card that appears in the top of the UI strip at
# level start. LevelBase instantiates this and calls show_caption() with the
# level's name. It stays visible for the duration of the level.
#
# Deliberately flat and hard-edged (no glow/anti-aliased shadow) for an 8-bit
# look. Swap the default font for a pixel font (e.g. Press Start 2P) on the Tag
# and Title labels to make it fully bitmap.

@onready var _card: PanelContainer = $Card
@onready var _tag: Label = $Card/Box/Tag
@onready var _title: Label = $Card/Box/Title


func _ready() -> void:
	layer = 9  # below the result overlay (10) so win/lose always wins
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


# Extra arguments are accepted for call-site compatibility.
func show_caption(
	title: String,
	_subtitle: String = "",
	_hold := 2.0,
	tag_text := "LEVEL",
	_fade_in := 0.6,
	_fade_out := 0.6
) -> void:
	if title.strip_edges().is_empty():
		queue_free()
		return
	if not is_node_ready():
		await ready

	_tag.text = tag_text
	_title.text = title.to_upper()
	visible = true
	_card.modulate.a = 0.0

	# Let the container compute its final size, then scale from its own center so
	# the "pop" doesn't drift sideways in the strip.
	await get_tree().process_frame
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.92, 0.92)

	var tween := create_tween()
	# Arcade flash-in: a couple of hard blinks, then a quick pop to full size.
	tween.tween_property(_card, "modulate:a", 1.0, 0.07)
	tween.tween_property(_card, "modulate:a", 0.0, 0.07)
	tween.tween_property(_card, "modulate:a", 1.0, 0.07)
	tween.parallel().tween_property(_card, "scale", Vector2(1.08, 1.08), 0.07)
	tween.tween_property(_card, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
