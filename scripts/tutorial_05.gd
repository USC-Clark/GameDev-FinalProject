extends Node2D

@export var action_limit: int = 15


func _ready() -> void:
	$Key.key_collected.connect($Door.open_door)
	$Key.key_released.connect($Door.close_door)
