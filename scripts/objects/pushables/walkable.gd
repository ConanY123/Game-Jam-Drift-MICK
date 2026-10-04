class_name Walkable
extends Pushable

# A Pushable the player can partly walk onto (e.g. a treadmill).
#
# Geometry is described in the object's own unrotated, unscaled frame:
#   - base_size is the footprint in cells before scale/rotation.
#   - Local +X runs from the ENTRANCE edge (x = 0) to the far end.
#   - Local +Y runs across the width.
# The node's scale and rotation (snapped to 90 degrees) are applied on top, so
# the entrance stays attached to the same side of the object when you rotate it.
#
# Player rules:
#   - Enter only through the entrance edge, and not within entrance_margin of
#     either corner of that edge.
#   - Walk in until the front of the body reaches walkable_depth of the length.
#   - While on the walkway the sides and back act as walls (no exiting through
#     them) and the object can't be pushed. From outside it is a normal pushable.

@export var base_size := Vector2i(1, 1)
@export_range(0.0, 1.0, 0.05) var walkable_depth := 0.5
@export_range(0.0, 0.5, 0.01) var entrance_margin := 0.1

# ---------- setup / pushing ----------

# Replaces Pushable.setup: the footprint comes from base_size + the node's
# transform, and the node origin is the entrance corner (not always top-left).
func setup(p_level: LevelBase, _p_cell: Vector2i) -> void:
	level = p_level
	rotation = snappedf(rotation, PI / 2.0)
	# Snap the whole footprint to the grid. The node origin is the entrance
	# corner, which after a rotation is NOT the footprint's top-left, so snap by
	# the bounding rect's top-left and shift the node by that same delta. This
	# keeps the registered cells (always a top-left origin + size) aligned with
	# the rotated visual footprint, so pushing and walking work when rotated.
	var bounds := footprint_rect()
	var snapped_top_left := Vector2((bounds.position / Grid.CELL).round()) * Grid.CELL
	var delta := snapped_top_left - bounds.position
	global_position = level.to_global(level.to_local(global_position) + delta)
	cell = Vector2i((snapped_top_left / Grid.CELL).round())
	size = Vector2i((bounds.size / Grid.CELL).round()).max(Vector2i.ONE)
	level.register(self, get_cells(cell), realm)
	level.realm_changed.connect(func(_r): _refresh())
	_refresh()

func can_interact(dir: Vector2i) -> bool:
	if player_on_walkway():
		return false
	return super.can_interact(dir)

# Same as Pushable.try_push, but tweens by one cell instead of to
# cell_to_pos(cell), since the origin may not be the footprint's top-left.
func try_push(dir: Vector2i) -> bool:
	if not can_push(dir):
		return false
	level.unregister(self, realm)
	cell += dir
	level.register(self, get_cells(cell), realm)
	moving = true
	var tween := create_tween()
	tween.tween_property(self, "position", position + Vector2(dir * Grid.CELL), 0.12)
	tween.tween_callback(func(): moving = false)
	return true

# ---------- geometry (all in level space) ----------

func level_transform() -> Transform2D:
	return level.global_transform.affine_inverse() * global_transform

func entrance_origin() -> Vector2:
	return level_transform().origin

# Unit vector pointing from the entrance toward the far end.
func forward_axis() -> Vector2:
	return level_transform().x.normalized()

func side_axis() -> Vector2:
	return level_transform().y.normalized()

func length_px() -> float:
	return base_size.x * Grid.CELL * level_transform().x.length()

func width_px() -> float:
	return base_size.y * Grid.CELL * level_transform().y.length()

func footprint_rect() -> Rect2:
	var xf := level_transform()
	var extent := Vector2(base_size * Grid.CELL)
	var rect := Rect2(xf * Vector2.ZERO, Vector2.ZERO)
	for corner in [Vector2(extent.x, 0.0), Vector2(0.0, extent.y), extent]:
		rect = rect.expand(xf * corner)
	return rect

func covers_cell(c: Vector2i) -> bool:
	return get_cells(cell).has(c)

# (along, across) coordinates of a point relative to the entrance corner.
func _local_coords(p: Vector2) -> Vector2:
	var d := p - entrance_origin()
	return Vector2(d.dot(forward_axis()), d.dot(side_axis()))

func _overlaps(center: Vector2, half: float) -> bool:
	var body := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
	return body.intersects(footprint_rect())

# True when a body centred here sits in the walkable lane: inside the entrance
# margins across the width, and not past walkable_depth along the length.
func _in_walk_lane(center: Vector2, half: float) -> bool:
	var uv := _local_coords(center)
	var w := width_px()
	return (
		uv.x + half <= length_px() * walkable_depth
		and uv.y >= w * entrance_margin
		and uv.y <= w * (1.0 - entrance_margin)
	)

# Called from the player's collision query. False = let the body through.
# Walls off everything except the walk lane, in either realm, so the object can
# be stepped onto and pushed from both the physical and dream views.
func blocks_body(center: Vector2, half: float) -> bool:
	if not _overlaps(center, half):
		return false
	return not _in_walk_lane(center, half)

func body_on_walkway(center: Vector2, half: float) -> bool:
	return _overlaps(center, half) and _in_walk_lane(center, half)

func player_on_walkway() -> bool:
	if level == null or level.player == null:
		return false
	var p := level.player
	return body_on_walkway(p.position, p.hitbox_half())

# ---------- roommate hooks (overridden by subclasses) ----------

# True = the roommate can't advance while standing on this object.
func holds_roommate(_roommate: Node2D) -> bool:
	return false

# Non-empty string = the roommate dies with that reason.
func roommate_hazard(_roommate: Node2D) -> String:
	return ""

# ---------- visuals ----------

func _sprites() -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			result.append(child)
	return result

# Same realm fading rules as Pushable, but for any Sprite2D/AnimatedSprite2D.
func _refresh() -> void:
	if level == null:
		return
	for sprite in _sprites():
		if level.realm == realm:
			sprite.visible = true
			sprite.modulate.a = 1.0
		elif realm == LevelBase.Realm.PHYSICAL:
			sprite.visible = true
			sprite.modulate.a = 0.35
		else:
			sprite.visible = false
	queue_redraw()

# Pushable._draw assumes an unscaled top-left origin; draw in the local frame
# instead, and only when there's no sprite.
func _draw() -> void:
	if level == null or not _sprites().is_empty():
		return
	var rect := Rect2(Vector2.ZERO, Vector2(base_size * Grid.CELL))
	if level.realm == realm:
		draw_rect(rect, color)
	elif realm == LevelBase.Realm.PHYSICAL:
		draw_rect(rect, Color(color, 0.35))
