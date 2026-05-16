extends Node2D

@export var action_limit: int = 15


func _ready() -> void:
	$Key.key_collected.connect($Door.open_door)
	$Key.key_released.connect($Door.close_door)

	# Platform moves side to side when player stands on it (standby mode).
	# move_direction is set to horizontal on the Platform instance in the scene.

	# Killzone — any player that enters gets reset to spawn.
	var killzone := get_node_or_null("Killzone")
	if killzone is Area2D:
		killzone.body_entered.connect(_on_killzone_body_entered)


func _on_killzone_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		# Find the tutorial manager and trigger a level reset.
		var manager := _find_manager()
		if manager and manager.has_method("_reset_level"):
			manager._reset_level("You fell! Respawning...")


func _find_manager() -> Node:
	# The manager is the parent of the World node that contains this level.
	var node := get_parent()
	while node != null:
		if node.has_method("_reset_level"):
			return node
		node = node.get_parent()
	return null
