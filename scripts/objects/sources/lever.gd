class_name Lever
extends "res://scripts/objects/sources/signal_source.gd"

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _interact_sfx: AudioStreamPlayer2D = $InteractSfx

func _ready() -> void:
	manually_toggleable = true
	turned_on.connect(_update_sprite)
	turned_off.connect(_update_sprite)
	toggled.connect(_play_interaction_sfx)
	super._ready()
	_update_sprite()

func _play_interaction_sfx() -> void:
	_interact_sfx.play()

func _update_sprite() -> void:
	var frame_x := 32.0 if is_on else 0.0
	_sprite.region_rect.position.x = frame_x
