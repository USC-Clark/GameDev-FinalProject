extends Node2D

## Monitors multiple Gateplate nodes and opens a target Gate only when
## ALL of them are simultaneously active (pressed).

@export var gate_node_name: String = "Gate4"
@export var watched_plates: Array[String] = []  # names of Gateplate siblings to watch

var _gate: Node = null
var _plates: Array[Node] = []


func _ready() -> void:
	_gate = get_parent().get_node_or_null(gate_node_name)
	if _gate == null:
		push_warning("MultiGateplate: could not find Gate node '%s'" % gate_node_name)
		return

	for plate_name in watched_plates:
		var plate := get_parent().get_node_or_null(plate_name)
		if plate != null:
			_plates.append(plate)
		else:
			push_warning("MultiGateplate: could not find plate '%s'" % plate_name)

	# Poll every physics frame — simple and reliable.
	set_physics_process(true)
	_gate.close_gate()


func _physics_process(_delta: float) -> void:
	if _gate == null:
		return
	var all_on := true
	for plate in _plates:
		# Gateplate shows $Ongate when active.
		var on_sprite := plate.get_node_or_null("Ongate")
		if on_sprite == null or not on_sprite.visible:
			all_on = false
			break
	if all_on:
		_gate.open_gate()
	else:
		_gate.close_gate()
