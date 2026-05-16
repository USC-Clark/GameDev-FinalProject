extends CanvasLayer

const _BUTTON_ACTIONS := {
	"Control/DPad/Left":  "move_left",
	"Control/DPad/Right": "move_right",
	"Control/DPad/Down":  "move_down",
	"Control/Record":     "toggle_record",
	"Control/Jump":       "jump",
}

# finger_index -> action name currently held by that finger
var _finger_action: Dictionary = {}


func _ready() -> void:
	if not DisplayServer.is_touchscreen_available():
		visible = false
		return

	for path in _BUTTON_ACTIONS:
		var btn := get_node_or_null(path) as Control
		if btn:
			btn.mouse_filter = Control.MOUSE_FILTER_STOP

	var menu_btn := get_node_or_null("Control/MenuButton") as Button
	if menu_btn:
		menu_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		menu_btn.pressed.connect(_on_menu_pressed)


func _on_menu_pressed() -> void:
	_release_all()
	_send(InputEventAction.new(), "ui_cancel", true)
	await get_tree().process_frame
	_send(InputEventAction.new(), "ui_cancel", false)


func _release_all() -> void:
	for finger in _finger_action.keys():
		_send(InputEventAction.new(), _finger_action[finger], false)
	_finger_action.clear()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_finger_down(touch.index, touch.position)
		else:
			_on_finger_up(touch.index)
		get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_on_finger_move(drag.index, drag.position)
		get_viewport().set_input_as_handled()


func _on_finger_down(finger: int, pos: Vector2) -> void:
	var action := _action_at(pos)

	# If this finger was already holding something, release it first.
	if _finger_action.has(finger):
		var prev: String = _finger_action[finger]
		if prev != action:
			_send(InputEventAction.new(), prev, false)
			_finger_action.erase(finger)

	if action != "":
		_finger_action[finger] = action
		_send(InputEventAction.new(), action, true)


func _on_finger_move(finger: int, pos: Vector2) -> void:
	var action := _action_at(pos)
	var held: String = _finger_action.get(finger, "")
	if held == action:
		return
	# Finger slid off to a different zone.
	if held != "":
		_send(InputEventAction.new(), held, false)
	_finger_action[finger] = action
	if action != "":
		_send(InputEventAction.new(), action, true)


func _on_finger_up(finger: int) -> void:
	if _finger_action.has(finger):
		_send(InputEventAction.new(), _finger_action[finger], false)
		_finger_action.erase(finger)


func _action_at(pos: Vector2) -> String:
	for path in _BUTTON_ACTIONS:
		var btn := get_node_or_null(path) as Control
		if btn == null or not btn.visible:
			continue
		if btn.get_global_rect().has_point(pos):
			return _BUTTON_ACTIONS[path]
	return ""


func _send(ev: InputEventAction, action: String, pressed: bool) -> void:
	if get_tree().paused and action != "ui_cancel":
		return
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)
