class_name SlidingCart
extends Slidable

@export_enum("Horizontal", "Vertical") var orientation := 0


func _ready() -> void:
	_update_orientation()
	super._ready()


func _update_orientation() -> void:
	var horizontal := orientation == 0
	size = Vector2i(2, 1) if horizontal else Vector2i(1, 2)

	var footprint_size := Vector2(size * Grid.CELL)
	var center := footprint_size * 0.5
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite != null:
		sprite.position = center
		sprite.rotation = 0.0 if horizontal else PI * 0.5

	var collision_shape := get_node_or_null("StaticBody2D/CollisionShape2D") as CollisionShape2D
	if collision_shape != null:
		var rectangle := collision_shape.shape as RectangleShape2D
		if rectangle == null:
			push_error("SlidingCart CollisionShape2D must use a RectangleShape2D.")
			return
		var instance_rectangle := rectangle.duplicate() as RectangleShape2D
		collision_shape.shape = instance_rectangle
		instance_rectangle.size = footprint_size - Vector2(4.0, 4.0)
		collision_shape.position = center
