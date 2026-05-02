# portal.gd
# Dungeon door exit with animated aura effect
# Can be used as a visual effect or as a functional teleporter.

extends Node2D

signal portal_entered(body: Node2D)
signal portal_exited(body: Node2D)
signal level_exit_triggered(body: Node2D)

# ── Tweakable Parameters ─────────────────────────────────────
@export var door_width: float = 64.0
@export var door_height: float = 96.0
@export var aura_intensity: float = 1.0
@export var aura_speed: float = 2.0
@export var glow_pulses: int = 3
@export var door_color: Color = Color(0.19, 0.145, 0.106, 1.0)      # Dark wood
@export var frame_color: Color = Color(0.247, 0.196, 0.151, 1.0)    # Stone frame
@export var aura_color: Color = Color(0.204, 0.204, 0.204, 1.0)     # Golden aura
@export var glow_color: Color = Color(0.027, 0.0, 0.425, 0.3)       # Golden glow

# ── Portal Behavior Settings ─────────────────────────────────
@export_group("Portal Behavior")
@export_enum("Exit", "Teleporter", "Decoration") var portal_type: String = "Exit"
@export var destination_portal: NodePath = NodePath()
@export var teleport_cooldown: float = 0.5

# ── Internal State ───────────────────────────────────────────
var _time: float = 0.0
var _area: Area2D = null
var _teleport_timer: float = 0.0
var _teleported_bodies: Array[Node2D] = []
var _aura_particles: Array = []

class AuraParticle:
	var angle: float
	var distance: float
	var speed: float
	var size: float
	var alpha: float
	var offset: float

func _ready() -> void:
	_spawn_aura_particles()
	_setup_collision_area()

func _spawn_aura_particles() -> void:
	_aura_particles.clear()
	var particle_count: int = 40
	for i in particle_count:
		var p := AuraParticle.new()
		p.angle = randf() * TAU
		p.distance = randf_range(0.3, 1.2)
		p.speed = randf_range(0.5, 1.5)
		p.size = randf_range(2.0, 4.0)
		p.alpha = randf_range(0.3, 0.8)
		p.offset = randf() * TAU
		_aura_particles.append(p)


func _setup_collision_area() -> void:
	# Create an Area2D for detecting when entities enter the door
	_area = Area2D.new()
	_area.collision_layer = 0
	_area.collision_mask = 1 | 2  # Detect player (layer 1) and echoes (layer 2)
	_area.monitoring = true
	_area.monitorable = false
	add_child(_area)
	
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(door_width, door_height)
	shape.shape = rect
	_area.add_child(shape)
	
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	_time += delta

	# Update teleport cooldown
	if _teleport_timer > 0.0:
		_teleport_timer -= delta
		if _teleport_timer <= 0.0:
			_teleported_bodies.clear()

	# Animate aura particles
	for p in _aura_particles:
		p.angle += p.speed * delta * 0.5
		p.distance += sin(_time * aura_speed + p.offset) * 0.01

	queue_redraw()

func _draw() -> void:
	var pulse: float = (sin(_time * aura_speed) * 0.5 + 0.5)  # 0 → 1
	
	# Draw from back to front
	_draw_outer_glow(pulse)
	_draw_aura_particles(pulse)
	_draw_door_frame()
	_draw_door_body()
	_draw_door_details()
	_draw_inner_glow(pulse)

# ── Draw Layers ──────────────────────────────────────────────

func _draw_outer_glow(pulse: float) -> void:
	# Soft glow rings around the door
	var half_w: float = door_width * 0.5
	var half_h: float = door_height * 0.5
	
	for i in glow_pulses:
		var t: float = float(i) / float(glow_pulses)
		var expand: float = 20.0 + t * 30.0 + pulse * 10.0
		var alpha: float = (1.0 - t) * 0.2 * (0.6 + pulse * 0.4) * aura_intensity
		
		var glow: Color = glow_color
		glow.a = alpha
		
		var rect: Rect2 = Rect2(
			-half_w - expand,
			-half_h - expand,
			door_width + expand * 2,
			door_height + expand * 2
		)
		draw_rect(rect, glow, false, 3.0)

func _draw_aura_particles(pulse: float) -> void:
	# Floating magical particles around the door
	var half_w: float = door_width * 0.5
	var half_h: float = door_height * 0.5
	
	for p in _aura_particles:
		var base_dist: float = maxf(half_w, half_h) * 0.8
		var dist: float = base_dist * p.distance
		var pos: Vector2 = Vector2(cos(p.angle), sin(p.angle)) * dist
		
		var particle_color: Color = aura_color
		particle_color.a = p.alpha * (0.7 + pulse * 0.3) * aura_intensity
		
		# Glow behind particle
		var glow: Color = particle_color
		glow.a *= 0.4
		draw_circle(pos, p.size * 2.0, glow)
		
		# Particle itself
		draw_circle(pos, p.size, particle_color)

func _draw_door_frame() -> void:
	# Stone door frame
	var half_w: float = door_width * 0.5
	var half_h: float = door_height * 0.5
	var frame_thickness: float = 8.0
	
	# Outer frame
	var outer_rect: Rect2 = Rect2(
		-half_w - frame_thickness,
		-half_h - frame_thickness,
		door_width + frame_thickness * 2,
		door_height + frame_thickness * 2
	)
	draw_rect(outer_rect, frame_color, true)
	
	# Frame highlights (top and left)
	var highlight: Color = frame_color.lightened(0.2)
	draw_line(
		Vector2(-half_w - frame_thickness, -half_h - frame_thickness),
		Vector2(half_w + frame_thickness, -half_h - frame_thickness),
		highlight, 2.0
	)
	draw_line(
		Vector2(-half_w - frame_thickness, -half_h - frame_thickness),
		Vector2(-half_w - frame_thickness, half_h + frame_thickness),
		highlight, 2.0
	)
	
	# Frame shadows (bottom and right)
	var shadow: Color = frame_color.darkened(0.3)
	draw_line(
		Vector2(-half_w - frame_thickness, half_h + frame_thickness),
		Vector2(half_w + frame_thickness, half_h + frame_thickness),
		shadow, 2.0
	)
	draw_line(
		Vector2(half_w + frame_thickness, -half_h - frame_thickness),
		Vector2(half_w + frame_thickness, half_h + frame_thickness),
		shadow, 2.0
	)

func _draw_door_body() -> void:
	# Wooden door body
	var half_w: float = door_width * 0.5
	var half_h: float = door_height * 0.5
	
	var door_rect: Rect2 = Rect2(-half_w, -half_h, door_width, door_height)
	draw_rect(door_rect, door_color, true)
	
	# Wood grain effect (vertical lines)
	var grain_color: Color = door_color.darkened(0.15)
	var grain_count: int = 5
	for i in grain_count:
		var x: float = lerp(-half_w + 8, half_w - 8, float(i) / float(grain_count - 1))
		draw_line(
			Vector2(x, -half_h + 4),
			Vector2(x, half_h - 4),
			grain_color, 1.0
		)

func _draw_door_details() -> void:
	# Door details (planks and metal bands)
	var half_w: float = door_width * 0.5
	var half_h: float = door_height * 0.5
	
	# Horizontal planks
	var plank_color: Color = door_color.darkened(0.2)
	var plank_positions: Array[float] = [-half_h * 0.6, 0.0, half_h * 0.6]
	for y in plank_positions:
		draw_line(
			Vector2(-half_w + 4, y),
			Vector2(half_w - 4, y),
			plank_color, 3.0
		)
	
	# Metal bands
	var metal_color: Color = Color(0.4, 0.4, 0.45, 1.0)
	var band_positions: Array[float] = [-half_h * 0.7, half_h * 0.7]
	for y in band_positions:
		draw_line(
			Vector2(-half_w, y),
			Vector2(half_w, y),
			metal_color, 4.0
		)
		# Metal highlights
		draw_line(
			Vector2(-half_w, y - 1),
			Vector2(half_w, y - 1),
			metal_color.lightened(0.3), 1.0
		)
	
	# Door handle/ring
	var handle_pos: Vector2 = Vector2(half_w * 0.6, 0)
	draw_circle(handle_pos, 6.0, metal_color, true)
	draw_circle(handle_pos, 4.0, metal_color.darkened(0.3), true)
	draw_circle(handle_pos, 6.0, metal_color.lightened(0.2), false, 1.5)

func _draw_inner_glow(pulse: float) -> void:
	# Magical glow seeping through door cracks
	var half_w: float = door_width * 0.5
	var half_h: float = door_height * 0.5
	
	var inner_glow: Color = aura_color
	inner_glow.a = (0.3 + pulse * 0.2) * aura_intensity
	
	# Glow around door edges (inside)
	var edge_offset: float = 2.0
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(-half_w + edge_offset, -half_h + edge_offset),
		Vector2(half_w - edge_offset, -half_h + edge_offset),
		Vector2(half_w - edge_offset, half_h - edge_offset),
		Vector2(-half_w + edge_offset, half_h - edge_offset),
		Vector2(-half_w + edge_offset, -half_h + edge_offset)
	])
	
	draw_polyline(points, inner_glow, 3.0 + pulse * 2.0, true)


# ── Portal Interaction ───────────────────────────────────────

func _on_body_entered(body: Node2D) -> void:
	emit_signal("portal_entered", body)
	
	# Handle different portal types
	match portal_type:
		"Exit":
			_handle_exit(body)
		"Teleporter":
			_handle_teleport(body)
		"Decoration":
			pass  # Just emit signal, no action


func _on_body_exited(body: Node2D) -> void:
	emit_signal("portal_exited", body)


func _handle_exit(body: Node2D) -> void:
	# Only trigger exit for the player, not echoes
	if body.is_in_group("player"):
		emit_signal("level_exit_triggered", body)
		print("Portal: Player reached exit!")


func _handle_teleport(body: Node2D) -> void:
	# Prevent rapid back-and-forth teleportation
	if _teleported_bodies.has(body):
		return
	
	if destination_portal.is_empty():
		push_warning("Portal: Teleporter type requires destination_portal to be set")
		return
	
	var dest_node := get_node_or_null(destination_portal)
	if dest_node == null or not dest_node is Node2D:
		push_warning("Portal destination not found or invalid: %s" % destination_portal)
		return
	
	# Teleport the body
	body.global_position = dest_node.global_position
	
	# Add to cooldown list
	_teleported_bodies.append(body)
	_teleport_timer = teleport_cooldown
	
	# If destination is also a portal, mark it to prevent immediate return teleport
	if dest_node.has_method("_mark_teleported"):
		dest_node._mark_teleported(body)


func _mark_teleported(body: Node2D) -> void:
	# Called by another portal to prevent immediate return teleportation
	if not _teleported_bodies.has(body):
		_teleported_bodies.append(body)
	_teleport_timer = teleport_cooldown
