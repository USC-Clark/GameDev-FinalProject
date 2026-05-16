extends Node

const SAVE_PATH := "user://progress.cfg"
const SECTION := "progress"
const KEY_TUTORIAL_UNLOCKED := "tutorial_unlocked"
const KEY_TRAVERSE_UNLOCKED := "traverse_unlocked"
const KEY_ABYSS_UNLOCKED := "abyss_unlocked"
const KEY_DUNGEON_KEYS := "dungeon_keys_collected"
const KEY_DUNGEON_KEY_IDS := "dungeon_key_ids"

var admin_unlock: bool = false
var tutorial_unlocked: int = 1  # 1..10
var traverse_unlocked: int = 0  # 0 = none unlocked yet; 1..10 = highest accessible
var abyss_unlocked: int = 0     # 0 = none unlocked yet; 1..2 = highest accessible
var dungeon_keys_collected: int = 0       # 0..4 — unlocks Abyss at 4
var _collected_key_ids: Array[String] = []  # which chest IDs have been permanently collected
var abyss_intro_seen: bool = false          # true after the first-time glitch intro plays
var orb_cutscene_seen: bool = false         # true after the orb cutscene plays once


func _ready() -> void:
	_load()


func _reset_to_defaults() -> void:
	admin_unlock = false
	tutorial_unlocked = 1
	traverse_unlocked = 0
	abyss_unlocked = 0
	dungeon_keys_collected = 0
	_collected_key_ids.clear()
	abyss_intro_seen = false
	orb_cutscene_seen = false


func _load() -> void:
	admin_unlock = false
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_PATH)
	if err != OK:
		tutorial_unlocked = 1
		traverse_unlocked = 0
		return
	tutorial_unlocked = int(cfg.get_value(SECTION, KEY_TUTORIAL_UNLOCKED, 1))
	tutorial_unlocked = clampi(tutorial_unlocked, 1, 10)
	traverse_unlocked = int(cfg.get_value(SECTION, KEY_TRAVERSE_UNLOCKED, 0))
	traverse_unlocked = clampi(traverse_unlocked, 0, 10)
	abyss_unlocked = int(cfg.get_value(SECTION, KEY_ABYSS_UNLOCKED, 0))
	abyss_unlocked = clampi(abyss_unlocked, 0, 2)
	dungeon_keys_collected = int(cfg.get_value(SECTION, KEY_DUNGEON_KEYS, 0))
	dungeon_keys_collected = clampi(dungeon_keys_collected, 0, 4)
	var ids_str := String(cfg.get_value(SECTION, KEY_DUNGEON_KEY_IDS, ""))
	_collected_key_ids.clear()
	if ids_str != "":
		for id in ids_str.split(",", false):
			_collected_key_ids.append(id.strip_edges())
	abyss_intro_seen = bool(cfg.get_value(SECTION, "abyss_intro_seen", false))
	orb_cutscene_seen = bool(cfg.get_value(SECTION, "orb_cutscene_seen", false))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_TUTORIAL_UNLOCKED, tutorial_unlocked)
	cfg.set_value(SECTION, KEY_TRAVERSE_UNLOCKED, traverse_unlocked)
	cfg.set_value(SECTION, KEY_ABYSS_UNLOCKED, abyss_unlocked)
	cfg.set_value(SECTION, KEY_DUNGEON_KEYS, dungeon_keys_collected)
	cfg.set_value(SECTION, KEY_DUNGEON_KEY_IDS, ",".join(_collected_key_ids))
	cfg.set_value(SECTION, "abyss_intro_seen", abyss_intro_seen)
	cfg.set_value(SECTION, "orb_cutscene_seen", orb_cutscene_seen)
	cfg.save(SAVE_PATH)


func is_tutorial_unlocked(level_number: int) -> bool:
	if admin_unlock:
		return true
	return level_number <= tutorial_unlocked


func is_traverse_unlocked(level_number: int) -> bool:
	if admin_unlock:
		return true
	return level_number <= traverse_unlocked


func complete_tutorial_level(level_number: int) -> void:
	if admin_unlock:
		return
	if level_number >= tutorial_unlocked and tutorial_unlocked < 10:
		tutorial_unlocked = clampi(level_number + 1, 1, 10)
		_save()


func complete_traverse_level(level_number: int) -> void:
	if admin_unlock:
		return
	if level_number >= traverse_unlocked and traverse_unlocked < 10:
		traverse_unlocked = clampi(level_number + 1, 1, 10)
		_save()


func unlock_traverse() -> void:
	# Call this when the player first accesses traverse mode.
	if traverse_unlocked == 0:
		traverse_unlocked = 1
		_save()


func unlock_abyss() -> void:
	# Call this when the player first accesses abyss mode.
	if abyss_unlocked == 0:
		abyss_unlocked = 1
		_save()


func is_abyss_mode_unlocked() -> bool:
	if admin_unlock:
		return true
	return dungeon_keys_collected >= 4


func collect_dungeon_key(chest_id: String) -> void:
	# Only count each unique chest once, ever.
	if chest_id in _collected_key_ids:
		return
	if dungeon_keys_collected >= 4:
		return
	_collected_key_ids.append(chest_id)
	dungeon_keys_collected += 1
	_save()


func has_collected_key(chest_id: String) -> bool:
	return chest_id in _collected_key_ids


func is_abyss_unlocked(level_number: int) -> bool:
	if admin_unlock:
		return true
	return level_number <= abyss_unlocked


func complete_abyss_level(level_number: int) -> void:
	if admin_unlock:
		return
	if level_number >= abyss_unlocked and abyss_unlocked < 2:
		abyss_unlocked = clampi(level_number + 1, 1, 2)
		_save()


func toggle_admin_unlock() -> void:
	admin_unlock = not admin_unlock


func reset_tutorial_progress() -> void:
	tutorial_unlocked = 1
	admin_unlock = false
	_save()


func reset_traverse_progress() -> void:
	traverse_unlocked = 0
	admin_unlock = false
	_save()


func reset_dungeon_keys() -> void:
	dungeon_keys_collected = 0
	_collected_key_ids.clear()
	_save()
