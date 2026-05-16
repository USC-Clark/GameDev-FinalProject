extends Control

@onready var tutorial_button: Button = $Center/Panel/VBox/TutorialButton
@onready var traverse_button: Button = $Center/Panel/VBox/TraverseButton
@onready var abyss_button: Button = $Center/Panel/VBox/AbyssSection/AbyssButton
@onready var hint_label: Label = $Center/Panel/VBox/AbyssSection/HintLabel
@onready var back_button: Button = $Center/Panel/VBox/BackButton

@onready var key_boxes: Array = [
	$Center/Panel/VBox/AbyssSection/KeyRow/KeyBox1,
	$Center/Panel/VBox/AbyssSection/KeyRow/KeyBox2,
	$Center/Panel/VBox/AbyssSection/KeyRow/KeyBox3,
	$Center/Panel/VBox/AbyssSection/KeyRow/KeyBox4,
]

var _style_empty: StyleBoxFlat
var _style_filled: StyleBoxFlat


func _ready() -> void:
	Progress._load()

	_style_empty = StyleBoxFlat.new()
	_style_empty.bg_color = Color(0.1, 0.08, 0.14, 0.85)
	_style_empty.set_border_width_all(2)
	_style_empty.border_color = Color(0.35, 0.3, 0.45, 1)
	_style_empty.set_corner_radius_all(4)

	_style_filled = StyleBoxFlat.new()
	_style_filled.bg_color = Color(0.55, 0.42, 0.08, 0.9)
	_style_filled.set_border_width_all(2)
	_style_filled.border_color = Color(1, 0.85, 0.2, 1)
	_style_filled.set_corner_radius_all(4)

	tutorial_button.pressed.connect(func() -> void:
		GameState.go_to_tutorial_select()
	)
	traverse_button.pressed.connect(func() -> void:
		GameState.go_to_traverse_select()
	)
	abyss_button.pressed.connect(_on_abyss_pressed)
	back_button.pressed.connect(func() -> void:
		GameState.go_to_main_menu()
	)

	_refresh_abyss()


func _on_abyss_pressed() -> void:
	# Show the one-time glitch intro, then go to abyss select.
	if not Progress.abyss_intro_seen:
		Progress.abyss_intro_seen = true
		Progress._save()
		var intro := preload("res://scenes/abyss_intro.tscn").instantiate()
		add_child(intro)
		intro.done.connect(func() -> void:
			MusicManager.play_track("res://Music/Abyss.mp3")
			GameState.go_to_abyss_select()
		)
	else:
		GameState.go_to_abyss_select()


func _refresh_abyss() -> void:
	var keys := Progress.dungeon_keys_collected
	var unlocked := Progress.is_abyss_mode_unlocked()

	for i in range(4):
		var box: PanelContainer = key_boxes[i]
		var filled := i < keys
		box.add_theme_stylebox_override("panel", _style_filled if filled else _style_empty)
		var lbl := box.get_node_or_null("Label") as Label
		if lbl:
			lbl.modulate = Color(1, 1, 1, 1) if filled else Color(1, 1, 1, 0.25)

	abyss_button.disabled = not unlocked
	if unlocked:
		abyss_button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		hint_label.text = "Abyss unlocked — enter if you dare."
		hint_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2, 1))
	else:
		abyss_button.add_theme_color_override("font_color", Color(0.4, 0.35, 0.5, 1))
		hint_label.text = "Collect %d more dungeon key%s to unlock" % [
			4 - keys, "s" if (4 - keys) != 1 else ""
		]
		hint_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.6, 1))
