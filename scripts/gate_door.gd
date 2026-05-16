extends AnimatableBody2D

signal gate_opened
signal gate_closed

@onready var _close_sprite: Sprite2D = $Closegate
@onready var _open_sprite: Sprite2D = $Opengate
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	# Gate must block the player — layer 8 matches the tilemap, mask 0 (static).
	collision_layer = 8
	collision_mask = 0
	# sync_to_physics must be off — gate is moved via script, not physics engine.
	sync_to_physics = false
	_set_open(false)


func open_gate() -> void:
	_set_open(true)


func close_gate() -> void:
	_set_open(false)


func _set_open(open: bool) -> void:
	_close_sprite.visible = not open
	_open_sprite.visible = open
	if _collision != null:
		_collision.set_deferred("disabled", open)
	if open:
		emit_signal("gate_opened")
	else:
		emit_signal("gate_closed")
