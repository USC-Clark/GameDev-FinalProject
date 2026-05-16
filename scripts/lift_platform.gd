extends AnimatableBody2D

@export var move_distance: float = 300.0
@export var speed: float = 120.0
# Direction of movement: Vector2(0,-1) = up (default), Vector2(1,0) = right, Vector2(-1,0) = left
@export var move_direction: Vector2 = Vector2(0, -1)
# When true the platform bounces back and forth continuously while a player is on it.
@export var auto_bounce: bool = false

enum State { IDLE, GOING_UP, UP, GOING_DOWN }

var _state: State = State.IDLE
var _start: Vector2
var _end: Vector2
var _player_count: int = 0


func _ready() -> void:
	sync_to_physics = false
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_to_group("lift")  # lets the level manager find and reset this platform

	_start = position
	_end = position + move_direction.normalized() * move_distance

	# StandDetect is optional — only used when the platform self-activates.
	var detect := get_node_or_null("StandDetect")
	if detect is Area2D:
		detect.collision_mask = 1
		detect.monitoring = true
		detect.body_entered.connect(_on_body_entered)
		detect.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_count += 1
	if _player_count == 1:
		activate()
	elif _player_count > 1:
		deactivate()


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_count = maxi(_player_count - 1, 0)
	if _player_count == 0:
		deactivate()
	elif _player_count == 1:
		activate()


func activate() -> void:
	if _state == State.IDLE or _state == State.GOING_DOWN:
		_state = State.GOING_UP


func deactivate() -> void:
	if _state == State.UP or _state == State.GOING_UP:
		_state = State.GOING_DOWN


func _physics_process(delta: float) -> void:
	match _state:
		State.GOING_UP:
			var remaining := _end - position
			var step := speed * delta
			if remaining.length() <= step:
				position = _end
				# In bounce mode with a player on it — reverse immediately.
				if auto_bounce and _player_count > 0:
					_state = State.GOING_DOWN
				else:
					_state = State.UP
			else:
				move_and_collide(remaining.normalized() * step)

		State.GOING_DOWN:
			var remaining := _start - position
			var step := speed * delta
			if remaining.length() <= step:
				position = _start
				# In bounce mode with a player on it — reverse immediately.
				if auto_bounce and _player_count > 0:
					_state = State.GOING_UP
				else:
					_state = State.IDLE
			else:
				move_and_collide(remaining.normalized() * step)


func reset_to_initial() -> void:
	position = _start
	_state = State.IDLE
	_player_count = 0
