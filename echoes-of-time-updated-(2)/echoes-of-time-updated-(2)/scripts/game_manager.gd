extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ECHO_SCENE := preload("res://scenes/echo.tscn")
const ROOM_W := 1280.0
const ROOM_H := 720.0
const ONE_WAY_PLATFORM_LAYER: int = 5
const STEP_DISTANCE_PX: float = 96.0
const TUTORIAL_MAP_DIR := "res://scenes/maps/tutorial"
# Approx from player.gd jump_velocity=-520, gravity=1100 => ~123 px peak height.
const APPROX_JUMP_HEIGHT_PX: float = 123.0

@onready var world: Node2D = $World
@onready var actors: Node2D = $Actors
@onready var ui_steps: Label = $CanvasLayer/UI/StepsLabel
@onready var ui_record: Label = $CanvasLayer/UI/RecordLabel
@onready var ui_level: Label = $CanvasLayer/UI/LevelLabel
@onready var ui_info: Label = $CanvasLayer/UI/InfoLabel
@onready var ui_complete: Label = $CanvasLayer/UI/CompleteLabel
@onready var reset_button: Button = $CanvasLayer/UI/ResetButton
@onready var pause_panel: Panel = $CanvasLayer/UI/PausePanel
@onready var tutorial_select_button: Button = $CanvasLayer/UI/PausePanel/TutorialSelectButton

var _player: CharacterBody2D
var _echoes: Array[Node] = []
var _buttons: Array[Dictionary] = []
var _doors: Array[Dictionary] = []
var _hazards: Array[Rect2] = []
var _hazard_areas: Array[Area2D] = []
var _lifts: Array[Dictionary] = []
var _falling_platforms: Array[Dictionary] = []

var _is_tutorial_mode: bool = true
var _level_index: int = 0
var _paused: bool = false
var _is_complete: bool = false
var _last_actions: int = 0
var _free_mode: bool = false
var _current_level_data: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_button.pressed.connect(_on_reset_button_pressed)
	tutorial_select_button.pressed.connect(_on_tutorial_select_pressed)
	_is_tutorial_mode = true
	var start_scene_path := String(GameState.selected_tutorial_scene_path)
	if start_scene_path == "":
		start_scene_path = _tutorial_scene_path(int(GameState.selected_tutorial_level))
	if not ResourceLoader.exists(start_scene_path):
		push_error("Tutorial scene not found: %s" % start_scene_path)
		return
	_load_level(start_scene_path)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_level"):
		_reset_level_state("Manual reset.")
		return
	if event.is_action_pressed("toggle_free_mode"):
		_free_mode = not _free_mode
		ui_info.text = ("Free Mode: ON (limits ignored)" if _free_mode else "Free Mode: OFF")
		return
	if event.is_action_pressed("toggle_record") and not _paused and not _is_complete:
		_toggle_recording()
		return
	if _is_complete and event.is_action_pressed("jump"):
		_load_next_level()
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _physics_process(_delta: float) -> void:
	if _paused or _is_complete or _player == null:
		return
	_update_button_states()
	_update_doors()
	_check_hazards()
	_check_exit()


func _process(delta: float) -> void:
	if _paused:
		return
	for lift in _lifts:
		var body: AnimatableBody2D = lift["body"]
		if lift.get("auto", false):
			if bool(lift.get("start_on_action", false)) and not bool(lift.get("started", false)):
				continue
			var target: Vector2 = lift["end"] if lift.get("dir", 1) > 0 else lift["start"]
			var speed: float = float(lift.get("speed", 120.0))
			body.position = body.position.move_toward(target, speed * delta)
			if body.position.distance_to(target) <= 0.5:
				lift["dir"] = -int(lift.get("dir", 1))
		else:
			var pressed: bool = _is_button_pressed(String(lift.get("button_id", "")))
			var target: Vector2 = lift["end"] if pressed else lift["start"]
			body.position = body.position.move_toward(target, 120.0 * delta)


func _toggle_recording() -> void:
	if _player.is_recording():
		var recorded_frames: Array[Dictionary] = _player.stop_recording()
		print("Frames received: ", recorded_frames.size())
		
		if not recorded_frames.is_empty():
			var echo := ECHO_SCENE.instantiate()
			actors.add_child(echo)
			echo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			echo.setup(_current_level()["spawn"], recorded_frames)
			_echoes.append(echo)

		_player.reset_to_spawn()
		_player.reset_physics_interpolation()
		
		ui_info.text = "Echo created. Cooperate with your past self."
		ui_record.text = "Record: OFF"
	else:
		_player.reset_to_spawn()
		_player.reset_physics_interpolation()
		_player.start_recording()
		
		ui_info.text = "Recording started from spawn."
		ui_record.text = "Record: ON"


func _on_actions_changed(current: int, limit: int) -> void:
	ui_steps.text = "Actions: %d / %d" % [current, limit]
	if current > _last_actions:
		var delta_actions := current - _last_actions
		# Start any auto movers that should begin on first action.
		for lift in _lifts:
			if bool(lift.get("start_on_action", false)) and not bool(lift.get("started", false)):
				lift["started"] = true
		for _i in range(delta_actions):
			for echo in _echoes:
				if echo.has_method("consume_action"):
					echo.consume_action()
	_last_actions = current


func _on_record_state_changed(is_on: bool) -> void:
	ui_record.text = "Record: %s" % ("ON" if is_on else "OFF")


func _on_action_limit_exceeded() -> void:
	if _free_mode:
		return
	_reset_level_state("Action limit exceeded.")


func _on_reset_button_pressed() -> void:
	_reset_level_state("Manual reset.")


func _reset_level_state(reason: String) -> void:
	for echo in _echoes:
		# Free immediately to avoid 1-frame "double render" artifacts on reset.
		if is_instance_valid(echo):
			echo.free()
	_echoes.clear()
	_player.cancel_recording()
	_player.reset_to_spawn()
	_player.reset_physics_interpolation()
	_player.force_update_transform()
	_last_actions = 0
	_reset_mechanisms()
	ui_info.text = reason
	ui_record.text = "Record: OFF"
	print("RESET - back to Original")


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	pause_panel.visible = _paused


func _on_tutorial_select_pressed() -> void:
	# Ensure we don't carry pause state into menus.
	_paused = false
	get_tree().paused = false
	pause_panel.visible = false
	GameState.go_to_tutorial_select()


func _check_exit() -> void:
	var exit_rect: Rect2 = _current_level()["exit"]
	if exit_rect.has_point(_player.global_position):
		_is_complete = true
		ui_complete.visible = true
		ui_complete.text = "Level Complete!\nPress W to continue."
		if _is_tutorial_mode:
			Progress.complete_tutorial_level(_level_index + 1)


func _check_hazards() -> void:
	# Hazards are handled via Area2D triggers; keep this for safety fallback.
	for hz in _hazards:
		if hz.has_point(_player.global_position):
			_reset_level_state("Hazard hit. Reset.")
			return


func _update_button_states() -> void:
	for button_data in _buttons:
		var area: Area2D = button_data["area"]
		var is_pressed := false
		for body in area.get_overlapping_bodies():
			if body == _player or _echoes.has(body):
				is_pressed = true
				break
		button_data["pressed"] = is_pressed
		var visual: ColorRect = button_data["visual"]
		visual.color = Color(0.35, 0.95, 0.4, 1.0) if is_pressed else Color(0.88, 0.45, 0.25, 1.0)


func _update_doors() -> void:
	for door in _doors:
		var should_open := true
		for id in door["button_ids"]:
			if not _is_button_pressed(id):
				should_open = false
				break
		if should_open and door["hold_turns"] > 0:
			door["remaining"] = door["hold_turns"]
		elif not should_open and door["remaining"] > 0:
			door["remaining"] -= 1
			should_open = true
		door["open"] = should_open
		var collider: CollisionShape2D = door["collision"]
		var visual: ColorRect = door["visual"]
		collider.disabled = should_open
		visual.modulate.a = 0.4 if should_open else 1.0
		visual.color = Color(0.15, 0.95, 0.25, 1.0) if should_open else Color(0.8, 0.18, 0.22, 1.0)


func _is_button_pressed(button_id: String) -> bool:
	for button_data in _buttons:
		if button_data["id"] == button_id:
			return button_data["pressed"]
	return false


func _load_level(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		ui_complete.visible = true
		ui_complete.text = "Tutorial complete."
		return

	var level_number := _extract_level_number(scene_path)
	var level_data := _load_tutorial_level_data(scene_path)
	if level_data.is_empty():
		ui_complete.visible = true
		ui_complete.text = "Failed to load tutorial scene."
		return

	_level_index = maxi(level_number - 1, 0)
	_current_level_data = level_data
	GameState.selected_tutorial_level = max(level_number, 1)
	GameState.selected_tutorial_scene_path = scene_path
	_is_complete = false
	ui_complete.visible = false
	get_tree().paused = false
	_paused = false
	pause_panel.visible = false

	for child in world.get_children():
		child.queue_free()
	for child in actors.get_children():
		child.queue_free()

	_echoes.clear()
	_buttons.clear()
	_doors.clear()
	_hazards.clear()
	for area in _hazard_areas:
		if is_instance_valid(area):
			area.queue_free()
	_hazard_areas.clear()
	_lifts.clear()
	_falling_platforms.clear()
	_last_actions = 0

	_build_room_shell()
	_build_level_geometry(_current_level())
	_spawn_player(_current_level())
	_reset_mechanisms()

	ui_level.text = "Tutorial %d" % (_level_index + 1) if _is_tutorial_mode else "Level %d" % (_level_index + 1)
	ui_record.text = "Record: OFF"
	ui_info.text = _current_level().get("hint", "Use echoes to solve the chamber.")


func _spawn_player(data: Dictionary) -> void:
	_player = PLAYER_SCENE.instantiate()
	actors.add_child(_player)
	_player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_player.setup(data["spawn"], data["action_limit"])
	_player.reset_physics_interpolation()
	_player.force_update_transform()
	_player.action_used.connect(_on_actions_changed)
	_player.recording_toggled.connect(_on_record_state_changed)
	_player.action_limit_exceeded.connect(_on_action_limit_exceeded)


func _build_room_shell() -> void:
	_add_platform(Rect2(0.0, ROOM_H - 28.0, ROOM_W, 28.0), Color(0.2, 0.24, 0.31, 1.0), false)
	_add_platform(Rect2(-12.0, 0.0, 12.0, ROOM_H), Color(0.2, 0.24, 0.31, 1.0), false)
	_add_platform(Rect2(ROOM_W, 0.0, 12.0, ROOM_H), Color(0.2, 0.24, 0.31, 1.0), false)
	_add_platform(Rect2(0.0, -12.0, ROOM_W, 12.0), Color(0.2, 0.24, 0.31, 1.0), false)


func _build_level_geometry(data: Dictionary) -> void:
	for p in data.get("platforms", []):
		_add_platform(p, Color(0.24, 0.3, 0.42, 1.0), true)
	for fp in data.get("falling_platforms", []):
		_add_falling_platform(fp)
	for hz in data.get("hazards", []):
		_add_hazard(hz)
	for b in data.get("buttons", []):
		_add_button(b["id"], b["rect"])
	for d in data.get("doors", []):
		_add_door(d["rect"], d["buttons"], d.get("timer_turns", 0))
	for lift in data.get("lifts", []):
		_add_lift(lift)
	_build_exit(data["exit"])


func _add_platform(rect: Rect2, color: Color, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.position = rect.position
	body.collision_layer = 16 if one_way else 4
	body.collision_mask = 0
	world.add_child(body)
	
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.size * 0.5
	shape.one_way_collision = one_way
	if one_way:
		shape.one_way_collision_margin = 6.0
	body.add_child(shape)
	
	var vis := ColorRect.new()
	vis.position = Vector2.ZERO
	vis.size = rect.size
	vis.color = color
	body.add_child(vis)


func _add_falling_platform(rect: Rect2) -> void:
	# A one-way platform that "drops" after being stepped on.
	var body := RigidBody2D.new()
	body.freeze = true
	body.gravity_scale = 2.2
	body.collision_layer = (1 << (ONE_WAY_PLATFORM_LAYER - 1))
	body.collision_mask = 0
	body.position = rect.position
	world.add_child(body)

	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.size * 0.5
	shape.one_way_collision = true
	shape.one_way_collision_margin = 6.0
	body.add_child(shape)

	var vis := ColorRect.new()
	vis.position = Vector2.ZERO
	vis.size = rect.size
	vis.color = Color(0.32, 0.34, 0.46, 1.0)
	body.add_child(vis)

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 1 | 2
	area.position = rect.size * 0.5
	body.add_child(area)
	var a_shape := CollisionShape2D.new()
	a_shape.shape = rect_shape
	area.add_child(a_shape)
	area.body_entered.connect(func(_b: Node) -> void:
		if body.freeze:
			body.freeze = false
	)

	_falling_platforms.append({"body": body})


func _add_hazard(rect: Rect2) -> void:
	_hazards.append(rect)
	var vis := ColorRect.new()
	vis.position = rect.position
	vis.size = rect.size
	vis.color = Color(0.9, 0.15, 0.2, 1.0)
	world.add_child(vis)

	# Use a slightly taller trigger so "standing on" the lava counts as entering it.
	var trigger_rect := Rect2(rect.position - Vector2(0, 8), rect.size + Vector2(0, 8))
	var area := Area2D.new()
	area.collision_layer = 32
	area.collision_mask = 1 | 2
	area.position = trigger_rect.position
	area.monitoring = true
	area.monitorable = true
	world.add_child(area)
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = trigger_rect.size
	shape.shape = rect_shape
	shape.position = trigger_rect.size * 0.5
	area.add_child(shape)
	area.body_entered.connect(func(_b: Node) -> void:
		_reset_level_state("Hazard hit. Reset.")
	)
	_hazard_areas.append(area)


func _add_button(button_id: String, rect: Rect2) -> void:
	var area := Area2D.new()
	area.collision_layer = 8
	area.collision_mask = 1 | 2
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.size * 0.5
	area.position = rect.position
	area.add_child(shape)
	area.monitoring = true
	area.monitorable = true
	world.add_child(area)
	var vis := ColorRect.new()
	vis.position = rect.position
	vis.size = rect.size
	vis.color = Color(0.88, 0.45, 0.25, 1.0)
	world.add_child(vis)
	_buttons.append({"id": button_id, "area": area, "visual": vis, "pressed": false})


func _add_door(rect: Rect2, button_ids: Array, timer_turns: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.size * 0.5
	body.position = rect.position
	body.add_child(shape)
	world.add_child(body)
	var vis := ColorRect.new()
	vis.position = rect.position
	vis.size = rect.size
	vis.color = Color(0.8, 0.18, 0.22, 1.0)
	world.add_child(vis)
	_doors.append({"collision": shape, "visual": vis, "button_ids": button_ids, "hold_turns": timer_turns, "remaining": 0, "open": false})


func _add_lift(data: Dictionary) -> void:
	var body := AnimatableBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	body.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = data["size"]
	shape.shape = rect_shape
	shape.position = data["size"] * 0.5
	var start_pos: Vector2 = data["start"]
	var reset_pos: Vector2 = data.get("initial", start_pos)
	body.position = reset_pos
	body.add_child(shape)
	world.add_child(body)
	# Only valid once the node is inside the scene tree.
	body.reset_physics_interpolation()
	body.force_update_transform()
	var vis := ColorRect.new()
	vis.position = Vector2.ZERO
	vis.size = data["size"]
	vis.color = Color(0.3, 0.65, 0.9, 1.0)
	body.add_child(vis)
	_lifts.append({
		"body": body,
		"start": start_pos,
		"end": Vector2(data["end"]),
		"button_id": data.get("button_id", ""),
		"auto": bool(data.get("auto", false)),
		"speed": float(data.get("speed", 120.0)),
		"dir": 1,
		"reset": reset_pos,
		"start_on_action": bool(data.get("start_on_action", false)),
		"started": false
	})


func _build_exit(rect: Rect2) -> void:
	var exit_vis := ColorRect.new()
	exit_vis.position = rect.position
	exit_vis.size = rect.size
	exit_vis.color = Color(0.95, 0.88, 0.2, 1.0)
	world.add_child(exit_vis)


func _reset_mechanisms() -> void:
	for door in _doors:
		door["remaining"] = 0
		door["open"] = false
	for button_data in _buttons:
		button_data["pressed"] = false
	for lift in _lifts:
		var body: AnimatableBody2D = lift["body"]
		body.position = lift.get("reset", lift["start"])
		# Prevent visual "ghosting" / duplicate-looking platforms after teleports.
		body.reset_physics_interpolation()
		body.force_update_transform()
		lift["dir"] = 1
		lift["started"] = false


func _current_level() -> Dictionary:
	return _current_level_data


func _tutorial_scene_path(level_number: int) -> String:
	return "%s/tutorial_%02d.tscn" % [TUTORIAL_MAP_DIR, level_number]


func _tutorial_level_count() -> int:
	var level_count := 0
	while true:
		var next_level := level_count + 1
		if not ResourceLoader.exists(_tutorial_scene_path(next_level)):
			break
		level_count = next_level
	return level_count


func _load_tutorial_level_data(scene_path: String) -> Dictionary:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return {}
	var map_root: Node = packed.instantiate()
	var level_data := {
		"spawn": map_root.get("spawn") if map_root.get("spawn") is Vector2 else Vector2(90, 620),
		"action_limit": int(map_root.get("action_limit")) if map_root.get("action_limit") is int else 12,
		"hint": String(map_root.get("hint")) if map_root.get("hint") is String else "Use echoes to solve the chamber.",
		"platforms": map_root.get("platforms") if map_root.get("platforms") is Array else [],
		"falling_platforms": map_root.get("falling_platforms") if map_root.get("falling_platforms") is Array else [],
		"buttons": map_root.get("buttons") if map_root.get("buttons") is Array else [],
		"doors": map_root.get("doors") if map_root.get("doors") is Array else [],
		"lifts": map_root.get("lifts") if map_root.get("lifts") is Array else [],
		"hazards": map_root.get("hazards") if map_root.get("hazards") is Array else [],
		"exit": map_root.get("exit") if map_root.get("exit") is Rect2 else Rect2(950, 637, 50, 55),
	}
	_apply_minimum_action_limit(level_data)
	map_root.free()
	return level_data


func _load_next_level() -> void:
	var next_path := _next_tutorial_scene_path(String(GameState.selected_tutorial_scene_path))
	_load_level(next_path)


func _next_tutorial_scene_path(current_scene_path: String) -> String:
	var current_level := _extract_level_number(current_scene_path)
	return _tutorial_scene_path(current_level + 1)


func _extract_level_number(scene_path: String) -> int:
	var base := scene_path.get_file().get_basename()
	var parts := base.split("_")
	if parts.size() < 2:
		return 0
	return int(parts[1])


func _apply_minimum_action_limit(level: Dictionary) -> void:
	# Ensure the level is never mathematically impossible due to action_limit being too low.
	# This is a conservative floor based on straight-line distance-to-exit (not full pathfinding).
	var spawn: Vector2 = level.get("spawn", Vector2.ZERO)
	var exit_rect: Rect2 = level.get("exit", Rect2())
	var exit_center := exit_rect.position + exit_rect.size * 0.5

	var dx := absf(exit_center.x - spawn.x)
	var horizontal_actions := int(ceili(dx / STEP_DISTANCE_PX))

	# Only count upward travel; falling doesn't cost actions by itself.
	var dy_up := maxf(0.0, spawn.y - exit_center.y)
	var vertical_actions := int(ceili(dy_up / APPROX_JUMP_HEIGHT_PX))

	var estimated_min := horizontal_actions + vertical_actions
	var safe_limit := estimated_min + 3
	level["action_limit"] = maxi(int(level.get("action_limit", safe_limit)), safe_limit)
