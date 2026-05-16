extends Node

const TUTORIAL_MAP_DIR := "res://scenes/maps/tutorial"
var selected_tutorial_level: int = 1
var selected_tutorial_scene_path: String = ""
var selected_traverse_level: int = 1
var selected_abyss_level: int = 1

# Fade overlay — created once and reused for all transitions.
var _fade: ColorRect = null
var _transitioning: bool = false

const LEVEL_SCENES := [
	"res://scenes/tutorial_game.tscn",
	"res://scenes/traverse_game.tscn",
	"res://scenes/abyss_game.tscn",
]


func _ready() -> void:
	_build_fade_overlay()


func _build_fade_overlay() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.z_index = 100
	var cl := CanvasLayer.new()
	cl.layer = 200
	cl.add_child(_fade)
	add_child(cl)


func _resize_for(path: String) -> void:
	var is_level := path in LEVEL_SCENES
	var target := Vector2i(1450, 900) if is_level else Vector2i(1450, 700)
	get_tree().root.content_scale_size = target
	DisplayServer.window_set_size(target)


# All scene changes go through here — fades out, loads, fades in.
func _go_to(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP

	if ResourceLoader.exists(path):
		ResourceLoader.load_threaded_request(path)

	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.18)
	await t.finished

	# Resize while screen is black so there's no visible pop.
	_resize_for(path)

	if ResourceLoader.exists(path):
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame

	get_tree().change_scene_to_file(path)
	await get_tree().process_frame

	var t2 := create_tween()
	t2.tween_property(_fade, "color:a", 0.0, 0.18)
	await t2.finished

	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false


func start_tutorial(level_number: int) -> void:
	var requested := clampi(level_number, 1, 10)
	if not Progress.is_tutorial_unlocked(requested):
		requested = clampi(Progress.tutorial_unlocked, 1, 10)
	selected_tutorial_level = requested
	selected_tutorial_scene_path = "%s/tutorial_%02d.tscn" % [TUTORIAL_MAP_DIR, requested]
	_go_to("res://scenes/tutorial_game.tscn")


func start_traverse(level_number: int) -> void:
	selected_traverse_level = clampi(level_number, 1, 10)
	_go_to("res://scenes/traverse_game.tscn")


func go_to_main_menu() -> void:
	_go_to("res://scenes/main_menu.tscn")


func go_to_mode_select() -> void:
	_go_to("res://scenes/mode_select.tscn")


func go_to_tutorial_select() -> void:
	_go_to("res://scenes/tutorial_select.tscn")


func go_to_settings() -> void:
	_go_to("res://scenes/settings_menu.tscn")


func go_to_traverse_select() -> void:
	_go_to("res://scenes/traverse_select.tscn")


func start_abyss(level_number: int) -> void:
	selected_abyss_level = clampi(level_number, 1, 2)
	_go_to("res://scenes/abyss_game.tscn")


func go_to_abyss_select() -> void:
	_go_to("res://scenes/abyss_select.tscn")
