extends "res://scripts/traverse_level.gd"


func _ready() -> void:
	super._ready()  # Runs base wiring: Key→Door, Door exit, Killzone

	var key2 := get_node_or_null("Key2")
	var platform := get_node_or_null("Platform1")

	if platform != null:
		# Disable StandDetect so the platform only responds to Key2, not player weight.
		var detect := platform.get_node_or_null("StandDetect")
		if detect is Area2D:
			detect.monitoring = false

	# Key2 controls Platform1 only — activate when held, deactivate when released.
	if key2 != null and platform != null:
		if platform.has_method("activate"):
			key2.key_collected.connect(platform.activate)
			key2.key_released.connect(platform.deactivate)
