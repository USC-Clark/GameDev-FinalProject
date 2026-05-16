extends Control

@onready var play_button: Button = $Center/Panel/VBox/PlayButton
@onready var settings_button: Button = $Center/Panel/VBox/SettingsButton
@onready var quit_button: Button = $Center/Panel/VBox/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# Start music when the main menu loads.
	MusicManager.play()


func _on_play_pressed() -> void:
	if not Progress.orb_cutscene_seen:
		Progress.orb_cutscene_seen = true
		Progress._save()
		# Expand to 900 tall for the cutscene.
		get_tree().root.content_scale_size = Vector2i(1450, 900)
		DisplayServer.window_set_size(Vector2i(1450, 900))
		var cutscene := preload("res://scenes/orb_cutscene.tscn").instantiate()
		add_child(cutscene)
		cutscene.done.connect(func() -> void:
			GameState.start_tutorial(1)
		)
	else:
		GameState.go_to_mode_select()


func _on_settings_pressed() -> void:
	GameState.go_to_settings()


func _on_quit_pressed() -> void:
	get_tree().quit()
