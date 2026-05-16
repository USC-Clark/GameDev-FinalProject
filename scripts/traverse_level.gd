extends Node2D

@export var action_limit: int = 12


func _ready() -> void:
	# Wire Key → Door if both exist in this level.
	var key := get_node_or_null("Key")
	var door := get_node_or_null("Door")
	if key != null and door != null:
		if key.has_signal("key_collected"):
			key.key_collected.connect(door.open_door)
		if key.has_signal("key_released"):
			key.key_released.connect(door.close_door)

	# When the player walks into the open door, load the next level.
	if door != null and door.has_signal("player_exited"):
		door.player_exited.connect(_on_door_exit)

	# Wire Killzone — any player touching it resets the level instantly.
	var killzone := get_node_or_null("Killzone")
	if killzone is Area2D:
		killzone.body_entered.connect(_on_killzone_body_entered)


func _on_killzone_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var manager := _find_manager()
	if manager and manager.has_method("_reset_level"):
		manager._reset_level("Fell into the void! Reset.")


func _on_door_exit() -> void:
	var manager := _find_manager()
	if manager == null:
		return
	Progress.complete_traverse_level(GameState.selected_traverse_level)
	# Show the completion panel instead of loading immediately.
	if manager.has_method("_show_complete"):
		manager._show_complete()
	else:
		manager.call_deferred("_load_level", GameState.selected_traverse_level)


func _find_manager() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("_load_level"):
			return node
		node = node.get_parent()
	return null
