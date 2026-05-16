extends Node2D


func _ready() -> void:
	$Key.key_collected.connect($Door.open_door)
	$Key.key_released.connect($Door.close_door)
