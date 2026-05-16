extends CanvasLayer

## Orb cutscene — fully automatic, no player input required.
## Emits [signal done] when finished.

signal done

# ── Exports ───────────────────────────────────────────────────
@export var background_scene:   PackedScene = null
@export var sprite_sheet_path:  String      = "res://Sprite/SPRITE_SHEET.png"

@export var row_idle_y:         int   = 0
@export var row_walk_y:         int   = 32
@export var row_attack_y:       int   = 96
@export var row_echo_y:         int   = 0

@export var walk_frame_count:   int   = 8
@export var attack_frame_count: int   = 7
@export var idle_frame_count:   int   = 6
@export var walk_uses_two_rows: bool  = false

@export var walk_anim_speed:    float = 10.0
@export var attack_anim_speed:  float = 10.0
@export var idle_anim_speed:    float = 10.0

@export var walk_speed:         float = 220.0
@export var orb_stop_offset:    float = 160.0

@export var orb_position:       Vector2 = Vector2(725, 680)
@export var warrior_start_x:    float   = -80.0
@export var warrior_floor_y:    float   = 776.0
@export var first_stop_x:       float   = 320.0

@export var echo_slide_dist:    float = 140.0
@export var echo_slide_time:    float = 0.55
@export var orb_pulse_speed:    float = 2.8

## Seconds each subtitle line stays on screen before fading out.
@export var line_display_time:  float = 2.8
## Typewriter speed — characters per second.
@export var typewriter_speed:   float = 40.0

# ── Internal ──────────────────────────────────────────────────
var _warrior_sprite  : AnimatedSprite2D
var _echo_sprite     : AnimatedSprite2D
var _orb_root        : Node2D
var _obelisk_sprite  : AnimatedSprite2D
var _flash_overlay   : ColorRect
var _bg_dim          : ColorRect
var _bg_tilemap      : TileMap     # reference to the background TileMap

var _walk_target_x   : float = 0.0
var _walking         : bool  = false
var _orb_time        : float = 0.0
var _orb_alive       : bool  = true
var _murmur_active   : bool  = false  # stops boss murmur loop when obelisk breaks

const SPRITE_SCALE   := Vector2(3.6289063, 3.7226563)
const FRAME_W        := 32
const FRAME_H        := 32


func _ready() -> void:
	layer = 50

	# Block all input during the cutscene so menu buttons can't be triggered.
	get_tree().root.set_disable_input(true)

	# Stop the MusicManager and play cutscene music on a private player
	# at fixed volume — unaffected by settings.
	MusicManager.stop()
	var _cutscene_music := AudioStreamPlayer.new()
	_cutscene_music.stream = load("res://Music/cutscene_song.mp3")
	_cutscene_music.bus = "Master"
	_cutscene_music.volume_db = 6.0   # boosted volume, ignores settings slider
	_cutscene_music.autoplay = false
	add_child(_cutscene_music)
	_cutscene_music.play()

	_bg_dim = ColorRect.new()
	_bg_dim.color = Color(0.07, 0.06, 0.12, 1)  # dark navy — covers the menu
	_bg_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_dim)

	if background_scene != null:
		var bg := background_scene.instantiate()
		add_child(bg)
		var obelisk := bg.get_node_or_null("Time_Obelisk")
		if obelisk is AnimatedSprite2D:
			_obelisk_sprite = obelisk as AnimatedSprite2D
			orb_position = bg.position + obelisk.position
		# Hide Layer6 (layer index 4) until the crack happens.
		var tilemap := bg.get_node_or_null("TileMap")
		if tilemap is TileMap:
			(tilemap as TileMap).set_layer_enabled(4, false)
		_bg_tilemap = tilemap
		# Grab the boss sprite if it's already placed in the background scene.
		var boss := bg.get_node_or_null("Background_Boss")
		if boss is AnimatedSprite2D:
			(boss as AnimatedSprite2D).play("default")

	_orb_root = Node2D.new()
	add_child(_orb_root)

	_warrior_sprite = _make_warrior_sprite()
	_warrior_sprite.position = Vector2(warrior_start_x, warrior_floor_y)
	add_child(_warrior_sprite)
	_warrior_sprite.play("idle")

	_echo_sprite = _make_echo_sprite()
	_echo_sprite.position = Vector2(warrior_start_x, warrior_floor_y)
	_echo_sprite.modulate = Color(0.2, 0.5, 1.0, 0.0)
	_echo_sprite.visible = false
	add_child(_echo_sprite)

	_flash_overlay = ColorRect.new()
	_flash_overlay.color = Color(1, 1, 1, 0)
	_flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_overlay)

	_run_sequence()


func _process(delta: float) -> void:
	if _walking:
		var diff := _walk_target_x - _warrior_sprite.position.x
		if absf(diff) <= walk_speed * delta:
			_warrior_sprite.position.x = _walk_target_x
			_walking = false
		else:
			_warrior_sprite.position.x += signf(diff) * walk_speed * delta

	if _orb_alive and is_instance_valid(_obelisk_sprite):
		_orb_time += delta
		var pulse := sin(_orb_time * orb_pulse_speed) * 0.5 + 0.5
		var s := lerpf(0.95, 1.05, pulse)
		_obelisk_sprite.scale = Vector2(s, s)


# ── Sequence ──────────────────────────────────────────────────

func _run_sequence() -> void:
	# Background is already black — brief pause then start
	await _wait(0.3)
	if not is_inside_tree(): return

	# Walk to first skeleton
	_walk_target_x = first_stop_x
	_warrior_sprite.play("Walk")
	_walking = true
	while _walking:
		await get_tree().process_frame
		if not is_inside_tree(): return
	_warrior_sprite.play("idle")

	await _wait(0.4)
	if not is_inside_tree(): return

	# Warrior lines auto-play on the right
	# Agis murmur fires independently every 2s
	_murmur_active = true
	_show_boss_murmur()
	await _show_line("Warrior", "What is this place...?\nThe air feels different here. Heavy.", false)
	if not is_inside_tree(): return
	await _show_line("Warrior", "That structure... I've never seen anything like it.\nIt pulses like it's alive.", false)
	if not is_inside_tree(): return
	await _show_line("Warrior", "Some kind of obelisk? No — it's more than that.\nI can feel it pulling at something inside me.", false)
	if not is_inside_tree(): return
	await _show_line("Warrior", "...I have to get closer.", false)
	if not is_inside_tree(): return

	await _wait(0.3)
	if not is_inside_tree(): return

	# Walk to obelisk
	_walk_target_x = orb_position.x
	_warrior_sprite.play("Walk")
	_walking = true
	while _walking:
		await get_tree().process_frame
		if not is_inside_tree(): return

	# Attack
	_warrior_sprite.play("Attack")
	var attack_duration := float(attack_frame_count) / attack_anim_speed
	await _wait(attack_duration * 0.6)
	if not is_inside_tree(): return

	# Stop boss murmur, obelisk drains black
	_murmur_active = false
	if is_instance_valid(_obelisk_sprite):
		var t_drain := create_tween()
		t_drain.tween_property(_obelisk_sprite, "modulate", Color(0, 0, 0, 1), 0.7)
	_orb_alive = false

	await _wait(attack_duration * 0.4)
	if not is_inside_tree(): return
	_warrior_sprite.play("idle")

	# Cracks form across the background
	await _wait(0.3)
	if not is_inside_tree(): return
	_spawn_cracks()

	# Boss glitch popup
	await _wait(0.5)
	if not is_inside_tree(): return
	var intro := preload("res://scenes/abyss_intro.tscn").instantiate()
	intro.glitch_text = "YOU TOOK WHAT WAS MINE...\nNOW YOU WILL NEVER REST!!!"
	get_tree().root.add_child(intro)
	await intro.done
	if not is_inside_tree(): return

	# After boss popup — particles burst out, warrior floats up, particles collect
	_spawn_absorption_particles()

	await _wait(0.3)
	if not is_inside_tree(): return

	# Warrior floats up 200px while particles are scattered
	var float_up := create_tween()
	float_up.tween_property(_warrior_sprite, "position:y",
		_warrior_sprite.position.y - 200.0, 0.7) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await float_up.finished
	if not is_inside_tree(): return

	# Hold floating while particles fly back in
	await _wait(1.0)
	if not is_inside_tree(): return

	# Warrior lights up as particles arrive
	var t_absorb := create_tween()
	t_absorb.tween_property(_warrior_sprite, "modulate", Color(2.5, 3.0, 3.0, 1.0), 0.15)
	await t_absorb.finished
	if not is_inside_tree(): return
	await _wait(0.25)
	if not is_inside_tree(): return
	var t_normal := create_tween()
	t_normal.tween_property(_warrior_sprite, "modulate", Color(1, 1, 1, 1), 0.35)
	await t_normal.finished
	if not is_inside_tree(): return

	# Float back down
	var float_down := create_tween()
	float_down.tween_property(_warrior_sprite, "position:y",
		warrior_floor_y, 0.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await float_down.finished
	if not is_inside_tree(): return

	await _wait(0.3)
	if not is_inside_tree(): return

	# Echo spawns right, faces left — warrior flashes white at the split moment
	_warrior_sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
	var t_split_flash := create_tween()
	t_split_flash.tween_property(_warrior_sprite, "modulate", Color(1, 1, 1, 1), 0.3)

	_echo_sprite.position = _warrior_sprite.position + Vector2(echo_slide_dist, 0)
	_echo_sprite.visible = true
	_echo_sprite.play("idle2")
	_echo_sprite.flip_h = true
	_echo_sprite.modulate = Color(0.2, 0.5, 1.0, 0.0)
	var t_echo := create_tween()
	t_echo.tween_property(_echo_sprite, "modulate:a", 0.85, echo_slide_time) \
		.set_ease(Tween.EASE_OUT)
	await t_echo.finished
	if not is_inside_tree(): return

	await _wait(1.4)
	if not is_inside_tree(): return

	# Keep black bg covering the menu until the new scene is loaded.
	if is_instance_valid(_warrior_sprite): _warrior_sprite.queue_free()
	if is_instance_valid(_echo_sprite): _echo_sprite.queue_free()

	# Re-enable input BEFORE emitting done so the next scene gets input immediately.
	get_tree().root.set_disable_input(false)
	MusicManager.play()
	emit_signal("done")
	await get_tree().tree_changed
	await get_tree().process_frame
	queue_free()


# ── Auto subtitle system ──────────────────────────────────────

## Shows a single subtitle line with typewriter effect, holds, then fades out.
## left=true puts it on the left side (for boss). Awaitable.
func _show_line_at(speaker: String, text: String, screen_pos: Vector2) -> void:
	if not is_inside_tree():
		return

	var cl := CanvasLayer.new()
	cl.layer = 60
	add_child(cl)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(true))
	# Position above the obelisk, centered on its x
	panel.anchor_left   = 0.0
	panel.anchor_right  = 0.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left   = screen_pos.x - 360.0
	panel.offset_right  = screen_pos.x - 60.0
	panel.offset_top    = screen_pos.y - 160.0
	panel.offset_bottom = screen_pos.y - 60.0
	cl.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = speaker
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.7, 0.5, 1.0, 1))
	vbox.add_child(name_lbl)

	var text_lbl := RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.scroll_active = false
	text_lbl.custom_minimum_size = Vector2(280, 40)
	text_lbl.add_theme_font_size_override("normal_font_size", 11)
	text_lbl.add_theme_color_override("default_color", Color(0.75, 0.65, 0.95, 1))
	vbox.add_child(text_lbl)

	panel.modulate.a = 0.0
	var t_in := create_tween()
	t_in.tween_property(panel, "modulate:a", 1.0, 0.2)
	await t_in.finished
	if not is_inside_tree():
		cl.queue_free()
		return

	# Typewriter
	var char_delay := 1.0 / typewriter_speed
	var displayed := ""
	for ch in text:
		if not _murmur_active:   # stop mid-type if obelisk broke
			cl.queue_free()
			return
		displayed += ch
		text_lbl.text = displayed
		await get_tree().create_timer(char_delay).timeout
		if not is_inside_tree():
			cl.queue_free()
			return

	await _wait(line_display_time)
	if not is_inside_tree():
		cl.queue_free()
		return

	var t_out := create_tween()
	t_out.tween_property(panel, "modulate:a", 0.0, 0.25)
	await t_out.finished
	cl.queue_free()


func _show_line(speaker: String, text: String, left: bool) -> void:
	if not is_inside_tree():
		return

	# Container
	var cl := CanvasLayer.new()
	cl.layer = 60
	add_child(cl)

	# Outer HBox — portrait + bubble (or bubble + portrait for left side)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	if left:
		hbox.anchor_left   = 0.0
		hbox.anchor_right  = 0.0
		hbox.anchor_top    = 0.65
		hbox.anchor_bottom = 0.65
		hbox.offset_left   = 30.0
		hbox.offset_right  = 490.0
		hbox.offset_top    = -70.0
		hbox.offset_bottom = 70.0
	else:
		hbox.anchor_left   = 1.0
		hbox.anchor_right  = 1.0
		hbox.anchor_top    = 0.5
		hbox.anchor_bottom = 0.5
		hbox.offset_left   = -620.0
		hbox.offset_right  = -30.0
		hbox.offset_top    = -110.0
		hbox.offset_bottom = 110.0
	hbox.grow_horizontal = Control.GROW_DIRECTION_BEGIN if left else Control.GROW_DIRECTION_END
	cl.add_child(hbox)

	# Portrait image — only for warrior (right side)
	var portrait := TextureRect.new()
	if not left:
		portrait.custom_minimum_size = Vector2(100, 100)
		portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var portrait_tex_path := "res://Sprite/SPRITE_PORTRAIT.png"
		if ResourceLoader.exists(portrait_tex_path):
			portrait.texture = load(portrait_tex_path)

	# Bubble panel
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _make_panel_style(left))
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical   = Control.SIZE_SHRINK_CENTER

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = speaker
	name_lbl.add_theme_font_size_override("font_size", 11 if left else 14)
	name_lbl.add_theme_color_override("font_color",
		Color(0.7, 0.5, 1.0, 1) if left else Color(0.25, 0.15, 0, 1))
	vbox.add_child(name_lbl)

	var text_lbl := RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.scroll_active = false
	text_lbl.custom_minimum_size = Vector2(280, 60) if left else Vector2(420, 120)
	text_lbl.add_theme_font_size_override("normal_font_size", 11 if left else 14)
	text_lbl.add_theme_color_override("default_color",
		Color(0.75, 0.65, 0.95, 1) if left else Color(0.08, 0.06, 0.02, 1))
	vbox.add_child(text_lbl)

	# Order: portrait right of bubble for warrior, no portrait for boss
	if left:
		hbox.add_child(panel)
	else:
		hbox.add_child(panel)
		hbox.add_child(portrait)

	# Fade in
	hbox.modulate.a = 0.0
	var t_in := create_tween()
	t_in.tween_property(hbox, "modulate:a", 1.0, 0.2)
	await t_in.finished
	if not is_inside_tree():
		cl.queue_free()
		return

	# Typewriter
	var char_delay := 1.0 / typewriter_speed
	var displayed := ""
	# Only play dialogue sound for the player/warrior — never for boss lines.
	var _dlg_sound: AudioStreamPlayer = null
	if speaker == "Warrior":
		_dlg_sound = AudioStreamPlayer.new()
		_dlg_sound.stream = load("res://all_sounds/DIALOGUE_SOUND.mp3")
		_dlg_sound.bus = "Master"
		_dlg_sound.volume_db = 6.0
		cl.add_child(_dlg_sound)
	for ch in text:
		displayed += ch
		text_lbl.text = displayed
		if _dlg_sound != null and not _dlg_sound.playing:
			_dlg_sound.play()
		await get_tree().create_timer(char_delay).timeout
		if not is_inside_tree():
			cl.queue_free()
			return

	# Typewriter finished — stop dialogue sound immediately.
	if _dlg_sound != null:
		_dlg_sound.stop()

	# Hold
	await _wait(line_display_time)
	if not is_inside_tree():
		cl.queue_free()
		return

	# Fade out
	var t_out := create_tween()
	t_out.tween_property(hbox, "modulate:a", 0.0, 0.25)
	await t_out.finished
	cl.queue_free()


func _make_panel_style(left: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.03, 0.1, 0.88) if left else Color(1, 1, 1, 0.92)
	s.set_border_width_all(2)
	s.border_color = Color(0.4, 0.2, 0.7, 1) if left else Color(0.7, 0.6, 0.2, 1)
	s.set_corner_radius_all(8)
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 4
	s.content_margin_left   = 10
	s.content_margin_right  = 10
	s.content_margin_top    = 8
	s.content_margin_bottom = 8
	return s


func _show_boss_murmur() -> void:
	var murmurs := [
		"Mmh... nnn...",
		"...who... dares...",
		"...not yet... sleep...",
		"Zzz... hm...",
		"...the obelisk... no...",
	]
	var idx := 0
	while _murmur_active and is_inside_tree():
		await get_tree().create_timer(2.0).timeout
		if not _murmur_active or not is_inside_tree():
			return
		await _show_line_at("Agis", murmurs[idx % murmurs.size()], orb_position)
		idx += 1


# ── Sprite builders ───────────────────────────────────────────

func _make_warrior_sprite() -> AnimatedSprite2D:
	var tex := load(sprite_sheet_path) as Texture2D
	var frames := SpriteFrames.new()
	_add_anim(frames, "idle",   tex, row_idle_y,   idle_frame_count,   idle_anim_speed,   true)
	_add_walk_anim(frames, tex)
	_add_anim(frames, "Attack", tex, row_attack_y, attack_frame_count, attack_anim_speed, false)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.scale = SPRITE_SCALE
	return spr


func _make_echo_sprite() -> AnimatedSprite2D:
	var tex := load(sprite_sheet_path) as Texture2D
	var frames := SpriteFrames.new()
	_add_anim(frames, "idle2", tex, row_echo_y, idle_frame_count, idle_anim_speed, true)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.scale = SPRITE_SCALE
	return spr


func _add_anim(frames: SpriteFrames, anim: String, tex: Texture2D,
		row_y: int, count: int, speed: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, speed)
	frames.set_animation_loop(anim, loop)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME_W, row_y, FRAME_W, FRAME_H)
		frames.add_frame(anim, at)


func _add_walk_anim(frames: SpriteFrames, tex: Texture2D) -> void:
	frames.add_animation("Walk")
	frames.set_animation_speed("Walk", walk_anim_speed)
	frames.set_animation_loop("Walk", true)
	var first_row_count := mini(walk_frame_count, 8) if walk_uses_two_rows else walk_frame_count
	for i in first_row_count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * FRAME_W, row_walk_y, FRAME_W, FRAME_H)
		frames.add_frame("Walk", at)
	if walk_uses_two_rows and walk_frame_count > 8:
		for i in walk_frame_count - 8:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * FRAME_W, row_walk_y + FRAME_H, FRAME_W, FRAME_H)
			frames.add_frame("Walk", at)


func _spawn_absorption_particles() -> void:
	if not is_instance_valid(_obelisk_sprite) or not is_instance_valid(_warrior_sprite):
		return
	var obelisk_pos := _obelisk_sprite.global_position

	# Phase 1 — burst outward in random directions.
	# Phase 2 — after a delay, fly into the warrior (who floats up).
	for i in 16:
		var p := ColorRect.new()
		var size := randf_range(8.0, 16.0)
		p.size = Vector2(size, size)
		p.color = Color(
			randf_range(0.2, 0.5),
			randf_range(0.6, 1.0),
			randf_range(0.8, 1.0),
			1.0
		)
		p.position = obelisk_pos - p.size * 0.5
		add_child(p)

		# Random burst direction and distance
		var angle := randf() * TAU
		var dist  := randf_range(120.0, 320.0)
		var burst_target := obelisk_pos + Vector2(cos(angle), sin(angle)) * dist
		var burst_time   := randf_range(0.3, 0.55)
		var collect_delay := randf_range(0.6, 1.0)   # wait before flying to warrior
		var collect_time  := randf_range(0.35, 0.6)

		var tw: Tween = create_tween().set_parallel(true)
		# Burst out
		tw.tween_property(p, "position", burst_target - p.size * 0.5, burst_time) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		# Then fly into warrior — use a callback to start the second tween
		tw.tween_callback(func() -> void:
			if not is_instance_valid(p) or not is_instance_valid(_warrior_sprite):
				return
			var warrior_pos := _warrior_sprite.global_position
			var tw2: Tween = create_tween().set_parallel(true)
			tw2.tween_property(p, "position", warrior_pos - p.size * 0.5, collect_time) \
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			tw2.tween_property(p, "modulate:a", 0.0, collect_time * 0.4) \
				.set_delay(collect_time * 0.6)
			tw2.tween_callback(p.queue_free).set_delay(collect_time + 0.05)
		).set_delay(burst_time + collect_delay)


func _spawn_cracks() -> void:
	# Reveal Layer6 — the cracked/broken tilemap layout.
	if is_instance_valid(_bg_tilemap):
		(_bg_tilemap as TileMap).set_layer_enabled(4, true)

	# Draw several jagged crack lines radiating from the obelisk position outward.
	var origin := orb_position
	var crack_configs := [
		# Each entry: [end offset, width, delay]
		[Vector2(-600, -300), 3.0, 0.00],
		[Vector2( 700, -250), 2.5, 0.06],
		[Vector2(-400,  400), 2.0, 0.10],
		[Vector2( 500,  350), 2.5, 0.04],
		[Vector2(-200, -500), 2.0, 0.08],
		[Vector2( 100,  500), 1.5, 0.12],
		[Vector2(-700,  100), 2.0, 0.05],
		[Vector2( 650, -100), 1.5, 0.09],
	]
	for cfg in crack_configs:
		var end_offset: Vector2 = cfg[0]
		var width: float        = cfg[1]
		var delay: float        = cfg[2]
		_draw_crack(origin, origin + end_offset, width, delay)


func _draw_crack(start: Vector2, end: Vector2, width: float, delay: float) -> void:
	var line := Line2D.new()
	line.width = width
	line.default_color = Color(0.05, 0.0, 0.1, 0.9)
	line.joint_mode = Line2D.LINE_JOINT_SHARP

	# Build jagged points between start and end
	var segments := 8
	var points: Array[Vector2] = []
	for i in segments + 1:
		var t := float(i) / float(segments)
		var base := start.lerp(end, t)
		var perp := (end - start).rotated(PI * 0.5).normalized()
		var jitter := randf_range(-18.0, 18.0) * (1.0 - absf(t - 0.5) * 1.5)
		points.append(base + perp * jitter)
	line.points = points
	line.modulate.a = 0.0
	add_child(line)

	# Fade in quickly after delay
	var tw: Tween = create_tween()
	tw.tween_property(line, "modulate:a", 1.0, 0.08).set_delay(delay)


func _wait(seconds: float) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(seconds).timeout
