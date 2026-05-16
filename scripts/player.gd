extends CharacterBody2D

signal action_used(current_actions: int, limit: int)
signal action_limit_exceeded
signal recording_toggled(is_recording: bool)
signal recording_finished(recorded_frames: Array[Dictionary])

@export var move_speed: float = 260.0
@export var acceleration: float = 1200.0
@export var friction: float = 1400.0
@export var jump_velocity: float = -600.0
@export var gravity: float = 1100.0
@export var burst_duration: float = 0.16
@export var step_distance_px: float = 96.0
@export var drop_through_seconds: float = 0.18

const ONE_WAY_PLATFORM_LAYER: int = 5

var spawn_position: Vector2 = Vector2.ZERO
var action_limit: int = 8
var actions_used: int = 0

var _is_recording: bool = false
var _recorded_frames: Array[Dictionary] = []

var _move_direction: float = 0.0
var _move_timer: float = 0.0
var _step_target_x: float = 0.0
var _is_stepping: bool = false
var _drop_timer: float = 0.0
var _last_position: Vector2 = Vector2.ZERO
var _stuck_timer: float = 0.0
const _STUCK_THRESHOLD: float = 0.3

# Input buffers — store presses for up to N seconds so touch events
# arriving between physics ticks are never silently dropped.
const _INPUT_BUFFER_TIME := 0.12
var _buf_left: float = 0.0
var _buf_right: float = 0.0
var _buf_jump: float = 0.0
var _buf_down: float = 0.0

@onready var animated_sprite: AnimatedSprite2D = $Original
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var dash_sound: AudioStreamPlayer2D = $DashSound

const _SNAP_RAY_LENGTH: float = 2400.0
const _ECHO_TINT: Color = Color(0.5, 0.5, 0.5, 1.0)

var _default_collision_layer: int = 1
var _default_collision_mask: int = 20


func _ready() -> void:
	add_to_group("time_actor")
	add_to_group("player")

	_default_collision_layer = collision_layer
	_default_collision_mask = collision_mask

	if animated_sprite != null and animated_sprite.sprite_frames != null:
		# Default appearance (non-recording).
		animated_sprite.modulate = Color(1, 1, 1, 1)

		if animated_sprite.sprite_frames.has_animation("record"):
			animated_sprite.sprite_frames.set_animation_loop("record", false)
		# Keep movement animations visible.
		if animated_sprite.sprite_frames.has_animation("Dash"):
			animated_sprite.sprite_frames.set_animation_loop("Dash", true)
		if not animated_sprite.animation_finished.is_connected(_on_original_animation_finished):
			animated_sprite.animation_finished.connect(_on_original_animation_finished)

		# Some scenes may have been saved with "record" selected; force a sane idle start.
		if animated_sprite.sprite_frames.has_animation("idle") and animated_sprite.animation == "record" and not _is_recording:
			animated_sprite.play("idle")


func setup(spawn: Vector2, limit: int) -> void:
	spawn_position = spawn
	action_limit = limit
	actions_used = 0
	global_position = spawn_position
	velocity = Vector2.ZERO
	_restore_collision_defaults()
	_snap_to_floor()
	emit_signal("action_used", actions_used, action_limit)


func _physics_process(delta: float) -> void:
	# Tick down input buffers.
	_buf_left  = maxf(_buf_left  - delta, 0.0)
	_buf_right = maxf(_buf_right - delta, 0.0)
	_buf_jump  = maxf(_buf_jump  - delta, 0.0)
	_buf_down  = maxf(_buf_down  - delta, 0.0)

	# Fill buffers on fresh presses.
	if Input.is_action_just_pressed("move_left"):  _buf_left  = _INPUT_BUFFER_TIME
	if Input.is_action_just_pressed("move_right"): _buf_right = _INPUT_BUFFER_TIME
	if Input.is_action_just_pressed("jump"):       _buf_jump  = _INPUT_BUFFER_TIME
	if Input.is_action_just_pressed("move_down"):  _buf_down  = _INPUT_BUFFER_TIME

	var left_pressed  := _buf_left  > 0.0
	var right_pressed := _buf_right > 0.0
	var jump_pressed  := _buf_jump  > 0.0
	var down_pressed  := _buf_down  > 0.0

	# Consume buffers so they only trigger once per press.
	if left_pressed:  _buf_left  = 0.0
	if right_pressed: _buf_right = 0.0
	if jump_pressed:  _buf_jump  = 0.0
	if down_pressed:  _buf_down  = 0.0

	_process_move_press(left_pressed, right_pressed)
	_consume_action_inputs(left_pressed, right_pressed, jump_pressed)
	_try_drop_through(down_pressed)
	_apply_motion(delta, jump_pressed)
	_refresh_actions_if_at_spawn()

	_update_sprite_flip_from_velocity()
	_update_sprite_state()
	_last_position = global_position

	if _is_recording:
		_recorded_frames.append({
			"position": global_position,
			"velocity": velocity,
			"is_dashing": _is_stepping,
			"flip_h": (animated_sprite.flip_h if animated_sprite != null else false),
		})


func _process_move_press(left_pressed: bool, right_pressed: bool) -> void:
	if left_pressed:
		_move_direction = -1.0
		_move_timer = burst_duration
		_step_target_x = global_position.x - step_distance_px
		_is_stepping = true
		_play_dash_sound()
	elif right_pressed:
		_move_direction = 1.0
		_move_timer = burst_duration
		_step_target_x = global_position.x + step_distance_px
		_is_stepping = true
		_play_dash_sound()


func _consume_action_inputs(left_pressed: bool, right_pressed: bool, jump_pressed: bool) -> void:
	if left_pressed:
		_use_action()
	if right_pressed:
		_use_action()
	if jump_pressed:
		_use_action()


func _apply_motion(delta: float, jump_pressed: bool) -> void:
	_update_drop_through(delta)

	if _is_stepping:
		var remaining := _step_target_x - global_position.x
		var dur := maxf(0.001, burst_duration)
		var step_speed := step_distance_px / dur
		var dir := signf(remaining)
		velocity.x = dir * step_speed
		if absf(remaining) <= step_speed * delta:
			global_position.x = _step_target_x
			velocity.x = 0.0
			_is_stepping = false
			_move_timer = 0.0
		else:
			# Detect if stuck against a wall — position hasn't changed.
			if global_position.distance_to(_last_position) < 1.0:
				_stuck_timer += delta
				if _stuck_timer >= _STUCK_THRESHOLD:
					velocity.x = 0.0
					_is_stepping = false
					_move_timer = 0.0
					_stuck_timer = 0.0
			else:
				_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0
		# Keep horizontal momentum while airborne so jumps feel smooth.
		# Only kill horizontal velocity when grounded and not stepping.
		if is_on_floor():
			velocity.x = 0.0

	if not is_on_floor():
		velocity.y += gravity * delta
	elif jump_pressed:
		velocity.y = jump_velocity
		_play_jump_sound()

	move_and_slide()


func _try_drop_through(down_pressed: bool) -> void:
	if not down_pressed:
		return
	if not is_on_floor():
		return
	_drop_timer = drop_through_seconds
	set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, false)
	global_position.y += 2.0


func _update_drop_through(delta: float) -> void:
	if _drop_timer <= 0.0:
		set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)
		return
	_drop_timer = maxf(0.0, _drop_timer - delta)
	if _drop_timer == 0.0:
		set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)


func start_recording() -> void:
	_is_recording = true
	_recorded_frames.clear()
	emit_signal("recording_toggled", true)
	print("Recording started")

	# Match the replay ghost's look while recording.
	if animated_sprite != null:
		animated_sprite.modulate = _ECHO_TINT

	if animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("record"):
		if animated_sprite.animation != "record":
			animated_sprite.play("record")


func stop_recording() -> Array[Dictionary]:
	if not _is_recording:
		return []
	_is_recording = false
	emit_signal("recording_toggled", false)
	emit_signal("recording_finished", _recorded_frames.duplicate(true))
	print("Recording stopped - frames: ", _recorded_frames.size())

	# Restore normal look after recording ends.
	if animated_sprite != null:
		animated_sprite.modulate = Color(1, 1, 1, 1)
	_restore_collision_defaults()
	add_to_group("player")

	return _recorded_frames.duplicate(true)


func cancel_recording() -> void:
	_is_recording = false
	_recorded_frames.clear()
	emit_signal("recording_toggled", false)
	if animated_sprite != null:
		animated_sprite.modulate = Color(1, 1, 1, 1)
	_restore_collision_defaults()
	add_to_group("player")


func is_recording() -> bool:
	return _is_recording


func reset_to_spawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_restore_collision_defaults()
	_snap_to_floor()
	actions_used = 0
	_move_direction = 0.0
	_move_timer = 0.0
	_is_stepping = false
	_step_target_x = global_position.x
	_stuck_timer = 0.0
	_buf_left = 0.0
	_buf_right = 0.0
	_buf_jump = 0.0
	_buf_down = 0.0
	emit_signal("action_used", actions_used, action_limit)


func _use_action() -> void:
	actions_used += 1
	emit_signal("action_used", actions_used, action_limit)
	if actions_used > action_limit:
		emit_signal("action_limit_exceeded")


func _refresh_actions_if_at_spawn() -> void:
	if global_position.distance_to(spawn_position) <= 6.0 and actions_used != 0:
		actions_used = 0
		emit_signal("action_used", actions_used, action_limit)


func _update_sprite_flip_from_velocity() -> void:
	if animated_sprite == null:
		return
	if velocity.x == 0.0:
		return
	animated_sprite.flip_h = velocity.x < 0.0


func _update_sprite_state() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	# If the one-shot record animation is currently playing, don't override it.
	if animated_sprite.animation == "record" and animated_sprite.is_playing():
		return

	var desired: String = "Dash" if _is_stepping else "idle"
	if animated_sprite.sprite_frames.has_animation(desired) and animated_sprite.animation != desired:
		animated_sprite.play(desired)


func _on_original_animation_finished() -> void:
	if animated_sprite == null:
		return
	if animated_sprite.animation == "record":
		if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")


func _snap_to_floor() -> void:
	# Intentionally disabled — the Spawn marker defines the exact spawn position.
	# Snapping caused players to land on the wrong floor when spawning above platforms.
	pass


func _restore_collision_defaults() -> void:
	# Some actions (drop-through) temporarily disable a collision mask bit.
	# Ensure the player is always detectable by Areas/doors/plates after recording/resets.
	# Doors/gates/plates in this project generally mask against layer 1.
	collision_layer = 1
	collision_mask = _default_collision_mask if _default_collision_mask != 0 else 20
	set_collision_layer_value(1, true)
	set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)


# ── Sound Effects ────────────────────────────────────────────

func _play_jump_sound() -> void:
	if jump_sound != null and not jump_sound.playing:
		jump_sound.play()


func _play_dash_sound() -> void:
	if dash_sound != null and not dash_sound.playing:
		dash_sound.play()
