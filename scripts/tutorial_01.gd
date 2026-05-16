extends Node2D


func _ready() -> void:
	var key := $Key
	var door := $Door

	key.key_collected.connect(door.open_door)
	key.key_released.connect(door.close_door)

	await get_tree().process_frame
	# Only show intro dialogue if tutorial 01 hasn't been completed yet.
	if not Progress.is_tutorial_unlocked(2):
		_show_intro_dialogue()


func _show_intro_dialogue() -> void:
	var dlg := preload("res://scenes/dialogue_box.tscn").instantiate()
	var manager := _find_manager()
	if manager:
		manager.add_child(dlg)
	else:
		get_parent().add_child(dlg)

	# Hide reset button until after dialogue 3 is done.
	var reset_btn := _find_reset_button(manager)
	if reset_btn:
		reset_btn.visible = false

	dlg.restore_controls_on_finish = false  # demo follows, don't restore yet
	dlg.show_dialogue([
		{"name": "Player", "text": "Hmm... where am I?"},
		{"name": "Player", "text": "Interesting... I can record my movements\nand replay them as an Echo!"},
	])

	dlg.dialogue_finished.connect(func() -> void:
		_run_rec_demo(manager)
	)


func _run_rec_demo(manager: Node) -> void:
	var player: Node = null
	for p in get_tree().get_nodes_in_group("player"):
		player = p
		break
	if player == null:
		_show_final_dialogue(manager)
		return

	# Keep input blocked during demo — injected actions still work via Input.parse_input_event.
	# Only re-enable physics so the player can physically move from injected inputs.
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node:
			p.set_physics_process(true)
			p.set_process(true)
			p.set_process_unhandled_input(false)  # block real player input

	var hint := _make_hint_label("Press REC to start recording!", manager)
	await _pausable_wait(1.2)
	if not is_inside_tree(): return
	if not is_instance_valid(hint): return
	hint.queue_free()

	player.start_recording()

	var move_hint := _make_hint_label("Recording... watch the Echo!", manager)
	await _pausable_wait(0.4)
	if not is_inside_tree(): return

	for i in range(3):
		_inject_action("move_right")
		await _pausable_wait(0.45)
		if not is_inside_tree(): return

	await _pausable_wait(0.3)
	if not is_inside_tree(): return
	if is_instance_valid(move_hint): move_hint.queue_free()

	var stop_hint := _make_hint_label("Press REC again to stop!", manager)
	await _pausable_wait(1.0)
	if not is_inside_tree(): return
	if is_instance_valid(stop_hint): stop_hint.queue_free()

	if manager and manager.has_method("_toggle_recording"):
		manager._toggle_recording()
	else:
		player.stop_recording()

	# Keep player input blocked during echo playback.
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node:
			p.set_physics_process(true)
			p.set_process(true)
			p.set_process_unhandled_input(false)

	await _pausable_wait(0.8)
	if not is_inside_tree(): return

	var echo_hint := _make_hint_label("Your Echo replays your moves!", manager)
	await _pausable_wait(1.8)
	if not is_inside_tree(): return
	if is_instance_valid(echo_hint): echo_hint.queue_free()

	if manager and manager.has_method("_reset_level"):
		manager._reset_level("Get ready!")
	await _pausable_wait(0.5)
	if not is_inside_tree(): return

	# Block all input again — reset re-enables the player.
	_set_player_blocked(true)
	_show_final_dialogue(manager)


## Waits [duration] seconds, freezing while the tree is paused or node is freed.
func _pausable_wait(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		if not is_inside_tree():
			return
		if not get_tree().paused:
			elapsed += get_process_delta_time()


func _show_final_dialogue(manager: Node) -> void:
	var dlg := preload("res://scenes/dialogue_box.tscn").instantiate()
	if manager:
		manager.add_child(dlg)
	else:
		get_parent().add_child(dlg)

	# restore_controls_on_finish = true (default) — controls return after dialogue 3.
	dlg.show_dialogue([
		{"name": "Player", "text": "Now your turn!"},
	])

	# Unblock player input only after dialogue 3 is dismissed.
	dlg.dialogue_finished.connect(func() -> void:
		_set_player_blocked(false)
		# Show reset button now that the intro sequence is complete.
		var reset_btn := _find_reset_button(manager)
		if reset_btn:
			reset_btn.visible = true
		_highlight_key_and_rec()
	)


func _inject_action(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	ev.strength = 1.0
	Input.parse_input_event(ev)
	if is_inside_tree():
		await get_tree().process_frame
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)


func _make_hint_label(text: String, parent: Node) -> Node:
	var cl := CanvasLayer.new()
	cl.layer = 30
	if parent:
		parent.add_child(cl)
	else:
		get_parent().add_child(cl)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.3, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.custom_minimum_size = Vector2(700, 0)
	lbl.position = Vector2(-350, -30)
	cl.add_child(lbl)

	lbl.modulate.a = 0.0
	var t := lbl.create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.2)
	return cl


func _set_player_blocked(blocked: bool) -> void:
	for p in get_tree().get_nodes_in_group("player"):
		if p is Node:
			p.set_physics_process(not blocked)
			p.set_process(not blocked)
			p.set_process_unhandled_input(not blocked)


func _find_manager() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("_reset_level"):
			return node
		node = node.get_parent()
	return null


func _find_reset_button(manager: Node) -> Button:
	if manager == null:
		return null
	var btn := manager.get_node_or_null("CanvasLayer/UI/ResetButton")
	if btn is Button:
		return btn as Button
	return null


func _highlight_key_and_rec() -> void:
	var key := get_node_or_null("Key")
	if key != null:
		var tween := get_tree().create_tween().set_loops().bind_node(key)
		tween.tween_property(key, "modulate", Color(2.0, 2.0, 0.4, 1.0), 0.4) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(key, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		$Key.key_collected.connect(func() -> void:
			tween.kill()
			key.modulate = Color(1, 1, 1, 1)
		, CONNECT_ONE_SHOT)

	# Highlight the REC button.
	var rec_btn: Button = null
	var touch := get_tree().get_root().find_child("Record", true, false)
	if touch is Button:
		rec_btn = touch as Button
	if rec_btn == null:
		var tc := get_tree().get_root().find_child("TouchControls", true, false)
		if tc:
			rec_btn = tc.get_node_or_null("Control/Record") as Button

	if rec_btn != null:
		var rec_tween := get_tree().create_tween().set_loops().bind_node(rec_btn)
		rec_tween.tween_property(rec_btn, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.4) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		rec_tween.tween_property(rec_btn, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		await get_tree().create_timer(10.0).timeout
		if is_instance_valid(rec_btn):
			rec_tween.kill()
			rec_btn.modulate = Color(1, 1, 1, 1)
