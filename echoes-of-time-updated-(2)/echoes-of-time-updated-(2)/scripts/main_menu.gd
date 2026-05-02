extends Control

@onready var play_button: Button = $Center/Panel/VBox/PlayButton
@onready var settings_button: Button = $Center/Panel/VBox/SettingsButton
@onready var quit_button: Button = $Center/Panel/VBox/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	GameState.go_to_mode_select()


func _on_settings_pressed() -> void:
	GameState.go_to_settings()


func _on_quit_pressed() -> void:
	get_tree().quit()
