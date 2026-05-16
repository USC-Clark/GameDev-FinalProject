extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ECHO_SCENE := preload("res://scenes/echo.tscn")
const TRAVERSE_SOLUTIONS := preload("res://scripts/traverse_solutions.gd")

const ROOM_W := 1280.0
const ROOM_H := 720.0
const ONE_WAY_PLATFORM_LAYER: int = 5

@onready var world: Node2D = $World
@onready var actors: Node2D = $Actors
@onready var ui_steps: Label = $CanvasLayer/UI/StepsLabel
@onready var ui_record: Label = $CanvasLayer/UI/RecordLabel
@onready var ui_level: Label = $CanvasLayer/UI/LevelLabel
@onready var ui_info: Label = $CanvasLayer/UI/InfoLabel
@onready var ui_complete: Label = $CanvasLayer/UI/CompleteLabel
@onready var reset_button: Button = $CanvasLayer/UI/ResetButton
@onready var solve_button: Button = $CanvasLayer/UI/SolveButton
@onready var pause_panel: Panel = $CanvasLayer/UI/PausePanel
@onready var back_button: Button = $CanvasLayer/UI/PausePanel/TraverseSelectButton

var _player: CharacterBody2D
var _echoes: Array[Node] = []

var _level_root: Node
var _spawn: Vector2 = Vector2(90, 620)
var _exit_area: Area2D
var _action_limit: int = 12
var _is_complete: bool = false
var _paused: bool = false
var _last_actions: int = 0

var _buttons: Array[Node] = [] # PressureButton
var _gates: Array[Node] = []   # Gate
var _lifts: Array[Node] = []   # LiftPlatform
var _hazards: Array[Area2D] = []

var _admin_mode: bool = false
var _solution_echo: Node
var _solution_frames: Array[Dictionary] = []
var _solution_step_idx: int = 0
var _solution_timer: float = 0.0
const SOLUTION_STEP_INTERVAL := 0.18

const TRAVERSE_LEVELS := [
	"res://scenes/traverse/level_01_split_commitment.tscn",
	"res://scenes/traverse/level_02_delayed_door.tscn",
	"res://scenes/traverse/level_03_lift_intro.tscn",
	"res://scenes/traverse/level_04_dual_pressure.tscn",
	"res://scenes/traverse/level_05_bridge_sequence.tscn",
	"res://scenes/traverse/level_06_vertical_relay.tscn",
	"res://scenes/traverse/level_07_gate_corridor.tscn",
	"res://scenes/traverse/level_08_echo_ladder.tscn",
	"res://scenes/traverse/level_09_mirror_towers.tscn",
	"res://scenes/traverse/level_10_master_chamber.tscn",
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_button.pressed.connect(func() -> void: _reset_level("Manual reset."))
	solve_button.pressed.connect(_on_solve_pressed)
	back_button.pressed.connect(func() -> void:
		_paused = false
		get_tree().paused = false
		pause_panel.visible = false
		GameState.go_to_traverse_select()
	)

	var idx := clampi(GameState.selected_traverse_level - 1, 0, TRAVERSE_LEVELS.size() - 1)
	_load_level(idx)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_level"):
		_reset_level("Manual reset.")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		_admin_mode = not _admin_mode
		solve_button.visible = _admin_mode
		ui_info.text = "Admin: %s" % ("ON (Solve available)" if _admin_mode else "OFF")
		return
	if event.is_action_pressed("toggle_record") and not _paused and not _is_complete:
		_toggle_recording()
		return
	if _is_complete and event.is_action_pressed("jump"):
		_load_level(GameState.selected_traverse_level) # next
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

	# Admin solution playback (auto-consume frames on a timer).
	if _solution_echo != null and is_instance_valid(_solution_echo) and not _solution_frames.is_empty():
		_solution_timer -= delta
		while _solution_timer <= 0.0 and _solution_step_idx < _solution_frames.size():
			if _solution_echo.has_method("consume_action"):
				_solution_echo.consume_action()
			_solution_step_idx += 1
			_solution_timer += SOLUTION_STEP_INTERVAL
		if _solution_step_idx >= _solution_frames.size():
			_solution_echo = null


func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	pause_panel.visible = _paused


func _load_level(index: int) -> void:
	if index >= TRAVERSE_LEVELS.size():
		ui_complete.visible = true
		ui_complete.text = "Traverse complete.\nMore levels soon."
		return

	GameState.selected_traverse_level = index + 1
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

	_level_root = load(TRAVERSE_LEVELS[index]).instantiate()
	world.add_child(_level_root)

	# Remove "boxed arena" walls at runtime (levels remain editable in editor).
	var walls := _level_root.get_node_or_null("Walls")
	if walls:
		walls.queue_free()

	_build_room_shell()

	_convert_static_platforms_to_platform_scene()
	_scan_level()
	_spawn_player()
	_reset_dynamic_nodes()

	ui_level.text = "Traverse %d" % (index + 1)
	ui_record.text = "Record: OFF"
	ui_info.text = "R = Toggle Record | Esc/Backspace = Reset | W = Next when complete"
	solve_button.visible = _admin_mode


func _convert_static_platforms_to_platform_scene() -> void:
	# Convert ONLY invisible platform colliders (no visible "Visual" node).
	# Visible authored platforms should remain as-is.
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

		# Detect "platform block" shape.
		var cs := child.get_node_or_null("CollisionShape2D")
		if cs == null or not (cs is CollisionShape2D):
			continue
		var cshape := cs as CollisionShape2D
		if cshape.shape == null or not (cshape.shape is RectangleShape2D):
			continue

		# Convert only if it's an "invisible block":
		# - no Visual node, OR
		# - Visual exists but is hidden / fully transparent.
		var vis := child.get_node_or_null("Visual")
		var is_invisible := false
		if vis == null:
			is_invisible = true
		elif vis is CanvasItem:
			var ci := vis as CanvasItem
			is_invisible = (not ci.visible) or (ci.modulate.a <= 0.01)
		if not is_invisible:
			continue

		# Treat near-ground invisible colliders as the floor.
		# Keep them (don't replace), but rename for clarity in the scene tree.
		var body2d := child as Node2D
		var rs_floor := cshape.shape as RectangleShape2D
		var floor_threshold_y := ROOM_H - 60.0
		if body2d.global_position.y >= floor_threshold_y or (body2d.global_position.y + rs_floor.size.y) >= (ROOM_H - 10.0):
			child.name = "Floor"
			continue

		var rs := cshape.shape as RectangleShape2D
		var size := rs.size
		var one_way_flag := bool(cshape.one_way_collision)

		# The authored blocks use body.position = rect.position and shape.position = rect.size*0.5.
		var rect := Rect2((child as Node2D).position, size)

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
	_action_limit = int(_level_root.get("action_limit")) if _level_root != null else 12
	if _action_limit <= 0:
		_action_limit = 12
	_spawn = Vector2(90, 620)
	_exit_area = null

	var spawn_node := _level_root.get_node_or_null("Spawn")
	if spawn_node and spawn_node is Node2D:
		_spawn = spawn_node.global_position

	_exit_area = _level_root.get_node_or_null("Exit") as Area2D

	_buttons.clear()
	for n in get_tree().get_nodes_in_group("pressure_button"):
		if n is Node and _level_root.is_ancestor_of(n):
			_buttons.append(n)

	_gates.clear()
	for n in get_tree().get_nodes_in_group("gate"):
		if n is Node and _level_root.is_ancestor_of(n):
			_gates.append(n)

	_lifts.clear()
	for n in get_tree().get_nodes_in_group("lift"):
		if n is Node and _level_root.is_ancestor_of(n):
			_lifts.append(n)

	var hazard_nodes := []
	for n in get_tree().get_nodes_in_group("hazard"):
		if n is Node and _level_root.is_ancestor_of(n):
			hazard_nodes.append(n)
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
		var target: Vector2 = lift.end if int(lift.dir) > 0 else lift.start
		lift.position = lift.position.move_toward(target, float(lift.speed) * delta)
		if lift.position.distance_to(target) <= 0.5:
			lift.dir = -int(lift.dir)
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
	_stop_solution_playback()
	ui_info.text = reason
	ui_record.text = "Record: OFF"


func _build_room_shell() -> void:
	# Ground like tutorial mode (no visible box walls).
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


func _on_solve_pressed() -> void:
	if not _admin_mode:
		return
	_stop_solution_playback()
	var level_num := GameState.selected_traverse_level
	var frames: Array[Dictionary] = TRAVERSE_SOLUTIONS.get_solution(level_num)
	if frames.is_empty():
		ui_info.text = "No admin solution recorded for Traverse %d." % level_num
		return

	# Reset player state so the solution echo is easy to watch.
	_player.cancel_recording()
	_player.reset_to_spawn()
	_player.reset_physics_interpolation()
	_player.force_update_transform()

	_solution_echo = ECHO_SCENE.instantiate()
	actors.add_child(_solution_echo)
	_solution_echo.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_solution_echo.setup(_spawn, frames)
	_solution_frames = frames
	_solution_step_idx = 0
	_solution_timer = SOLUTION_STEP_INTERVAL
	ui_info.text = "Admin solution playing (auto)."


func _stop_solution_playback() -> void:
	_solution_frames.clear()
	_solution_step_idx = 0
	_solution_timer = 0.0
	if _solution_echo != null and is_instance_valid(_solution_echo):
		_solution_echo.free()
	_solution_echo = null
