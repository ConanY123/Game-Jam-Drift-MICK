class_name RealmMinimap
extends Control

const VIEW_SIZE := Vector2i(5, 3)
const CELL_SIZE := 32
const VIEW_ORIGIN := Vector2(32.0, 24.0)
const VIEW_PIXELS := Vector2i(VIEW_SIZE.x * CELL_SIZE, VIEW_SIZE.y * CELL_SIZE)
const PANEL_SIZE := Vector2(224.0, 128.0)

var _level: LevelBase
var _viewport: SubViewport
var _viewport_container: SubViewportContainer
var _mirror_root: Node2D
var _camera: Camera2D
var _mirror_nodes: Dictionary = {}
var _opposite_realm := LevelBase.Realm.DREAM

func setup(level: LevelBase) -> void:
	_level = level
	if not level.realm_changed.is_connected(_on_realm_changed):
		level.realm_changed.connect(_on_realm_changed)
	_rebuild_mirror()

func _on_realm_changed(_new_realm: int) -> void:
	_rebuild_mirror()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	if _level == null or _camera == null or _level.roommate == null:
		return
	_camera.position = _level.roommate.position
	for source in _mirror_nodes:
		var mirror: Node2D = _mirror_nodes[source]
		if is_instance_valid(source) and is_instance_valid(mirror):
			_sync_mirror_node(source, mirror)

func _draw() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.16, 0.9)
	panel_style.border_color = Color(0.55, 0.5, 0.95, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(6)
	draw_style_box(panel_style, Rect2(Vector2.ZERO, PANEL_SIZE))
	draw_string(
		ThemeDB.fallback_font,
		Vector2(12.0, 18.0),
		"OTHER REALM",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color(0.92, 0.88, 1.0)
	)

func _rebuild_mirror() -> void:
	if _viewport_container != null:
		_viewport_container.queue_free()
		_viewport_container = null
		_viewport = null
		_mirror_root = null
		_camera = null
		_mirror_nodes.clear()
	if _level == null or _level.roommate == null:
		return

	_viewport_container = SubViewportContainer.new()
	_viewport_container.position = VIEW_ORIGIN
	_viewport_container.size = Vector2(VIEW_PIXELS)
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.stretch = false
	add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = VIEW_PIXELS
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport_container.add_child(_viewport)

	_mirror_root = Node2D.new()
	_viewport.add_child(_mirror_root)
	_camera = Camera2D.new()
	_camera.position = _level.roommate.position
	_camera.enabled = true
	_mirror_root.add_child(_camera)

	var opposite := (
		LevelBase.Realm.DREAM
		if _level.realm == LevelBase.Realm.PHYSICAL
		else LevelBase.Realm.PHYSICAL
	)
	_opposite_realm = opposite
	_copy_level_layers(opposite)
	_copy_level_visuals(opposite)

func _copy_level_layers(opposite: int) -> void:
	for child in _level.get_children():
		if not child is TileMapLayer:
			continue
		var layer := child as TileMapLayer
		var copy := layer.duplicate() as TileMapLayer
		if copy == null:
			continue
		copy.visible = _layer_is_visible_in_realm(layer.name, opposite)
		_mirror_root.add_child(copy)
		if layer.name == "WallLayer":
			_rebuild_wall_layer(copy, opposite)

func _layer_is_visible_in_realm(layer_name: String, opposite: int) -> bool:
	if layer_name == "FloorLayer":
		return opposite == LevelBase.Realm.PHYSICAL
	if layer_name == "DreamFloorLayer":
		return opposite == LevelBase.Realm.DREAM
	return true

func _rebuild_wall_layer(layer: TileMapLayer, opposite: int) -> void:
	var wall_cells: Dictionary = _level.get("_wall_cells")
	if wall_cells == null:
		return
	layer.clear()
	var wall_source := (
		_level.DREAM_WALL_SOURCE_ID
		if opposite == LevelBase.Realm.DREAM
		else _level.PHYSICAL_WALL_SOURCE_ID
	)
	for cell in wall_cells:
		var data: Array = wall_cells[cell]
		var atlas_coords: Vector2i = data[1]
		var original_source: int = data[0]
		if original_source == 2 or original_source == 3:
			atlas_coords += _level.MERGED_WALL_ATLAS_OFFSET
		layer.set_cell(cell, wall_source, atlas_coords, data[2])

func _copy_level_visuals(opposite: int) -> void:
	for child in _level.get_children():
		if (
			child == _level.player
			or child is TileMapLayer
			or child is CanvasLayer
			or child is Path2D
		):
			continue
		if child == _level.roommate:
			_copy_visual_tree(child, _mirror_root, opposite)
			continue
		if child is Sprite2D and child.name in ["PhysicalBackground", "DreamBackground"]:
			var background := child.duplicate() as Sprite2D
			background.visible = (
				child.name == "DreamBackground"
				and opposite == LevelBase.Realm.DREAM
			) or (
				child.name == "PhysicalBackground"
				and opposite == LevelBase.Realm.PHYSICAL
			)
			_mirror_root.add_child(background)
			continue
		_copy_visual_tree(child, _mirror_root, opposite)

func _copy_visual_tree(source: Node, parent: Node, opposite: int) -> void:
	var visual_root := Node2D.new()
	visual_root.name = source.name
	if source is Node2D:
		visual_root.transform = source.transform
		visual_root.visible = source.visible
	if source.name == "Physical":
		visual_root.modulate.a = 1.0 if opposite == LevelBase.Realm.PHYSICAL else 0.35
	elif source.name == "Dream":
		visual_root.visible = opposite == LevelBase.Realm.DREAM
	parent.add_child(visual_root)
	_mirror_nodes[source] = visual_root
	_sync_mirror_node(source, visual_root)

	var source_realm: Variant = source.get("realm")
	if source_realm != null and source_realm is int:
		if int(source_realm) == LevelBase.Realm.DREAM:
			visual_root.visible = opposite == LevelBase.Realm.DREAM
		elif opposite == LevelBase.Realm.DREAM:
			visual_root.modulate.a = 0.35

	for child in source.get_children():
		if child is Sprite2D or child is AnimatedSprite2D or child is Polygon2D or child is Line2D:
			visual_root.add_child(child.duplicate())
		elif child is Node2D or child.get_child_count() > 0:
			_copy_visual_tree(child, visual_root, opposite)

func _sync_mirror_node(source: Node, mirror: Node2D) -> void:
	if source is Node2D:
		mirror.transform = source.transform
	if source is CanvasItem:
		mirror.visible = source.visible
		if source.name == "Physical":
			mirror.visible = true
			mirror.modulate.a = 1.0 if _opposite_realm == LevelBase.Realm.PHYSICAL else 0.35
		elif source.name == "Dream":
			mirror.visible = _opposite_realm == LevelBase.Realm.DREAM
		var source_realm: Variant = source.get("realm")
		if source_realm != null and source_realm is int:
			if int(source_realm) == LevelBase.Realm.DREAM:
				mirror.visible = _opposite_realm == LevelBase.Realm.DREAM
			elif _opposite_realm == LevelBase.Realm.DREAM:
				mirror.modulate.a = 0.35
