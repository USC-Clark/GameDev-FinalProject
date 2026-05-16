extends Control

@onready var grid: GridContainer = $Center/Panel/VBox/Grid
@onready var back_button: Button = $Center/Panel/VBox/BottomRow/BackButton

var _level_buttons: Array[Button] = []


func _ready() -> void:
	Progress._load()
	# Unlock level 1 the first time the player visits traverse mode.
	Progress.unlock_traverse()

	back_button.pressed.connect(func() -> void:
		GameState.go_to_mode_select()
	)
	_build_cards()
	_refresh_locks()


func _build_cards() -> void:
	for child in grid.get_children():
		child.queue_free()
	_level_buttons.clear()

	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.08, 0.08, 0.1, 0.92)
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6

	var style_disabled := StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.45, 0.45, 0.45, 0.6)
	style_disabled.corner_radius_top_left = 6
	style_disabled.corner_radius_top_right = 6
	style_disabled.corner_radius_bottom_left = 6
	style_disabled.corner_radius_bottom_right = 6

	for i in range(1, 11):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(130, 80)
		btn.add_theme_font_size_override("font_size", 25)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 1))
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		btn.text = str(i)
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.35)
		btn.pressed.connect(func(level_number := i) -> void:
			GameState.start_traverse(level_number)
		)
		grid.add_child(btn)
		_level_buttons.append(btn)


func _refresh_locks() -> void:
	for i in range(1, 11):
		var btn := _level_buttons[i - 1]
		var unlocked := Progress.is_traverse_unlocked(i)
		btn.disabled = not unlocked
		btn.modulate = Color(1, 1, 1, 1.0) if unlocked else Color(1, 1, 1, 0.35)
