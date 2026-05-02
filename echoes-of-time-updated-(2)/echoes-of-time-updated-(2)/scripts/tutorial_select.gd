extends Control

@onready var grid: GridContainer = $Center/Panel/VBox/Grid
@onready var admin_label: Label = $Center/Panel/VBox/AdminLabel
@onready var back_button: Button = $Center/Panel/VBox/BottomRow/BackButton
@onready var reset_progress_button: Button = $Center/Panel/VBox/BottomRow/ResetProgressButton

var _level_buttons: Array[Button] = []


func _ready() -> void:
	# Re-load progress on entry so locks always reflect the save file.
	Progress._load()
	back_button.pressed.connect(func() -> void:
		GameState.go_to_mode_select()
	)
	reset_progress_button.pressed.connect(_reset_progress)
	_build_cards()
	_refresh_locks()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F:
			Progress.toggle_admin_unlock()
			_refresh_locks()


func _build_cards() -> void:
	for child in grid.get_children():
		child.queue_free()
	_level_buttons.clear()

	for i in range(1, 11):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(180, 92)
		btn.add_theme_font_size_override("font_size", 28)
		btn.text = str(i)
		btn.focus_mode = Control.FOCUS_ALL
		# Default to locked until _refresh_locks applies the real state.
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.35)
		btn.pressed.connect(func(level_number := i) -> void:
			GameState.start_tutorial(level_number)
		)
		grid.add_child(btn)
		_level_buttons.append(btn)


func _refresh_locks() -> void:
	admin_label.text = "Admin Unlock (F): %s" % ("ON" if Progress.admin_unlock else "OFF")
	for i in range(1, 11):
		var btn := _level_buttons[i - 1]
		var unlocked := Progress.is_tutorial_unlocked(i)
		btn.disabled = not unlocked
		btn.modulate = Color(1, 1, 1, 1.0) if unlocked else Color(1, 1, 1, 0.35)


func _reset_progress() -> void:
	Progress.reset_tutorial_progress()
	_refresh_locks()
