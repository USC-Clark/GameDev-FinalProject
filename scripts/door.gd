extends AnimatableBody2D

# Emitted when the player physically walks into the open door.
signal player_exited


func _ready() -> void:
	$ExitArea.body_entered.connect(_on_exit_body_entered)


func _on_exit_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_exited.emit()


# Call this when the key is collected — opens the door and arms the exit trigger.
func open_door() -> void:
	$Close.visible = false
	$Open.visible = true
	$CollisionShape2D.set_deferred("disabled", true)
	# Enable the exit area so the player can now walk through.
	$ExitArea.set_deferred("monitoring", true)


# Call this to reset the door back to closed (e.g. on level reset).
func close_door() -> void:
	$Close.visible = true
	$Open.visible = false
	$CollisionShape2D.set_deferred("disabled", false)
	$ExitArea.set_deferred("monitoring", false)
