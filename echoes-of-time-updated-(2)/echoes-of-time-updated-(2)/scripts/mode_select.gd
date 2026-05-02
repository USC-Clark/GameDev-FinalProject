extends Control

@onready var tutorial_button: Button = $Center/Panel/VBox/TutorialButton
@onready var traverse_button: Button = $Center/Panel/VBox/TraverseButton
@onready var back_button: Button = $Center/Panel/VBox/BackButton


func _ready() -> void:
	tutorial_button.pressed.connect(func() -> void:
		GameState.go_to_tutorial_select()
	)
	traverse_button.pressed.connect(func() -> void:
		GameState.go_to_traverse_select()
	)
	back_button.pressed.connect(func() -> void:
		GameState.go_to_main_menu()
	)
