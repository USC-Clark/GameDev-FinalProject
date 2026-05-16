extends CanvasLayer

signal dialogue_finished

const TYPEWRITER_SPEED := 0.03

## If true, touch controls are hidden during dialogue and restored on finish.
## Set to false if you want to manage controls manually (e.g. tutorial_01 demo).
var restore_controls_on_finish: bool = true

@onready var _root: Control             = $Root
@onready var _portrait: TextureRect     = $Root/Anchor/Portrait
@onready var _name_label: Label         = $Root/Anchor/Bubble/Margin/VBox/NameLabel
@onready var _text_label: RichTextLabel = $Root/Anchor/Bubble/Margin/VBox/DialogueLabel
@onready var _tap_hint: Button          = $Root/Anchor/Bubble/Margin/VBox/TapHint
@onready var _dialogue_sound: AudioStreamPlayer = $DialogueSound

var _lines: Array[Dictionary] = []
var _current: int = 0
var _typing: bool = false
var _full_text: String = ""
var _timer: float = 0.0
var _char_idx: int = 0
var _is_player_speaking: bool = false


func _ready() -> void:
	# Run even when the tree is paused so the box stays visible.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root.visible = false
	_tap_hint.visible = false
	(_tap_hint as Button).pressed.connect(_on_next_pressed)
	_dialogue_sound.stream = load("res://all_sounds/DIALOGUE_SOUND.mp3")
	_dialogue_sound.volume_db = 6.0


func show_dialogue(lines: Array) -> void:
	_lines.clear()
	for l in lines:
		_lines.append(l)
	_current = 0
	_root.visible = true
	_set_player_blocked(true)
	_set_touch_controls_visible(false)
	_show_line(_current)


func _show_line(idx: int) -> void:
	if idx >= _lines.size():
		_finish()
		return
	var line: Dictionary = _lines[idx]
	_name_label.text = line.get("name", "")
	_full_text = line.get("text", "")
	_text_label.text = ""
	_char_idx = 0
	_typing = true
	_tap_hint.visible = false
	_is_player_speaking = (line.get("name", "") == "Player")
	_dialogue_sound.stop()
	if line.has("portrait"):
		_portrait.texture = load(line["portrait"])


func _process(delta: float) -> void:
	# Freeze typewriter while the game is paused, and stop dialogue sound.
	if get_tree().paused:
		if _dialogue_sound.playing:
			_dialogue_sound.stop()
		return
	# Resume sound if we were typing when pause was lifted.
	if _typing and _is_player_speaking and not _dialogue_sound.playing:
		_dialogue_sound.play()
	if not _typing:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = TYPEWRITER_SPEED
		if _char_idx < _full_text.length():
			_char_idx += 1
			_text_label.text = _full_text.left(_char_idx)
			if _is_player_speaking and not _dialogue_sound.playing:
				_dialogue_sound.play()
		else:
			_typing = false
			_tap_hint.visible = true
			_dialogue_sound.stop()


func _on_next_pressed() -> void:
	# Block advancing while paused.
	if get_tree().paused:
		return
	_advance()


func _advance() -> void:
	if _typing:
		_typing = false
		_text_label.text = _full_text
		_tap_hint.visible = true
		_dialogue_sound.stop()
	else:
		_current += 1
		_show_line(_current)


func _finish() -> void:
	_dialogue_sound.stop()
	_root.visible = false
	_set_player_blocked(false)
	if restore_controls_on_finish:
		_set_touch_controls_visible(true)
	emit_signal("dialogue_finished")
	queue_free()


func _set_touch_controls_visible(visible_state: bool) -> void:
	var tc := get_tree().get_root().find_child("TouchControls", true, false)
	if tc:
		tc.visible = visible_state


func _set_player_blocked(blocked: bool) -> void:
	var players := get_tree().get_nodes_in_group("player")
	for p in players:
		if p is Node:
			p.set_physics_process(not blocked)
			p.set_process(not blocked)
			p.set_process_unhandled_input(not blocked)
