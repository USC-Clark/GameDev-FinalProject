extends Control

# The first scene to show after the loading screen.
const NEXT_SCENE := "res://scenes/main_menu.tscn"

# Scenes to preload in the background while the loading screen is visible.
# This warms the resource cache so later transitions are instant.
const PRELOAD_SCENES := [
	"res://scenes/main_menu.tscn",
	"res://scenes/mode_select.tscn",
	"res://scenes/tutorial_select.tscn",
	"res://scenes/traverse_select.tscn",
	"res://scenes/tutorial_game.tscn",
	"res://scenes/traverse_game.tscn",
	"res://scenes/abyss_game.tscn",
	"res://scenes/settings_menu.tscn",
]

const MIN_DISPLAY_TIME := 1.5  # seconds — minimum time to show the screen

var _elapsed: float = 0.0
var _load_queue: Array[String] = []
var _current_load: String = ""
var _done: bool = false


func _ready() -> void:
	# Loading screen and all menus use 1450x700.
	get_tree().root.content_scale_size = Vector2i(1450, 700)
	DisplayServer.window_set_size(Vector2i(1450, 700))

	$LoadAnimation/ProgressBar.value = 0.0
	$LoadAnimation/ProgressBar.max_value = 100.0
	$LoadAnimation/Subtitle.text = "Loading..."

	# Kick off background loading for all scenes.
	for path in PRELOAD_SCENES:
		if ResourceLoader.exists(path):
			ResourceLoader.load_threaded_request(path)
			_load_queue.append(path)

	_current_load = ""


func _process(delta: float) -> void:
	_elapsed += delta

	# Poll background loading progress.
	var total := float(PRELOAD_SCENES.size())
	var completed := 0.0
	for path in PRELOAD_SCENES:
		var progress_arr: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress_arr)
		match status:
			ResourceLoader.THREAD_LOAD_LOADED:
				completed += 1.0
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if progress_arr.size() > 0:
					completed += float(progress_arr[0])
			_:
				completed += 1.0  # failed or not started — don't block

	var load_progress := completed / maxf(total, 1.0)
	# Blend load progress with elapsed time so bar always moves.
	var time_progress := clampf(_elapsed / MIN_DISPLAY_TIME, 0.0, 1.0)
	var display_progress := maxf(load_progress, time_progress * 0.5)
	$LoadAnimation/ProgressBar.value = clampf(display_progress, 0.0, 1.0) * 100.0

	# Proceed once both the minimum time has passed and loading is done.
	if not _done and _elapsed >= MIN_DISPLAY_TIME and load_progress >= 1.0:
		_done = true
		call_deferred("_go_to_menu")


func _go_to_menu() -> void:
	GameState.go_to_main_menu()
