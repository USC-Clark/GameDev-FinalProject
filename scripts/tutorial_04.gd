extends Node2D

@export var action_limit: int = 15


func _ready() -> void:
	$Key.key_collected.connect($Door.open_door)
	$Key.key_released.connect($Door.close_door)

	await get_tree().process_frame
	# Only show intro dialogue if tutorial 04 hasn't been completed yet.
	if not Progress.is_tutorial_unlocked(5):
		_show_intro_dialogue()


func _show_intro_dialogue() -> void:
	var dlg := preload("res://scenes/dialogue_box.tscn").instantiate()
	var manager := _find_manager()
	if manager:
		manager.add_child(dlg)
	else:
		get_parent().add_child(dlg)

	dlg.show_dialogue([
		{"name": "Player", "text": "Hmm, there's a Gate blocking the way..."},
		{"name": "Player", "text": "That plate on the ground must control it!\nSomeone needs to stand on it."},
		{"name": "Player", "text": "I'll use my Echo — record myself standing\non the plate, then walk through the Gate!"},
	])

	dlg.dialogue_finished.connect(_highlight_gateplate)

func _highlight_gateplate() -> void:
	var plate := get_node_or_null("Gateplate")
	var gate  := get_node_or_null("Gate")

	# Pulse the Gateplate yellow — target the Offgate sprite directly.
	if plate != null:
		var offgate := plate.get_node_or_null("Offgate")
		var pulse_target: Node2D = offgate if offgate != null else plate
		var pt := get_tree().create_tween().set_loops().bind_node(pulse_target)
		pt.tween_property(pulse_target, "self_modulate", Color(2.0, 2.0, 0.3, 1.0), 0.4) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		pt.tween_property(pulse_target, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		# Stop when the gate opens (plate is being stood on).
		if gate != null and gate.has_signal("gate_opened"):
			gate.gate_opened.connect(func() -> void:
				pt.kill()
				pulse_target.self_modulate = Color(1, 1, 1, 1)
			, CONNECT_ONE_SHOT)
		else:
			# Fallback — stop after 12 seconds.
			await get_tree().create_timer(12.0).timeout
			if is_instance_valid(pulse_target):
				pt.kill()
				pulse_target.self_modulate = Color(1, 1, 1, 1)

	# Pulse the Gate blue so the player knows what it controls.
	if gate != null:
		var close_sprite := gate.get_node_or_null("Closegate")
		var target: Node2D = close_sprite if close_sprite != null else gate
		var gt := get_tree().create_tween().set_loops().bind_node(target)
		# Use a bright cyan/blue that's visible even on dark sprites.
		gt.tween_property(target, "self_modulate", Color(0.2, 0.6, 3.0, 1.0), 0.5) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		gt.tween_property(target, "self_modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5) \
			.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		# Stop when the gate opens.
		gate.gate_opened.connect(func() -> void:
			gt.kill()
			target.self_modulate = Color(1, 1, 1, 1)
		, CONNECT_ONE_SHOT)


func _find_manager() -> Node:
	var node: Node = self
	while node != null:
		if node.has_method("_reset_level"):
			return node
		node = node.get_parent()
	return null
