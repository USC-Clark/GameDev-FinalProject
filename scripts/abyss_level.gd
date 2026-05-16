extends Node2D

## Abyss mode level root script.
## Tighter action limits and a Killzone that resets on any contact.
@export var action_limit: int = 8


func _ready() -> void:
	# Wire Key → Door if both exist.
	var key := get_node_or_null("Key")
	var door := get_node_or_null("Door")
	if key != null and door != null:
		if key.has_signal("key_collected"):
			key.key_collected.connect(door.open_door)
		if key.has_signal("key_released"):
			key.key_released.connect(door.close_door)

	if door != null and door.has_signal("player_exited"):
		door.player_exited.connect(_on_door_exit)

	# Wire Key2 → Platform1 (standing on Key2 raises Platform1, leaving lowers it).
	var key2 := get_node_or_null("Key2")
	var platform1 := get_node_or_null("Platform1")
	if key2 != null and platform1 != null:
		if key2.has_signal("key_collected") and platform1.has_method("activate"):
			key2.key_collected.connect(platform1.activate)
		if key2.has_signal("key_released") and platform1.has_method("deactivate"):
			key2.key_released.connect(platform1.deactivate)
		# Disable the stand-on trigger so only Key2 controls this platform.
		var stand_detect := platform1.get_node_or_null("StandDetect")
		if stand_detect is Area2D:
			(stand_detect as Area2D).monitoring = false

	var killzone := get_node_or_null("Killzone")
	if killzone is Area2D:
		killzone.body_entered.connect(_on_killzone_body_entered)


func _on_killzone_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var manager := _find_manager()
	if manager and manager.has_method("_reset_level"):
		manager._reset_level("Fell into the abyss! Reset.")


func _on_door_exit() -> void:
	var manager := _find_manager()
	if manager == null:
		return
	Progress.complete_abyss_level(GameState.selected_abyss_level)
	if manager.has_method("_show_complete"):
		manager._show_complete()
	else:
		manager.call_deferred("_load_level", GameState.selected_abyss_level)


func _find_manager() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("_load_level"):
			return node
		node = node.get_parent()
	return null
