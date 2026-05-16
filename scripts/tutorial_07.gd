extends Node2D

@export var action_limit: int = 20


func _ready() -> void:
	# Key opens ALL doors while held, closes them when released.
	$Key.key_collected.connect(_on_key_collected)
	$Key.key_released.connect(_on_key_released)

	# Door2 is the correct exit — leads to tutorial_08.
	$Door2.player_exited.connect(_on_exit_door_entered)

	# Door1 and Door3 are traps — entering them respawns the player.
	$Door1.player_exited.connect(_on_trap_door_entered)
	$Door3.player_exited.connect(_on_trap_door_entered)


func _on_key_collected() -> void:
	$Door1.open_door()
	$Door2.open_door()
	$Door3.open_door()


func _on_key_released() -> void:
	$Door1.close_door()
	$Door2.close_door()
	$Door3.close_door()


func _on_exit_door_entered() -> void:
	var manager := _find_manager()
	if manager == null:
		return
	Progress.complete_tutorial_level(7)
	if manager.has_method("_on_door_opened_as_exit"):
		manager._on_door_opened_as_exit()


func _on_trap_door_entered() -> void:
	var manager := _find_manager()
	if manager and manager.has_method("_reset_level"):
		manager._reset_level("Wrong door! Try again.")


func _find_manager() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("_reset_level"):
			return node
		node = node.get_parent()
	return null
