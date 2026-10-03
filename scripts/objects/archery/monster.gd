class_name Monster
extends Node2D

# A drifting spirit from the endless layer. It slowly floats toward the
# roommate. Shoot it with an arrow to banish it (it fades out and frees).
#
# Grid-free movement (like the player and roommate) - it drifts in pixel space
# toward the roommate's current position. Hit detection against arrows is done
# by distance in Arrow, so this stays simple.
#
# Self-contained: nothing else needs to know the Monster type. The level spawns
# it; the arrow banishes it via the kill() method (duck-typed, no class_name
# dependency).

const SPEED := 18.0  # slower than the roommate (24) so it's a lazy drift
const RADIUS := 11.0  # visual + hit radius
const FADE_TIME := 0.25  # banish animation length

# If true, drifting into the roommate fails the level (hard threat). Default
# false = soft threat (design doc: missed spirits never reset the level); you
# just lose the chance to banish it for stamina later.
@export var lethal_on_touch := false

var level: LevelBase
var dying := false
var _fade_t := 0.0
var _draw_scale := 1.0
var _draw_alpha := 1.0

# A drop-in Sprite2D child (optional). If present, the fallback circle isn't
# drawn and the sprite is used instead.
@onready var _sprite: Node2D = get_node_or_null("Sprite2D")

func setup(p_level: LevelBase) -> void:
	level = p_level

func _ready() -> void:
	if level == null and get_parent() is LevelBase:
		level = get_parent()
	# Snap to the center of whatever cell we were dropped on in the editor.
	position = Grid.cell_to_center(Grid.pos_to_cell(position))
	if level != null:
		level.realm_changed.connect(func(_r): _refresh())
	_refresh()
	queue_redraw()

# Dream creature: only shown (and only active) while viewing the dream realm.
func _refresh() -> void:
	visible = level != null and level.realm == LevelBase.Realm.DREAM

func _physics_process(delta: float) -> void:
	if level == null:
		return
	if dying:
		_update_fade(delta)
		return
	# Only drift and threaten while the dream is the active realm.
	if level.realm != LevelBase.Realm.DREAM:
		return
	# Don't start drifting until the hour has started (player has moved),
	# matching the roommate's gating.
	if level.player == null or not level.player.has_moved:
		return
	var rm := level.roommate
	if rm == null:
		return
	var to_rm := rm.position - position
	var dist := to_rm.length()
	if dist > 1.0:
		position += to_rm / dist * SPEED * delta
	if lethal_on_touch and dist < RADIUS and not rm.get("dead"):
		level.level_lost.emit("a nightmare reached him")
	queue_redraw()

# Called by an arrow that reaches us. Begins the banish fade.
func kill() -> void:
	if dying:
		return
	dying = true
	_fade_t = 0.0

func _update_fade(delta: float) -> void:
	_fade_t += delta / FADE_TIME
	var t := clampf(_fade_t, 0.0, 1.0)
	_draw_scale = 1.0 + 0.6 * t  # puff outward
	_draw_alpha = 1.0 - t
	# Drive a sprite child too, if there is one (the fallback uses the vars).
	if _sprite != null:
		_sprite.scale = Vector2(_draw_scale, _draw_scale)
		_sprite.modulate.a = _draw_alpha
	queue_redraw()
	if t >= 1.0:
		queue_free()

func _draw() -> void:
	# If an artist dropped in a Sprite2D child, let it do the drawing.
	if _sprite != null:
		return
	var body := Color(0.55, 0.3, 0.7, _draw_alpha)  # dusky purple spirit
	var r := RADIUS * _draw_scale
	draw_circle(Vector2.ZERO, r, body)
	if not dying:
		# two little eyes so it reads as a creature, facing the roommate
		var eye := Color(1, 1, 1, 0.9)
		draw_circle(Vector2(-4, -2), 2.0, eye)
		draw_circle(Vector2(4, -2), 2.0, eye)
