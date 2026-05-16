extends Node2D

# Optional: set this in the Inspector to the Gate node.
# If left empty, the plate will look for a sibling node named "Gate".
@export var gate_node_name: String = "Gate"

var _gate: Node = null
var _player_count: int = 0


func _ready() -> void:
	# Find the gate — first try the export name, then search the parent.
	if gate_node_name != "":
		_gate = get_parent().get_node_or_null(gate_node_name)

	if _gate == null:
		push_warning("Gateplate: could not find Gate node named '%s'" % gate_node_name)

	var detect: Area2D = $Detect
	detect.collision_layer = 0
	detect.collision_mask = 1  # Player is on layer 1
	detect.monitoring = true
	detect.monitorable = false
	detect.body_entered.connect(_on_body_entered)
	detect.body_exited.connect(_on_body_exited)

	_set_active(false)


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_count += 1
	if _player_count == 1:
		_set_active(true)
		if _gate and _gate.has_method("open_gate"):
			_gate.open_gate()


func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_count = maxi(_player_count - 1, 0)
	if _player_count == 0:
		_set_active(false)
		if _gate and _gate.has_method("close_gate"):
			_gate.close_gate()


func _set_active(active: bool) -> void:
	$Ongate.visible = active
	$Offgate.visible = not active
