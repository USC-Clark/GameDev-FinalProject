extends Node

const TUTORIAL_MAP_DIR := "res://scenes/maps/tutorial"
var selected_tutorial_level: int = 1 # 1..10
var selected_tutorial_scene_path: String = ""
var selected_traverse_level: int = 1 # 1..10


func start_tutorial(level_number: int) -> void:
	var requested := clampi(level_number, 1, 10)
	# Enforce progression lock unless admin unlock is enabled.
	if not Progress.is_tutorial_unlocked(requested):
		requested = clampi(Progress.tutorial_unlocked, 1, 10)
	selected_tutorial_level = requested
	selected_tutorial_scene_path = "%s/tutorial_%02d.tscn" % [TUTORIAL_MAP_DIR, requested]
	if ResourceLoader.exists(selected_tutorial_scene_path):
		get_tree().change_scene_to_file("res://scenes/tutorial_game.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/tutorial_game.tscn")


func start_traverse(level_number: int) -> void:
	selected_traverse_level = clampi(level_number, 1, 10)
	get_tree().change_scene_to_file("res://scenes/traverse_game.tscn")


func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func go_to_mode_select() -> void:
	get_tree().change_scene_to_file("res://scenes/mode_select.tscn")


func go_to_tutorial_select() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial_select.tscn")


func go_to_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")


func go_to_traverse_select() -> void:
	get_tree().change_scene_to_file("res://scenes/traverse_select.tscn")
