extends AnimatedSprite2D

const DUNGEON_KEY_SCENE := preload("res://scenes/dungeon_key.tscn")

signal key_spawned(key_node: Node2D)

## Unique ID for this chest — set in the Inspector for each placed chest.
@export var chest_id: String = "chest_default"
## Message shown when the key is collected.
@export var pickup_message: String = "Someone is watching you from beneath..."

@onready var _detect: Area2D = $Area2D

var _opened: bool = false
var _key_permanently_taken: bool = false


func _ready() -> void:
	# If already collected in a previous session, disappear immediately.
	if Progress.has_collected_key(chest_id):
		queue_free()
		return

	_detect.collision_layer = 0
	_detect.collision_mask = 1
	_detect.monitoring = true
	_detect.body_entered.connect(_on_body_entered)
	play("Close_chest")


func _on_body_entered(body: Node) -> void:
	if _opened or not body.is_in_group("player"):
		return
	_open()


func _open() -> void:
	_opened = true
	play("Open_chest")
	animation_finished.connect(_on_open_animation_finished, CONNECT_ONE_SHOT)


func _on_open_animation_finished() -> void:
	var key := DUNGEON_KEY_SCENE.instantiate() as Node2D
	key.position = global_position
	key.scale = Vector2(1.0, 1.0)
	get_parent().add_child(key)

	if key is AnimatedSprite2D:
		(key as AnimatedSprite2D).play("default")

	var tween := get_tree().create_tween()
	tween.tween_property(key, "position", global_position + Vector2(0, -32), 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	var pickup: Area2D = key.get_node_or_null("Pickup")
	if pickup:
		pickup.collision_mask = 1
		pickup.monitoring = true
		pickup.body_entered.connect(_on_key_picked_up.bind(key))

	emit_signal("key_spawned", key)


func _on_key_picked_up(body: Node, key: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if is_instance_valid(key):
		key.queue_free()
	_key_permanently_taken = true
	Progress.collect_dungeon_key(chest_id)
	_show_message(pickup_message)
	# Chest disappears after key is collected.
	queue_free()


func reset() -> void:
	# If the key was collected this session or previously — remove the chest.
	if _key_permanently_taken or Progress.has_collected_key(chest_id):
		queue_free()
		return
	# Key not yet collected — reset to closed so player can try again.
	_opened = false
	# Free any floating key that wasn't picked up.
	var parent := get_parent()
	if is_instance_valid(parent):
		for child in parent.get_children():
			if child.name.begins_with("DungeonKey"):
				child.queue_free()
	play("Close_chest")


func _show_message(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.z_index = 10
	label.position = global_position + Vector2(-120, -80)
	get_parent().add_child(label)

	label.modulate.a = 0.0
	var tween := get_tree().create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(2.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
