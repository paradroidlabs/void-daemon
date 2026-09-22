class_name WatchdogBoss
extends Area2D

signal died(boss: Node, xp_value: int, source_id: String)
signal shot_requested(origin: Vector2, direction: Vector2, stats: Dictionary)
signal phase_changed(phase: int)

const MAGENTA := Color("ff4fd8")
const RED := Color("ff496c")
const AMBER := Color("ffbd4a")
const DARK := Color("190b1b")

var target: Node2D
var max_health: float = 1500.0
var health: float = 1500.0
var contact_damage: float = 24.0
var collision_radius: float = 54.0
var xp_value: int = 40
var phase: int = 1
var is_dead: bool = false
var velocity := Vector2.ZERO

var _attack_cooldown: float = 1.3
var _pattern_index: int = 0
var _telegraph_left: float = 0.0
var _queued_pattern: int = 0
var _orbit_sign: float = 1.0
var _hit_flash: float = 0.0


func configure(target_node: Node2D, difficulty: float = 1.0) -> void:
	target = target_node
	max_health = 1500.0 * maxf(0.5, difficulty)
	health = max_health
	contact_damage = 24.0 * maxf(0.75, difficulty)
	_orbit_sign = -1.0 if (int(global_position.x + global_position.y) & 1) == 1 else 1.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("bosses")
	collision_layer = 2
	collision_mask = 1
	monitoring = true
	monitorable = true
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = collision_radius
	collision.shape = circle
	add_child(collision)
	z_index = 12
	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_dead or not is_instance_valid(target):
		return
	_hit_flash = maxf(0.0, _hit_flash - delta)
	var to_player := target.global_position - global_position
	var distance := to_player.length()
	var desired := Vector2.ZERO
	if distance > 300.0:
		desired = to_player.normalized() * 105.0
	elif distance < 205.0:
		desired = -to_player.normalized() * 85.0
	else:
		desired = to_player.normalized().orthogonal() * _orbit_sign * (95.0 + phase * 8.0)
	velocity = velocity.move_toward(desired, 260.0 * delta)
	global_position += velocity * delta
	rotation += delta * (0.45 + phase * 0.18) * _orbit_sign

	if _telegraph_left > 0.0:
		_telegraph_left -= delta
		if _telegraph_left <= 0.0:
			_execute_pattern(_queued_pattern)
	else:
		_attack_cooldown -= delta
		if _attack_cooldown <= 0.0:
			_queue_attack()
	queue_redraw()


func take_damage(amount: float, source_id: String = "", _hit_position: Vector2 = Vector2.ZERO) -> bool:
	if is_dead or amount <= 0.0:
		return false
	health -= amount
	_hit_flash = 0.08
	var next_phase := 3 if health <= max_health * 0.34 else (2 if health <= max_health * 0.68 else 1)
	if next_phase != phase:
		phase = next_phase
		phase_changed.emit(phase)
		_attack_cooldown = 0.45
	if health <= 0.0:
		is_dead = true
		died.emit(self, xp_value, source_id)
		queue_free()
	return is_dead


func get_team() -> StringName:
	return &"enemy"


func is_alive() -> bool:
	return not is_dead


func receive_projectile_hit(
	_projectile: Area2D,
	amount: float,
	source_id: StringName,
	_hit_position: Vector2
) -> void:
	take_damage(amount, String(source_id))


func get_health_ratio() -> float:
	return clampf(health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0


func _queue_attack() -> void:
	_pattern_index += 1
	_queued_pattern = (_pattern_index + phase) % 3
	_telegraph_left = maxf(0.32, 0.58 - phase * 0.07)
	_attack_cooldown = maxf(0.62, 1.55 - phase * 0.22)


func _execute_pattern(pattern: int) -> void:
	if not is_instance_valid(target):
		return
	var aim := (target.global_position - global_position).normalized()
	match pattern:
		0:
			var count := 3 + phase * 2
			var spread := 0.18 + phase * 0.04
			for index in range(count):
				var offset := (float(index) - float(count - 1) * 0.5) * spread
				_emit_shot(aim.rotated(offset), 265.0 + phase * 18.0, 10.0 + phase * 2.0)
		1:
			var count := 8 + phase * 2
			var rotation_offset := float(_pattern_index % 2) * PI / float(count)
			for index in range(count):
				_emit_shot(Vector2.RIGHT.rotated(rotation_offset + TAU * float(index) / float(count)), 215.0 + phase * 16.0, 9.0 + phase)
		2:
			# A generous three-lane burst: the center lane arrives first, sides are slower.
			_emit_shot(aim, 390.0, 15.0)
			_emit_shot(aim.rotated(-0.46), 250.0, 11.0)
			_emit_shot(aim.rotated(0.46), 250.0, 11.0)


func _emit_shot(direction: Vector2, speed: float, damage: float) -> void:
	shot_requested.emit(global_position, direction.normalized(), {
		"speed": speed,
		"damage": damage,
		"lifetime": 4.5,
		"radius": 6.0,
		"pierce": 0,
		"color": MAGENTA,
		"source_id": "WATCHDOG",
	})


func _draw() -> void:
	var body_color := Color.WHITE if _hit_flash > 0.0 else MAGENTA
	var points := PackedVector2Array()
	for index in range(8):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 8.0) * (38.0 if index % 2 == 0 else 30.0))
	draw_colored_polygon(points, DARK)
	draw_polyline(points + PackedVector2Array([points[0]]), body_color, 3.0, true)
	draw_circle(Vector2.ZERO, 11.0 + phase * 2.0, Color(RED, 0.75))
	draw_arc(Vector2.ZERO, collision_radius, 0.0, TAU, 48, Color(MAGENTA, 0.28), 2.0)
	for index in range(phase + 1):
		var angle := Time.get_ticks_msec() * 0.0015 * _orbit_sign + TAU * float(index) / float(phase + 1)
		draw_circle(Vector2.RIGHT.rotated(angle) * 45.0, 3.5, AMBER)
	if _telegraph_left > 0.0 and is_instance_valid(target):
		var local_target := to_local(target.global_position)
		draw_line(Vector2.ZERO, local_target.limit_length(420.0), Color(AMBER, 0.75), 2.0)
	var bar_rect := Rect2(-52.0, -70.0, 104.0, 7.0)
	draw_rect(bar_rect, Color(0.08, 0.02, 0.08, 0.92), true)
	draw_rect(Rect2(bar_rect.position + Vector2.ONE, Vector2((bar_rect.size.x - 2.0) * get_health_ratio(), bar_rect.size.y - 2.0)), MAGENTA, true)
	draw_rect(bar_rect, Color(MAGENTA, 0.72), false, 1.0)
