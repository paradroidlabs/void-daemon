class_name XpOrb
extends Area2D

## Scene-free XP pickup. Attraction uses an explicit target Node2D or position,
## making the actor agnostic to keyboard, mouse, controller, and touch input.

signal attraction_started(orb: Area2D, target: Node)
signal collected(orb: Area2D, value: int, collector: Node)

var value: int = 1
var velocity: Vector2 = Vector2.ZERO
var attraction_radius: float = 150.0
var pickup_radius: float = 13.0
var acceleration: float = 900.0
var max_speed: float = 430.0
var drag: float = 380.0

var _target: Node2D
var _target_position: Vector2 = Vector2.ZERO
var _has_target_position: bool = false
var _collision_shape: CollisionShape2D
var _age_ticks: int = 0
var _attracting: bool = false
var _is_collected: bool = false
var _visual_color: Color = Color("84ff8b")
var _configured: bool = false


func configure(
	spawn_position: Vector2,
	orb_value: int = 1,
	target_node: Node2D = null,
	stats: Dictionary = {}
) -> XpOrb:
	global_position = spawn_position
	value = maxi(1, orb_value)
	_target = target_node
	_has_target_position = false
	attraction_radius = maxf(0.0, float(stats.get("attraction_radius", attraction_radius)))
	pickup_radius = maxf(2.0, float(stats.get("pickup_radius", pickup_radius)))
	acceleration = maxf(0.0, float(stats.get("acceleration", acceleration)))
	max_speed = maxf(0.0, float(stats.get("max_speed", max_speed)))
	drag = maxf(0.0, float(stats.get("drag", drag)))
	if stats.get("initial_velocity", null) is Vector2:
		velocity = stats["initial_velocity"]
	var requested_color: Variant = stats.get("color", null)
	if requested_color is Color:
		_visual_color = requested_color
	collision_layer = int(stats.get("collision_layer", 16))
	collision_mask = int(stats.get("collision_mask", 1))
	_configured = true
	_update_collision_shape()
	queue_redraw()
	return self


func _ready() -> void:
	monitoring = true
	monitorable = true
	_ensure_collision_shape()
	if not _configured:
		collision_layer = 16
		collision_mask = 1
	add_to_group(&"pickup")
	add_to_group(&"xp_orb")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_collected:
		return
	_age_ticks += 1

	var has_target := _refresh_target_position()
	if has_target:
		var collector: Node = _target if _target != null and is_instance_valid(_target) else null
		var offset := _target_position - global_position
		var distance_squared := offset.length_squared()
		if distance_squared <= pickup_radius * pickup_radius:
			if collector != null:
				collect(collector)
				return
			velocity = Vector2.ZERO
			queue_redraw()
			return
		if distance_squared <= attraction_radius * attraction_radius:
			if not _attracting:
				_attracting = true
				attraction_started.emit(self, collector)
			var desired := offset.normalized() * max_speed
			velocity = velocity.move_toward(desired, acceleration * delta)
		else:
			_attracting = false
			velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
	else:
		_attracting = false
		velocity = velocity.move_toward(Vector2.ZERO, drag * delta)

	global_position += velocity * delta
	queue_redraw()


func set_target(target_node: Node2D) -> void:
	_target = target_node
	_has_target_position = false
	_attracting = false


func set_target_position(world_position: Vector2) -> void:
	_target = null
	_target_position = world_position
	_has_target_position = true
	_attracting = false


func clear_target() -> void:
	_target = null
	_has_target_position = false
	_attracting = false


func collect(collector: Node = null) -> void:
	if _is_collected:
		return
	_is_collected = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	collected.emit(self, value, collector)
	queue_free()


func _refresh_target_position() -> bool:
	if _target != null:
		if is_instance_valid(_target):
			_target_position = _target.global_position
			return true
		_target = null
	if _has_target_position:
		# The orb can chase a supplied point, but only an actual player collision
		# collects it. A Node target is preferred when collection is desired.
		return true
	return false


func _on_body_entered(body: Node2D) -> void:
	_try_collect_from(body)


func _on_area_entered(area: Area2D) -> void:
	_try_collect_from(area)


func _try_collect_from(collider: Node) -> void:
	if _is_collected:
		return
	var collector := _resolve_collector(collider)
	if collector != null:
		collect(collector)


func _resolve_collector(collider: Node) -> Node:
	if collider == _target or collider.is_in_group(&"player"):
		return collider
	if collider.has_meta(&"xp_collector"):
		var receiver: Variant = collider.get_meta(&"xp_collector")
		if receiver is Node and is_instance_valid(receiver):
			return receiver
	var parent := collider.get_parent()
	if parent != null and (parent == _target or parent.is_in_group(&"player")):
		return parent
	return null


func _ensure_collision_shape() -> void:
	if _collision_shape != null:
		return
	_collision_shape = CollisionShape2D.new()
	_collision_shape.name = "PickupShape"
	var circle := CircleShape2D.new()
	circle.radius = pickup_radius
	_collision_shape.shape = circle
	add_child(_collision_shape)


func _update_collision_shape() -> void:
	if _collision_shape == null:
		return
	var circle := _collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = pickup_radius


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(float(_age_ticks) * 0.12)
	var radius := 5.0 + pulse
	var glow := Color(_visual_color, 0.18 + pulse * 0.08)
	draw_circle(Vector2.ZERO, radius + 3.0, glow)
	var diamond := PackedVector2Array([
		Vector2(0.0, -radius),
		Vector2(radius, 0.0),
		Vector2(0.0, radius),
		Vector2(-radius, 0.0),
		Vector2(0.0, -radius),
	])
	draw_polyline(diamond, _visual_color, 2.0)
	draw_line(Vector2(-2.5, 0.0), Vector2(2.5, 0.0), _visual_color, 1.5)
	draw_line(Vector2(0.0, -2.5), Vector2(0.0, 2.5), _visual_color, 1.5)
