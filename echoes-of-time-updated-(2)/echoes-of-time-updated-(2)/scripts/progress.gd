extends Node

const SAVE_PATH := "user://progress.cfg"
const SECTION := "progress"
const KEY_TUTORIAL_UNLOCKED := "tutorial_unlocked"

var admin_unlock: bool = false
var tutorial_unlocked: int = 1 # 1..10 (how many are currently accessible)


func _ready() -> void:
	_load()


func _load() -> void:
	# Admin unlock is a temporary test toggle; never persist it.
	admin_unlock = false
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		tutorial_unlocked = 1
		return
	tutorial_unlocked = int(cfg.get_value(SECTION, KEY_TUTORIAL_UNLOCKED, 1))
	tutorial_unlocked = clampi(tutorial_unlocked, 1, 10)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_TUTORIAL_UNLOCKED, tutorial_unlocked)
	cfg.save(SAVE_PATH)


func is_tutorial_unlocked(level_number: int) -> bool:
	# level_number: 1..10
	if admin_unlock:
		return true
	return level_number <= tutorial_unlocked


func complete_tutorial_level(level_number: int) -> void:
	# level_number: 1..10
	# Admin unlock is for testing; it should not advance real progression.
	if admin_unlock:
		return
	if level_number >= tutorial_unlocked and tutorial_unlocked < 10:
		tutorial_unlocked = clampi(level_number + 1, 1, 10)
		_save()


func toggle_admin_unlock() -> void:
	admin_unlock = not admin_unlock


func reset_tutorial_progress() -> void:
	tutorial_unlocked = 1
	admin_unlock = false
	_save()
