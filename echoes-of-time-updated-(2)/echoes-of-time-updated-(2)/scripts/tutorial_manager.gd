extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ECHO_SCENE := preload("res://scenes/echo.tscn")
const ROOM_W := 1280.0
const ROOM_H := 720.0
const TUTORIAL_MAP_DIR := "res://scenes/maps/tutorial"

@onready var world: Node2D = $World
@onready var actors: Node2D = $Actors
@onready var ui_steps: Label = $CanvasLayer/UI/StepsLabel
@onready var ui_record: Label = $CanvasLayer/UI/RecordLabel
@onready var ui_level: Label = $CanvasLayer/UI/LevelLabel
@onready var ui_info: Label = $CanvasLayer/UI/InfoLabel
@onready var ui_complete: Label = $CanvasLayer/UI/CompleteLabel
@onready var reset_button: Button = $CanvasLayer/UI/ResetButton
@onready var pause_panel: Panel = $CanvasLayer/UI/PausePanel
@onready var back_button: Button = $CanvasLayer/UI/PausePanel/TutorialSelectButton

var _player: CharacterBody2D
var _echoes: Array[Node] = []

var _level_root: Node
var _spawn: Vector2 = Vector2(90, 620)
var _exit_area: Area2D
var _action_limit: int = 12
var _is_complete: bool = false
var _paused: bool = false
var _last_actions: int = 0

var _buttons: Array[Node] = []
var _gates: Array[Node] = []
var _lifts: Array[Node] = []
var _hazards: Array[Area2D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_button.pressed.connect(func() -> void: _reset_level("Manual reset."))
	back_button.pressed.connect(func() -> void:
		_paused = false
		get_tree().paused = false
		pause_panel.visible = false
		GameState.go_to_tutorial_select()
	)

	var start_scene_path := String(GameState.selected_tutorial_scene_path)
	if start_scene_path == "":
		start_scene_path = _tutorial_scene_path(_as_int(GameState.selected_tutorial_level, 1))
	_load_level(start_scene_path)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_level"):
		_reset_level("Manual reset.")
		return
	if event.is_action_pressed("toggle_record") and not _paused and not _is_complete:
		_toggle_recording()
		return
	if _is_complete and event.is_action_pressed("jump"):
		_load_level(_next_tutorial_scene_path(String(GameState.selected_tutorial_scene_path)))
		return
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _physics_process(_delta: float) -> void:
	if _paused or _is_complete or _player == null:
		return
	_update_buttons()
	_update_gates()
	_check_exit()


func _process(delta: float) -> void:
	if _paused:
		return
	for lift in _lifts:
		if not (lift is Node):
			continue
		_update_lift(lift, delta)


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	pause_panel.visible = _paused


func _load_level(scene_path: String) -> void:
	if not ResourceLoader.exists(scene_path):
		ui_complete.visible = true
		ui_complete.text = "Tutorial complete."
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		ui_complete.visible = true
		ui_complete.text = "Failed to load tutorial scene."
		return

	var level_number := _extract_level_number(scene_path)
	GameState.selected_tutorial_level = maxi(level_number, 1)
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
	_gates.clear()
	_lifts.clear()
	_hazards.clear()
	_last_actions = 0

	_level_root = packed.instantiate()
	world.add_child(_level_root)

	var walls := _level_root.get_node_or_null("Walls")
	if walls:
		walls.queue_free()

	_build_room_shell()
	_convert_static_platforms_to_platform_scene()
	_scan_level()
	_spawn_player()
	_reset_dynamic_nodes()

	ui_level.text = "Tutorial %d" % maxi(level_number, 1)
	ui_record.text = "Record: OFF"
	ui_info.text = "R = Toggle Record | Esc/Backspace = Reset | W = Next when complete"


func _tutorial_scene_path(level_number: int) -> String:
	return "%s/tutorial_%02d.tscn" % [TUTORIAL_MAP_DIR, level_number]


func _next_tutorial_scene_path(current_scene_path: String) -> String:
	return _tutorial_scene_path(_extract_level_number(current_scene_path) + 1)


func _extract_level_number(scene_path: String) -> int:
	var base := scene_path.get_file().get_basename()
	var parts := base.split("_")
	if parts.size() < 2:
		return 0
	return _as_int(parts[1], 0)


func _convert_static_platforms_to_platform_scene() -> void:
	if _level_root == null:
		return
	_convert_platforms_recursive(_level_root)


func _convert_platforms_recursive(node: Node) -> void:
	for child in node.get_children():
		_convert_platforms_recursive(child)

		if not (child is StaticBody2D):
			continue
		if child.name == "Gate":
			continue
		if child.name == "Walls":
			continue

		var cs := child.get_node_or_null("CollisionShape2D")
		if cs == null or not (cs is CollisionShape2D):
			continue
		var cshape := cs as CollisionShape2D
		if cshape.shape == null or not (cshape.shape is RectangleShape2D):
			continue

		var vis := child.get_node_or_null("Visual")
		var is_invisible := false
		if vis == null:
			is_invisible = true
		elif vis is CanvasItem:
			var ci := vis as CanvasItem
			is_invisible = (not ci.visible) or (ci.modulate.a <= 0.01)
		if not is_invisible:
			continue

		var body2d := child as Node2D
		var rs_floor := cshape.shape as RectangleShape2D
		var floor_threshold_y := ROOM_H - 60.0
		if body2d.global_position.y >= floor_threshold_y or (body2d.global_position.y + rs_floor.size.y) >= (ROOM_H - 10.0):
			child.name = "Floor"
			continue

		var rs := cshape.shape as RectangleShape2D
		var one_way_flag := bool(cshape.one_way_collision)
		var rect := Rect2((child as Node2D).position, rs.size)

		var body := StaticBody2D.new()
		body.position = rect.position
		body.collision_layer = 16 if one_way_flag else 4
		body.collision_mask = 0
		(child as Node).add_sibling(body)
		
		var new_shape := CollisionShape2D.new()
		var new_rect_shape := RectangleShape2D.new()
		new_rect_shape.size = rect.size
		new_shape.shape = new_rect_shape
		new_shape.position = rect.size * 0.5
		new_shape.one_way_collision = one_way_flag
		if one_way_flag:
			new_shape.one_way_collision_margin = 6.0
		body.add_child(new_shape)
		
		var new_vis := ColorRect.new()
		new_vis.position = Vector2.ZERO
		new_vis.size = rect.size
		var tint := Color(0.24, 0.3, 0.42, 1.0)
		if vis is ColorRect:
			tint = (vis as ColorRect).color
		new_vis.color = tint
		body.add_child(new_vis)

		child.queue_free()


func _scan_level() -> void:
	if _level_root != null:
		_action_limit = _as_int(_level_root.get("action_limit"), 12)
	else:
		_action_limit = 12
	if _action_limit <= 0:
		_action_limit = 12
	_spawn = Vector2(90, 620)
	_exit_area = null

	var spawn_node := _level_root.get_node_or_null("Spawn")
	if spawn_node and spawn_node is Node2D:
		_spawn = spawn_node.global_position

	# Try to find Exit Area2D (old system)
	_exit_area = _level_root.get_node_or_null("Exit") as Area2D
	
	# If no Exit Area2D, look for ExitPortal (new system)
	if _exit_area == null:
		var exit_portal := _level_root.get_node_or_null("ExitPortal")
		if exit_portal != null and exit_portal.has_signal("level_exit_triggered"):
			# Connect portal exit signal
			exit_portal.level_exit_triggered.connect(_on_portal_exit_triggered)
			print("Tutorial Manager: Using portal exit system")

	_buttons.clear()
	_gates.clear()
	_lifts.clear()
	var hazard_nodes: Array[Node] = []
	_collect_level_interactables(_level_root, hazard_nodes)
	for h in hazard_nodes:
		if h is Area2D:
			_hazards.append(h)
			h.body_entered.connect(func(_b: Node) -> void:
				_reset_level("Hazard hit. Reset.")
			)


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate()
	actors.add_child(_player)
	_player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_player.setup(_spawn, _action_limit)
	_player.reset_physics_interpolation()
	_player.force_update_transform()
	_player.action_used.connect(_on_actions_changed)
	_player.recording_toggled.connect(func(is_on: bool) -> void:
		ui_record.text = "Record: %s" % ("ON" if is_on else "OFF")
	)
	_player.action_limit_exceeded.connect(func() -> void:
		_reset_level("Action limit exceeded.")
	)


func _toggle_recording() -> void:
	if _player.is_recording():
		var recorded: Array[Dictionary] = _player.stop_recording()
		if not recorded.is_empty():
			var echo := ECHO_SCENE.instantiate()
			actors.add_child(echo)
			echo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			echo.setup(_spawn, recorded)
			_echoes.append(echo)
		_player.reset_to_spawn()
		_player.reset_physics_interpolation()
		_player.force_update_transform()
	else:
		_player.reset_to_spawn()
		_player.reset_physics_interpolation()
		_player.force_update_transform()
		_player.start_recording()


func _on_actions_changed(current: int, limit: int) -> void:
	ui_steps.text = "Actions: %d / %d" % [current, limit]
	if current > _last_actions:
		var delta_actions := current - _last_actions
		for lift in _lifts:
			if bool(lift.get("start_on_action")):
				lift.started = true
		for _i in range(delta_actions):
			for echo in _echoes:
				if echo.has_method("consume_action"):
					echo.consume_action()
	_last_actions = current


func _is_button_pressed(id: String) -> bool:
	for b in _buttons:
		if b.has_method("get") and String(b.button_id) == id:
			return bool(b.pressed)
	return false


func _update_buttons() -> void:
	for b in _buttons:
		if not (b is Area2D):
			continue
		var pressed := false
		for body in (b as Area2D).get_overlapping_bodies():
			if body == _player or _echoes.has(body):
				pressed = true
				break
		b.set_pressed(pressed)


func _update_gates() -> void:
	for g in _gates:
		if not g.has_method("set_open"):
			continue
		var should_open := true
		for id in g.button_ids:
			if not _is_button_pressed(String(id)):
				should_open = false
				break
		if g.has_method("tick_timer"):
			should_open = g.tick_timer(should_open)
		g.set_open(should_open)


func _update_lift(lift: Node, delta: float) -> void:
	if not (lift is AnimatableBody2D):
		return
	var is_auto: bool = bool(lift.get("auto"))
	var button_id: String = String(lift.get("button_id"))
	var start_on_action: bool = bool(lift.get("start_on_action"))
	if is_auto:
		if start_on_action and not bool(lift.get("started")):
			return
		var target: Vector2 = lift.end if _as_int(lift.dir, 1) > 0 else lift.start
		lift.position = lift.position.move_toward(target, float(lift.speed) * delta)
		if lift.position.distance_to(target) <= 0.5:
			lift.dir = -_as_int(lift.dir, 1)
	else:
		var pressed := _is_button_pressed(button_id)
		var target: Vector2 = lift.end if pressed else lift.start
		lift.position = lift.position.move_toward(target, float(lift.speed) * delta)


func _check_exit() -> void:
	if _exit_area == null:
		return
	if _exit_area.get_overlapping_bodies().has(_player):
		_is_complete = true
		ui_complete.visible = true
		ui_complete.text = "Level Complete!\nPress W to continue."
		Progress.complete_tutorial_level(GameState.selected_tutorial_level)


func _on_portal_exit_triggered(body: Node2D) -> void:
	# Called when player enters an exit portal
	if body == _player:
		_is_complete = true
		ui_complete.visible = true
		ui_complete.text = "Level Complete!\nPress W to continue."
		Progress.complete_tutorial_level(GameState.selected_tutorial_level)


func _reset_dynamic_nodes() -> void:
	for g in _gates:
		if g.has_method("reset_timer"):
			g.reset_timer()
		if g.has_method("set_open"):
			g.set_open(false)
	for b in _buttons:
		if b.has_method("set_pressed"):
			b.set_pressed(false)
	for lift in _lifts:
		if lift.has_method("reset_to_initial"):
			lift.reset_to_initial()


func _reset_level(reason: String) -> void:
	for echo in _echoes:
		if is_instance_valid(echo):
			echo.free()
	_echoes.clear()
	_player.cancel_recording()
	_player.reset_to_spawn()
	_player.reset_physics_interpolation()
	_player.force_update_transform()
	_last_actions = 0
	_reset_dynamic_nodes()
	ui_info.text = reason
	ui_record.text = "Record: OFF"


func _build_room_shell() -> void:
	var rect := Rect2(0.0, ROOM_H - 28.0, ROOM_W, 28.0)
	var body := StaticBody2D.new()
	body.position = rect.position
	body.collision_layer = 4
	body.collision_mask = 0
	world.add_child(body)
	
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = rect.size
	shape.shape = rect_shape
	shape.position = rect.size * 0.5
	body.add_child(shape)
	
	var vis := ColorRect.new()
	vis.position = Vector2.ZERO
	vis.size = rect.size
	vis.color = Color(0.2, 0.24, 0.31, 1.0)
	body.add_child(vis)


func _as_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	if value is int:
		return value
	if value is float:
		return int(round(value))
	var text := String(value)
	if text.is_valid_int():
		return text.to_int()
	return fallback


func _collect_level_interactables(node: Node, hazard_nodes: Array[Node]) -> void:
	if node == null:
		return
	if node.is_in_group("pressure_button") or (node is Area2D and node.has_method("set_pressed") and node.get("button_id") != null):
		_buttons.append(node)
	if node.is_in_group("gate") or (node is StaticBody2D and node.has_method("set_open") and node.get("button_ids") != null):
		_gates.append(node)
	if node.is_in_group("lift") or (node is AnimatableBody2D and node.has_method("reset_to_initial")):
		_lifts.append(node)
	if node.is_in_group("hazard"):
		hazard_nodes.append(node)
	for child in node.get_children():
		_collect_level_interactables(child, hazard_nodes)
