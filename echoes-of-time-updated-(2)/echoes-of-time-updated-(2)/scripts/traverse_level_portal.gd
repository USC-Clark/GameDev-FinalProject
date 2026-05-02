# traverse_level_portal.gd
# Extended version of traverse_level that supports portal exits
extends Node2D

@export var action_limit: int = 12

@onready var _exit_portal: Node2D = null

func _ready() -> void:
	# Find the exit portal if it exists
	_exit_portal = get_node_or_null("ExitPortal")
	
	if _exit_portal == null:
		# Try to find any portal set as Exit type
		for child in get_children():
			if child.has_method("get") and child.get("portal_type") == "Exit":
				_exit_portal = child
				break
	
	# Connect portal signal if found
	if _exit_portal != null and _exit_portal.has_signal("level_exit_triggered"):
		_exit_portal.level_exit_triggered.connect(_on_portal_exit_triggered)


func _on_portal_exit_triggered(body: Node2D) -> void:
	# This signal will be picked up by the tutorial manager
	# The manager should connect to this or check for portal completion
	print("Portal exit triggered by: ", body.name)
