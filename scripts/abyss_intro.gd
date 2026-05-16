extends CanvasLayer

## One-time glitch intro shown the first time the player enters Abyss mode.
## Emits done() when finished so the caller can proceed to the abyss select screen.

signal done

@export var glitch_text: String = "Youuuuu!!! againnnnnn.....\nYou must now Pay!!!!!!!!!!!!!!!"

const GLITCH_CHARS := "!@#$%^&*<>?/\\|~`[]{}0123456789"

@onready var _label: Label = $Center/Label
@onready var _bg: ColorRect = $BG

var _glitch_timer: float = 0.0
var _reveal_idx: int = 0
var _phase: int = 0   # 0 = glitch in, 1 = hold, 2 = glitch out
var _hold_timer: float = 0.0
var _glitch_interval: float = 0.04


func _ready() -> void:
	_label.text = ""
	_label.modulate = Color(1, 0.1, 0.15, 1)
	_bg.modulate = Color(0, 0, 0, 0)

	# Fade in background.
	var t := create_tween()
	t.tween_property(_bg, "modulate:a", 0.88, 0.3)
	await t.finished

	# Play roar sound before the text appears.
	var roar := AudioStreamPlayer.new()
	roar.stream = load("res://all_sounds/roarsound.mp3")
	roar.bus = "Master"
	add_child(roar)
	roar.play()

	_phase = 0
	set_process(true)


func _process(delta: float) -> void:
	match _phase:
		0:  # Glitch-reveal each character
			_glitch_timer -= delta
			if _glitch_timer <= 0.0:
				_glitch_timer = _glitch_interval
				_reveal_idx = mini(_reveal_idx + 1, glitch_text.length())
				_label.text = _build_glitch_text(_reveal_idx)
				if _reveal_idx >= glitch_text.length():
					_phase = 1
					_hold_timer = 2.8

		1:  # Hold — keep glitching the last few chars
			_glitch_timer -= delta
			if _glitch_timer <= 0.0:
				_glitch_timer = _glitch_interval * 2
				_label.text = _build_glitch_text(glitch_text.length(), 4)
			_hold_timer -= delta
			if _hold_timer <= 0.0:
				_phase = 2

		2:  # Glitch out
			_glitch_timer -= delta
			if _glitch_timer <= 0.0:
				_glitch_timer = _glitch_interval
				_reveal_idx = maxi(_reveal_idx - 2, 0)
				_label.text = _build_glitch_text(_reveal_idx)
				if _reveal_idx <= 0:
					set_process(false)
					_finish()


func _build_glitch_text(revealed: int, extra_noise: int = 2) -> String:
	var result := ""
	for i in range(revealed):
		result += glitch_text[i]
	# Add a few random glitch characters after the revealed portion.
	for _i in range(extra_noise):
		result += GLITCH_CHARS[randi() % GLITCH_CHARS.length()]
	# Random colour flicker on the label.
	var r := randf_range(0.8, 1.0)
	var g := randf_range(0.0, 0.2)
	_label.modulate = Color(r, g, 0.1, 1.0)
	return result


func _finish() -> void:
	var t := create_tween()
	t.tween_property(_bg, "modulate:a", 0.0, 0.4)
	await t.finished
	emit_signal("done")
	queue_free()
