extends AnimatableBody2D

@export var button_id: String = ""
@export var move_distance: float = 300.0
@export var auto: bool = false
@export var speed: float = 120.0
@export var start_on_action: bool = false
@export var platform_size: Vector2 = Vector2(120, 20)

var dir: int = 1
var started: bool = false
var initial: Vector2
var start: Vector2
var end: Vector2

func _ready() -> void:
	add_to_group("button_driven")
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	initial = position
	start = position
	end = position + Vector2(0, -move_distance)
	reset_physics_interpolation()
	force_update_transform()
	collision_layer = 4
	collision_mask = 0

	var has_collision := false
	for child in get_children():
		if child is CollisionShape2D:
			has_collision = true
			break
	if not has_collision:
		var shape_node := CollisionShape2D.new()
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = platform_size
		shape_node.shape = rect_shape
		shape_node.position = platform_size * 0.5
		add_child(shape_node)

	var has_visual := false
	for child in get_children():
		if child is ColorRect:
			has_visual = true
			break
	if not has_visual:
		var vis := ColorRect.new()
		vis.size = platform_size
		vis.color = Color(0.3, 0.65, 0.9, 1.0)
		add_child(vis)

	if auto and not start_on_action:
		started = true

func activate() -> void:
	started = true

func deactivate() -> void:
	started = false
	dir = 1

func _physics_process(delta: float) -> void:
	if not started:
		return

	var target := end if dir == 1 else start
	var move_vec := (target - position).normalized() * speed * delta

	if position.distance_to(target) <= move_vec.length():
		move_and_collide(target - position)
		dir *= -1
		if not auto:
			started = false
	else:
		move_and_collide(move_vec)

func reset_to_initial() -> void:
	dir = 1
	started = false
	position = initial
	reset_physics_interpolation()
	force_update_transform()
