extends Area2D

@export var button_id: String = "B1"
@onready var visual: ColorRect = $Visual

var pressed: bool = false
var bodies_touching: Array[Node] = []

func _ready() -> void:
	add_to_group("interactable")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	monitoring = true
	monitorable = true

func set_pressed(is_pressed: bool) -> void:
	pressed = is_pressed
	if visual:
		visual.color = Color(0.35, 0.95, 0.4, 1.0) if is_pressed else Color(0.88, 0.45, 0.25, 1.0)

func _on_body_entered(body: Node) -> void:
	print("PRESSURE PLATE hit by: ", body.name)
	if body.is_in_group("player"):
		if not bodies_touching.has(body):
			bodies_touching.append(body)
		print("Bodies touching gate/plate: ", bodies_touching)
		_check_trigger()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		bodies_touching.erase(body)
		print("Bodies touching gate/plate: ", bodies_touching)
		_check_trigger()

func _check_trigger() -> void:
	var is_pressed := bodies_touching.size() > 0
	set_pressed(is_pressed)

	# Find all lifts/gates in the scene that share this button_id and notify them
	var targets := get_tree().get_nodes_in_group("button_driven")
	for target in targets:
		if target.get("button_id") == button_id:
			if is_pressed and target.has_method("activate"):
				target.activate()
			elif not is_pressed and target.has_method("deactivate"):
				target.deactivate()
