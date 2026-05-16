extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ECHO_SCENE := preload("res://scenes/echo.tscn")
const ROOM_W := 1450.0
const ROOM_H := 900.0
const TUTORIAL_MAP_DIR := "res://scenes/maps/tutorial"

@onready var world: Node2D = $World
@onready var actors: Node2D = $Actors
@onready var ui_steps: Label = $CanvasLayer/UI/StepsLabel
@onready var ui_record: Label = $CanvasLayer/UI/RecordLabel
@onready var ui_level: Label = $CanvasLayer/UI/LevelLabel
@onready var ui_info: Label = $CanvasLayer/UI/InfoLabel
@onready var ui_complete: Label = $OverlayLayer/CompletePanel/VBox/CompleteLabel
@onready var complete_panel: Panel = $OverlayLayer/CompletePanel
@onready var next_level_button: Button = $OverlayLayer/CompletePanel/VBox/NextLevelButton
@onready var select_button: Button = $OverlayLayer/CompletePanel/VBox/SelectButton
@onready var reset_button: Button = $CanvasLayer/UI/ResetButton
@onready var pause_panel: Panel = $OverlayLayer/PausePanel
@onready var back_button: Button = $OverlayLayer/PausePanel/TutorialSelectButton

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
	# Safety — ensure input is never blocked when entering a level.
	get_tree().root.set_disable_input(false)
	reset_button.pressed.connect(func() -> void: _reset_level("Manual reset."))
	back_button.pressed.connect(func() -> void:
		_paused = false
		get_tree().paused = false
		pause_panel.visible = false
		GameState.go_to_tutorial_select()
	)
	next_level_button.pressed.connect(func() -> void:
		complete_panel.visible = false
		_load_level(_next_tutorial_scene_path(String(GameState.selected_tutorial_scene_path)))
	)
	select_button.pressed.connect(func() -> void:
		complete_panel.visible = false
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
	print("_load_level called with: ", scene_path)
	if not ResourceLoader.exists(scene_path):
		complete_panel.visible = true
		next_level_button.visible = false
		ui_complete.text = "Tutorial complete."
		return

	var packed := load(scene_path) as PackedScene
	if packed == null:
		complete_panel.visible = true
		next_level_button.visible = false
		ui_complete.text = "Failed to load tutorial scene."
		return

	var level_number := _extract_level_number(scene_path)
	GameState.selected_tutorial_level = maxi(level_number, 1)
	GameState.selected_tutorial_scene_path = scene_path

	_is_complete = false
	complete_panel.visible = false
	get_tree().paused = false
	_paused = false
	pause_panel.visible = false

	for child in world.get_children():
		child.free()
	for child in actors.get_children():
		child.free()

	_echoes.clear()
	_buttons.clear()
	_gates.clear()
	_lifts.clear()
	_hazards.clear()
	_last_actions = 0

	# Instantiate level scene and add directly to world.
	# The TileMap/TileMapLayer nodes stay inside the level root.
	_level_root = packed.instantiate()
	world.add_child(_level_root)

	_build_room_shell()
	_scan_level()
	_spawn_player()
	_reset_dynamic_nodes()

	# Restart music from the beginning for this level.
	MusicManager.play()

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


func _scan_level() -> void:
	if _level_root == null:
		return
	_action_limit = _as_int(_level_root.get("action_limit"), 12)
	if _action_limit <= 0:
		_action_limit = 12
	_spawn = Vector2(90, 620)
	_exit_area = null

	var spawn_node := _level_root.get_node_or_null("Spawn")
	if spawn_node and spawn_node is Node2D:
		# global_position is unreliable immediately after add_child().
		# Since world is at (0,0) and level_root has no position offset,
		# the spawn node's local position equals its world position.
		_spawn = spawn_node.position

	_exit_area = _level_root.get_node_or_null("Exit") as Area2D

	if _exit_area == null:
		var exit_portal := _level_root.get_node_or_null("ExitPortal")
		if exit_portal != null and exit_portal.has_signal("level_exit_triggered"):
			exit_portal.level_exit_triggered.connect(_on_portal_exit_triggered)
			print("Tutorial Manager: Using portal exit system")

	# If no Area2D exit, check for a Door node that acts as the exit when opened.
	if _exit_area == null:
		var door_node := _level_root.get_node_or_null("Door")
		if door_node != null and door_node.has_signal("player_exited"):
			door_node.player_exited.connect(_on_door_opened_as_exit)
			print("Tutorial Manager: Door is the level exit")

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
		# Reset platforms so the echo replays against the same platform positions
		# that existed when recording started.
		_reset_dynamic_nodes()
		_player.reset_to_spawn()
		_player.reset_physics_interpolation()
		_player.force_update_transform()
		ui_record.text = "Record: OFF"
		ui_info.text = "Echo created. Cooperate with your past self."
	else:
		_player.reset_to_spawn()
		_player.reset_physics_interpolation()
		_player.force_update_transform()
		# Reset platforms to start position before recording begins.
		_reset_dynamic_nodes()
		_player.start_recording()
		ui_record.text = "Record: ON"
		ui_info.text = "Recording started from spawn."


func _on_actions_changed(current: int, limit: int) -> void:
	ui_steps.text = "Actions: %d / %d" % [current, limit]
	if current > _last_actions:
		var delta_actions := current - _last_actions
		for lift in _lifts:
			var start_on_action = lift.get("start_on_action")
			if start_on_action != null and start_on_action:
				lift.set("started", true)
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


func _update_lift(_lift: Node, _delta: float) -> void:
	# lift_platform.gd drives itself via _physics_process.
	# Nothing to do here — movement is handled by the platform script directly.
	pass


func _check_exit() -> void:
	if _exit_area == null:
		return
	if _exit_area.get_overlapping_bodies().has(_player):
		_is_complete = true
		next_level_button.visible = true
		complete_panel.visible = true
		ui_complete.text = "Level Complete!"
		Progress.complete_tutorial_level(GameState.selected_tutorial_level)


func _on_portal_exit_triggered(body: Node2D) -> void:
	if body == _player:
		_is_complete = true
		next_level_button.visible = true
		complete_panel.visible = true
		ui_complete.text = "Level Complete!"
		Progress.complete_tutorial_level(GameState.selected_tutorial_level)


func _on_door_opened_as_exit() -> void:
	# Player walked into the open door — show completion panel.
	_is_complete = true
	Progress.complete_tutorial_level(GameState.selected_tutorial_level)
	next_level_button.visible = true
	complete_panel.visible = true
	ui_complete.text = "Level Complete!"


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
	# Reset any chests in the current level.
	if _level_root:
		for node in _level_root.get_children():
			if node.has_method("reset"):
				node.reset()
	ui_info.text = reason
	ui_record.text = "Record: OFF"


func _build_room_shell() -> void:
	# Left wall
	var left := StaticBody2D.new()
	left.position = Vector2(-12.0, 0.0)
	left.collision_layer = 4
	left.collision_mask = 0
	world.add_child(left)
	var ls := CollisionShape2D.new()
	var lr := RectangleShape2D.new()
	lr.size = Vector2(12.0, ROOM_H)
	ls.shape = lr
	ls.position = lr.size * 0.5
	left.add_child(ls)

	# Right wall
	var right := StaticBody2D.new()
	right.position = Vector2(ROOM_W, 0.0)
	right.collision_layer = 4
	right.collision_mask = 0
	world.add_child(right)
	var rs := CollisionShape2D.new()
	var rr := RectangleShape2D.new()
	rr.size = Vector2(12.0, ROOM_H)
	rs.shape = rr
	rs.position = rr.size * 0.5
	right.add_child(rs)

	# Ceiling
	var ceiling := StaticBody2D.new()
	ceiling.position = Vector2(0.0, -12.0)
	ceiling.collision_layer = 4
	ceiling.collision_mask = 0
	world.add_child(ceiling)
	var cs := CollisionShape2D.new()
	var cr := RectangleShape2D.new()
	cr.size = Vector2(ROOM_W, 12.0)
	cs.shape = cr
	cs.position = cr.size * 0.5
	ceiling.add_child(cs)
	# NO FLOOR - TileMap handles it
	print("Room shell boundaries added")


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
