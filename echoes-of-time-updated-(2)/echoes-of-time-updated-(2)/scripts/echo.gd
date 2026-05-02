extends CharacterBody2D

@export var playback_speed: float = 1.35 # 1.0 = normal, >1 = faster

var _frames: Array[Dictionary] = []
var _index: int = 0
var _playback_done: bool = false
var _started: bool = false
var _playback_accum: float = 0.0
var _anim_idle: String = "idle2"
var _anim_dash: String = "Dash2"
var _anim_record: String = "record2"
var _last_was_dashing: bool = false
var _was_on_ground: bool = true

# Scene node is named "Pastself" (moved from player.tscn to echo.tscn).
@onready var echo_sprite: AnimatedSprite2D = $Pastself
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var dash_sound: AudioStreamPlayer2D = $DashSound

const SPRITESHEET_PATH: String = "res://Sprite/SPRITE_SHEET.png"
const FRAME_SIZE: int = 32
const _SNAP_RAY_LENGTH: float = 2400.0


func _ready() -> void:
	add_to_group("time_actor")
	add_to_group("player")
	if echo_sprite != null:
		echo_sprite.modulate = Color(0.5, 0.5, 0.5, 1.0)
		_build_sprite_frames_if_needed()
		_resolve_animation_names()
		_apply_animation_loop_rules()


func setup(spawn_pos: Vector2, frames: Array[Dictionary]) -> void:
	global_position = spawn_pos
	velocity = Vector2.ZERO
	_snap_to_floor()
	_frames = frames.duplicate(true)
	_index = 0
	_playback_done = false
	_started = false
	_playback_accum = 0.0
	visible = true
	if echo_sprite != null:
		echo_sprite.visible = true
		_build_sprite_frames_if_needed()
		_resolve_animation_names()
		_apply_animation_loop_rules()
		if echo_sprite.sprite_frames != null and echo_sprite.sprite_frames.has_animation(_anim_record):
			echo_sprite.play(_anim_record)
	print("Echo setup - frames: ", _frames.size())


func _physics_process(_delta: float) -> void:
	if _playback_done:
		return
	if _frames.is_empty():
		return

	# Wait for record2 spawn animation to finish playing before advancing frames.
	if not _started:
		if echo_sprite != null and echo_sprite.animation == _anim_record and echo_sprite.is_playing():
			return
		_started = true
		_index = 0

	if _index >= _frames.size():
		_playback_done = true
		if echo_sprite != null and echo_sprite.sprite_frames != null and echo_sprite.sprite_frames.has_animation(_anim_idle):
			if echo_sprite.animation != _anim_idle:
				echo_sprite.play(_anim_idle)
		print("Echo playback DONE - frozen at last position")
		return

	# Advance faster by consuming multiple recorded frames per physics tick.
	_playback_accum += maxf(0.1, playback_speed)
	while _playback_accum >= 1.0 and not _playback_done:
		if _index >= _frames.size():
			_playback_done = true
			break
		_apply_frame(_frames[_index])
		_index += 1
		_playback_accum -= 1.0

	if _playback_done:
		if echo_sprite != null and echo_sprite.sprite_frames != null and echo_sprite.sprite_frames.has_animation(_anim_idle):
			if echo_sprite.animation != _anim_idle:
				echo_sprite.play(_anim_idle)
		print("Echo playback DONE - frozen at last position")


# Compatibility with manager code; no longer drives playback.
func consume_action() -> void:
	pass


func _apply_frame(frame: Dictionary) -> void:
	var old_position: Vector2 = global_position
	global_position = frame.get("position", global_position)
	velocity = frame.get("velocity", Vector2.ZERO)

	if echo_sprite == null:
		return

	echo_sprite.flip_h = bool(frame.get("flip_h", false))
	var dashing: bool = bool(frame.get("is_dashing", false))
	var vel: Vector2 = frame.get("velocity", Vector2.ZERO)

	# Detect dash start (transition from not dashing to dashing)
	if dashing and not _last_was_dashing:
		_play_dash_sound()
	_last_was_dashing = dashing

	# Detect jump (negative Y velocity while was on ground)
	var is_jumping: bool = vel.y < -100.0  # Significant upward velocity
	if is_jumping and _was_on_ground:
		_play_jump_sound()
	
	# Update ground state (simple check: if Y velocity is near zero or positive, likely on ground)
	_was_on_ground = absf(vel.y) < 50.0 or vel.y > 0.0

	# Update animation
	if dashing:
		if echo_sprite.animation != _anim_dash:
			echo_sprite.play(_anim_dash)
	elif vel.length() > 10.0:
		if echo_sprite.animation != _anim_idle:
			echo_sprite.play(_anim_idle)
	else:
		if echo_sprite.animation != _anim_idle:
			echo_sprite.play(_anim_idle)


func _resolve_animation_names() -> void:
	if echo_sprite == null or echo_sprite.sprite_frames == null:
		return
	var sf := echo_sprite.sprite_frames
	# Support renamed animations by picking whichever exists.
	_anim_idle = _pick_existing(sf, ["idle2", "idle", "Idle2", "Idle"])
	_anim_dash = _pick_existing(sf, ["Dash2", "dash2", "Dash", "dash"])
	_anim_record = _pick_existing(sf, ["record2", "record", "Record2", "Record"])


func _pick_existing(sf: SpriteFrames, candidates: Array[String]) -> String:
	for n in candidates:
		if sf.has_animation(n):
			return n
	# Fall back to current animation if present.
	if sf.has_animation(echo_sprite.animation):
		return echo_sprite.animation
	# Last resort: keep first candidate.
	return candidates[0]


func _apply_animation_loop_rules() -> void:
	if echo_sprite == null or echo_sprite.sprite_frames == null:
		return
	var sf := echo_sprite.sprite_frames
	if sf.has_animation(_anim_idle):
		sf.set_animation_loop(_anim_idle, true)
	if sf.has_animation(_anim_dash):
		sf.set_animation_loop(_anim_dash, true)
	if sf.has_animation(_anim_record):
		sf.set_animation_loop(_anim_record, false)


func _build_sprite_frames_if_needed() -> void:
	if echo_sprite == null:
		return
	if echo_sprite.sprite_frames != null and (
		echo_sprite.sprite_frames.has_animation("idle2")
		or echo_sprite.sprite_frames.has_animation("idle")
	) and (
		echo_sprite.sprite_frames.has_animation("Dash2")
		or echo_sprite.sprite_frames.has_animation("Dash")
		or echo_sprite.sprite_frames.has_animation("dash2")
		or echo_sprite.sprite_frames.has_animation("dash")
	) and (
		echo_sprite.sprite_frames.has_animation("record2")
		or echo_sprite.sprite_frames.has_animation("record")
	):
		return

	if not ResourceLoader.exists(SPRITESHEET_PATH):
		return
	var tex_res := load(SPRITESHEET_PATH)
	if tex_res == null or not (tex_res is Texture2D):
		return
	var tex: Texture2D = tex_res as Texture2D

	var idle_regions: Array[Rect2] = []
	for x in [0, 32, 64, 96, 128, 160]:
		idle_regions.append(Rect2(x, 0, FRAME_SIZE, FRAME_SIZE))
	var dash_regions: Array[Rect2] = []
	for x in [0, 32, 64, 96, 128, 160]:
		dash_regions.append(Rect2(x, 256, FRAME_SIZE, FRAME_SIZE))
	var record_regions: Array[Rect2] = []
	for x in [0, 32, 64, 96, 128, 160, 192, 224, 256, 288]:
		record_regions.append(Rect2(x, 192, FRAME_SIZE, FRAME_SIZE))

	var frames := SpriteFrames.new()
	# Default names for dynamically built frames (used only if scene doesn't provide them).
	frames.add_animation("idle2")
	frames.set_animation_speed("idle2", 10.0)
	frames.set_animation_loop("idle2", true)
	for r in idle_regions:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = r
		frames.add_frame("idle2", at)

	frames.add_animation("Dash2")
	frames.set_animation_speed("Dash2", 10.0)
	frames.set_animation_loop("Dash2", true)
	for r in dash_regions:
		var at2 := AtlasTexture.new()
		at2.atlas = tex
		at2.region = r
		frames.add_frame("Dash2", at2)

	frames.add_animation("record2")
	frames.set_animation_speed("record2", 10.0)
	frames.set_animation_loop("record2", false)
	for r in record_regions:
		var at3 := AtlasTexture.new()
		at3.atlas = tex
		at3.region = r
		frames.add_frame("record2", at3)

	echo_sprite.sprite_frames = frames


func _snap_to_floor() -> void:
	var space := get_world_2d().direct_space_state
	if space == null:
		return

	var from := global_position + Vector2(0, -8)
	var to := global_position + Vector2(0, _SNAP_RAY_LENGTH)
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.exclude = [self]
	params.collide_with_areas = false
	params.collide_with_bodies = true

	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return
	var p: Vector2 = hit.get("position", global_position)
	global_position = Vector2(global_position.x, p.y)


# ── Sound Effects ────────────────────────────────────────────

func _play_jump_sound() -> void:
	if jump_sound != null and not jump_sound.playing:
		jump_sound.play()


func _play_dash_sound() -> void:
	if dash_sound != null and not dash_sound.playing:
		dash_sound.play()
