extends Node

const MUSIC_PATH := "res://Music/My-game-music.mp3"
const SAVE_PATH := "user://settings.cfg"
const SECTION := "audio"
const KEY_MUSIC_VOLUME := "music_volume_db"
const DEFAULT_VOLUME_DB := -1.94  # ~80 out of 100

@onready var _player: AudioStreamPlayer = $Player


func _ready() -> void:
	_player.stream = load(MUSIC_PATH)
	_player.bus = "Master"
	_player.finished.connect(_on_finished)
	_load_volume()
	# Do NOT autoplay — main menu calls play() explicitly.


func _load_volume() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		_player.volume_db = float(cfg.get_value(SECTION, KEY_MUSIC_VOLUME, DEFAULT_VOLUME_DB))
	else:
		_player.volume_db = DEFAULT_VOLUME_DB


func get_volume_db() -> float:
	return _player.volume_db


func set_volume_db(value_db: float) -> void:
	_player.volume_db = value_db
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # load existing keys so we don't wipe other settings
	cfg.set_value(SECTION, KEY_MUSIC_VOLUME, value_db)
	cfg.save(SAVE_PATH)


func play() -> void:
	# Don't restart if the same track is already playing.
	if _player.playing and _player.stream == load(MUSIC_PATH):
		return
	_player.stream = load(MUSIC_PATH)
	_player.stop()
	_player.play()


func play_track(path: String) -> void:
	var stream := load(path)
	if stream == null:
		return
	# Don't restart if this track is already playing.
	if _player.playing and _player.stream == stream:
		return
	_player.stream = stream
	_player.stop()
	_player.play()


func stop() -> void:
	_player.stop()


func _on_finished() -> void:
	# Loop.
	_player.play()
