extends Control

@onready var grid: GridContainer = $Center/Panel/VBox/Grid
@onready var back_button: Button = $Center/Panel/VBox/BottomRow/BackButton

var _level_buttons: Array[Button] = []


func _ready() -> void:
	Progress._load()
	Progress.unlock_abyss()

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
	style_normal.bg_color = Color(0.08, 0.05, 0.12, 0.92)
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6

	var style_disabled := StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.3, 0.3, 0.35, 0.5)
	style_disabled.corner_radius_top_left = 6
	style_disabled.corner_radius_top_right = 6
	style_disabled.corner_radius_bottom_left = 6
	style_disabled.corner_radius_bottom_right = 6

	for i in range(1, 3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(100, 60)
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5, 1))
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		btn.text = str(i)
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.35)
		btn.pressed.connect(func(level_number := i) -> void:
			GameState.start_abyss(level_number)
		)
		grid.add_child(btn)
		_level_buttons.append(btn)


func _refresh_locks() -> void:
	for i in range(1, 3):
		var btn := _level_buttons[i - 1]
		var unlocked := Progress.is_abyss_unlocked(i)
		btn.disabled = not unlocked
		btn.modulate = Color(1, 1, 1, 1.0) if unlocked else Color(1, 1, 1, 0.35)
