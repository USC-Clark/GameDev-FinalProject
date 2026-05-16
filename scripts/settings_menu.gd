extends Control

@onready var back_button: Button = $Center/Panel/VBox/BackButton
@onready var music_slider: HSlider = $Center/Panel/VBox/MusicRow/MusicSlider
@onready var music_value_label: Label = $Center/Panel/VBox/MusicRow/MusicValueLabel

# Converts a 0-100 slider value to decibels.
# 0   -> -80 dB (effectively silent)
# 100 ->   0 dB (full volume)
func _to_db(pct: float) -> float:
	if pct <= 0.0:
		return -80.0
	return linear_to_db(pct / 100.0)

# Converts decibels back to a 0-100 value for the slider.
func _to_pct(db: float) -> float:
	if db <= -80.0:
		return 0.0
	return clampf(db_to_linear(db) * 100.0, 0.0, 100.0)


func _ready() -> void:
	var pct := _to_pct(MusicManager.get_volume_db())
	music_slider.set_value_no_signal(pct)
	_update_label(pct)

	music_slider.value_changed.connect(_on_music_slider_changed)

	back_button.pressed.connect(func() -> void:
		GameState.go_to_main_menu()
	)


func _on_music_slider_changed(value: float) -> void:
	MusicManager.set_volume_db(_to_db(value))
	_update_label(value)


func _update_label(pct: float) -> void:
	music_value_label.text = str(int(pct))
