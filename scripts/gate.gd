extends StaticBody2D

@export var button_ids: PackedStringArray = ["B1"]
@export var hold_turns: int = 0
@export var required_players: int = 1

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual: ColorRect = $Visual

var _remaining: int = 0
var is_open: bool = false
var players_on_gate: int = 0
var bodies_touching: Array[Node] = []
var _trigger_area: Area2D


func _ready() -> void:
	add_to_group("interactable")
	# Gate body trigger for Original + Pastself detection/debug.
	_ensure_trigger_area()
	if _trigger_area != null:
		_trigger_area.monitoring = true
		_trigger_area.monitorable = true
		# Player bodies use collision layer 1 in this project.
		_trigger_area.collision_mask = 1
		if not _trigger_area.body_entered.is_connected(_on_body_entered):
			_trigger_area.body_entered.connect(_on_body_entered)
		if not _trigger_area.body_exited.is_connected(_on_body_exited):
			_trigger_area.body_exited.connect(_on_body_exited)


func _ensure_trigger_area() -> void:
	var existing := get_node_or_null("TriggerArea")
	if existing != null and existing is Area2D:
		_trigger_area = existing as Area2D
		return

	# Create fallback trigger if the scene doesn't define one.
	_trigger_area = Area2D.new()
	_trigger_area.name = "TriggerArea"
	_trigger_area.collision_layer = 0
	add_child(_trigger_area)

	var trigger_shape := CollisionShape2D.new()
	trigger_shape.name = "CollisionShape2D"
	if collision != null and collision.shape != null:
		trigger_shape.shape = collision.shape.duplicate(true)
		trigger_shape.position = collision.position
	_trigger_area.add_child(trigger_shape)


func _on_body_entered(body: Node) -> void:
	print("Gate body entered: ", body.name)
	if body.is_in_group("player") or body.name == "Player":
		if not bodies_touching.has(body):
			bodies_touching.append(body)
		if body.name.to_lower().contains("past"):
			print("Pastself triggered: ", body.name)
		else:
			print("Original triggered: ", body.name)
		_check_trigger()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") or body.name == "Player":
		bodies_touching.erase(body)
		_check_trigger()


func _check_trigger() -> void:
	players_on_gate = bodies_touching.size()
	print("Gate players count: ", players_on_gate)
	print("Bodies touching gate/plate: ", bodies_touching)
	if players_on_gate >= required_players:
		set_open(true)
	else:
		set_open(false)


func set_open(open: bool) -> void:
	is_open = open
	if collision:
		collision.disabled = open
	if visual:
		visual.modulate.a = 0.4 if open else 1.0
		visual.color = Color(0.15, 0.95, 0.25, 1.0) if open else Color(0.8, 0.18, 0.22, 1.0)


func tick_timer(should_open: bool) -> bool:
	# Matches tutorial door behavior: optional delayed close.
	if should_open and hold_turns > 0:
		_remaining = hold_turns
	elif not should_open and _remaining > 0:
		_remaining -= 1
		return true
	return should_open


func reset_timer() -> void:
	_remaining = 0
