extends Area2D

# Emitted when the first player enters — key turns on.
signal key_collected
# Emitted when the last player leaves — key turns off.
signal key_released

# Count of how many players are currently touching the key.
var _player_count: int = 0


func _ready() -> void:
	$Detection.body_entered.connect(_on_body_entered)
	$Detection.body_exited.connect(_on_body_exited)
	_set_on(false)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_count += 1
	if _player_count == 1:
		# First player arrived — turn on.
		_set_on(true)
		key_collected.emit()


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_count = maxi(_player_count - 1, 0)
	if _player_count == 0:
		# Last player left — turn off.
		_set_on(false)
		key_released.emit()


func _set_on(active: bool) -> void:
	$On.visible = active
	$Off.visible = not active
