extends Node2D

@export var action_limit: int = 15


func _ready() -> void:
	$Key.key_collected.connect($Door.open_door)
	$Key.key_released.connect($Door.close_door)

	# Platform self-activates when player stands on it (via StandDetect area).

	# Gate opens when player stands on GatePlate, closes when they leave.
	# (Wiring is handled automatically via the GatePlate's "gate" export property.)
