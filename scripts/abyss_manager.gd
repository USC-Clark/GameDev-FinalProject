extends Node2D

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const ECHO_SCENE   := preload("res://scenes/echo.tscn")

const ROOM_W := 1450.0
const ROOM_H := 900.0

@onready var world: Node2D          = $World
@onready var actors: Node2D         = $Actors
@onready var ui_steps: Label        = $CanvasLayer/UI/StepsLabel
@onready var ui_record: Label       = $CanvasLayer/UI/RecordLabel
@onready var ui_level: Label        = $CanvasLayer/UI/LevelLabel
@onready var ui_info: Label         = $CanvasLayer/UI/InfoLabel
@onready var ui_complete: Label     = $CanvasLayer/UI/CompletePanel/VBox/CompleteLabel
@onready var complete_panel: Panel  = $CanvasLayer/UI/CompletePanel
@onready var next_level_button: Button = $CanvasLayer/UI/CompletePanel/VBox/NextLevelButton
@onready var select_button: Button  = $CanvasLayer/UI/CompletePanel/VBox/SelectButton
@onready var reset_button: Button   = $CanvasLayer/UI/ResetButton
@onready var pause_panel: Panel     = $CanvasLayer/UI/PausePanel
@onready var back_button: Button    = $CanvasLayer/UI/PausePanel/AbyssSelectButton

const ABYSS_LEVELS := [
	"res://scenes/abyss/abyss_01_void_step.tscn",
	"res://scenes/abyss/abyss_02_gate_descent.tscn",
]

var _player: CharacterBody2D
var _echoes: Array[Node] = []
var _level_root: Node
var _spawn: Vector2 = Vector2(90, 620)
var _exit_area: Area2D
var _action_limit: int = 8
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
		GameState.go_to_abyss_select()
	)
	next_level_button.pressed.connect(func() -> void:
		complete_panel.visible = false
		_load_level(GameState.selected_abyss_level)
	)
	select_button.pressed.connect(func() -> void:
		complete_panel.visible = false
		GameState.go_to_abyss_select()
	)
	var idx := clampi(GameState.selected_abyss_level - 1, 0, ABYSS_LEVELS.size() - 1)
	_load_level(idx)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_level"):
		_reset_level("Manual reset.")
		return
	if event.is_action_pressed("toggle_record") and not _paused and not _is_complete:
		_toggle_recording()
		return
	if _is_complete and event.is_action_pressed("jump"):
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


func _load_level(index: int) -> void:
	if index >= ABYSS_LEVELS.size():
		complete_panel.visible = true
		next_level_button.visible = false
		ui_complete.text = "Abyss cleared!\nYou conquered the void."
		return

	GameState.selected_abyss_level = index + 1
	_is_complete = false
	complete_panel.visible = false
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

	_level_root = load(ABYSS_LEVELS[index]).instantiate()
	world.add_child(_level_root)

	_scan_level()
	_spawn_player()
	_reset_dynamic_nodes()

	MusicManager.play_track("res://Music/Abyss.mp3")

	ui_level.text = "Abyss %d" % (index + 1)
	ui_record.text = "Record: OFF"
	ui_info.text = "R = Toggle Record | Esc = Pause | Backspace = Reset"


func _scan_level() -> void:
	_action_limit = int(_level_root.get("action_limit")) if _level_root != null else 8
	if _action_limit <= 0:
		_action_limit = 8
	_spawn = Vector2(90, 620)
	_exit_area = null

	var spawn_node := _level_root.get_node_or_null("Spawn")
	if spawn_node and spawn_node is Node2D:
		_spawn = (spawn_node as Node2D).position

	_exit_area = _level_root.get_node_or_null("Exit") as Area2D

	var door_node := _level_root.get_node_or_null("Door")
	if _exit_area == null and door_node != null and door_node.has_signal("player_exited"):
		door_node.player_exited.connect(_on_door_opened_as_exit)

	_buttons.clear()
	_gates.clear()
	_lifts.clear()
	var hazard_nodes: Array[Node] = []
	_collect_interactables(_level_root, hazard_nodes)
	for h in hazard_nodes:
		if h is Area2D:
			_hazards.append(h)
			h.body_entered.connect(func(_b: Node) -> void:
				_reset_level("Hazard hit. Reset.")
			)


func _collect_interactables(node: Node, hazard_nodes: Array[Node]) -> void:
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
		_collect_interactables(child, hazard_nodes)


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
		_reset_dynamic_nodes()
		_player.reset_to_spawn()
		_player.reset_physics_interpolation()
		_player.force_update_transform()
	else:
		_player.reset_to_spawn()
		_player.reset_physics_interpolation()
		_player.force_update_transform()
		_reset_dynamic_nodes()
		_player.start_recording()


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
	pass


func _show_complete() -> void:
	_is_complete = true
	# If this is the final abyss level, show the glitch outro before the panel.
	if GameState.selected_abyss_level >= ABYSS_LEVELS.size():
		_show_outro()
		return
	# Level 1 — show a taunt then reveal the completion panel.
	if GameState.selected_abyss_level == 1:
		var intro := preload("res://scenes/abyss_intro.tscn").instantiate()
		intro.glitch_text = "Nicely Done but can you do the next time MUAHAHAHAHAHH!!!!"
		get_tree().root.add_child(intro)
		intro.done.connect(func() -> void:
			next_level_button.visible = true
			complete_panel.visible = true
			ui_complete.text = "Level Complete!"
		)
		return
	next_level_button.visible = true
	complete_panel.visible = true
	ui_complete.text = "Level Complete!"


func _show_outro() -> void:
	var intro := preload("res://scenes/abyss_intro.tscn").instantiate()
	intro.glitch_text = "NOOOOOOOOOO,\nI'll have my REVENGE SOOONNn!!!!!"
	get_tree().root.add_child(intro)
	intro.done.connect(func() -> void:
		next_level_button.visible = false
		complete_panel.visible = true
		ui_complete.text = "Abyss cleared!\nYou conquered the void."
	)


func _check_exit() -> void:
	if _exit_area == null:
		return
	if _exit_area.get_overlapping_bodies().has(_player):
		_show_complete()
		Progress.complete_abyss_level(GameState.selected_abyss_level)


func _on_door_opened_as_exit() -> void:
	_show_complete()
	Progress.complete_abyss_level(GameState.selected_abyss_level)


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
