extends Control

@onready var grid: GridContainer = $Center/Panel/VBox/Grid
@onready var back_button: Button = $Center/Panel/VBox/BottomRow/BackButton


func _ready() -> void:
	back_button.pressed.connect(func() -> void:
		GameState.go_to_mode_select()
	)
	_build_cards()


func _build_cards() -> void:
	for child in grid.get_children():
		child.queue_free()

	for i in range(1, 11):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(180, 92)
		btn.add_theme_font_size_override("font_size", 26)
		btn.text = str(i)
		btn.pressed.connect(func(level_number := i) -> void:
			GameState.start_traverse(level_number)
		)
		grid.add_child(btn)
