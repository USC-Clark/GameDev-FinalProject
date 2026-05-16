extends Control

@onready var back_button: Button = $Center/Panel/VBox/BackButton


func _ready() -> void:
	back_button.pressed.connect(func() -> void:
		GameState.go_to_main_menu()
	)
