class_name PlayerShip
extends CharacterBody2D

signal hull_changed(current: float, maximum: float)
signal shield_changed(current: float, maximum: float)
signal heat_changed(current: float, maximum: float)
signal vented(position: Vector2, heat_ratio: float)
signal damaged(amount: float, hull_damage: float)
signal died

const CYAN := Color("68f7e5")
const CYAN_DIM := Color("1f827e")
const AMBER := Color("ffbd4a")
const RED := Color("ff496c")

var max_hull: float = 100.0
var hull: float = 100.0
var max_shield: float = 30.0
var shield: float = 30.0
var move_speed: float = 285.0
var acceleration: float = 1900.0

var heat: float = 0.0
var max_heat: float = 100.0
var heat_cooling_per_second: float = 13.0
var vent_base_cooldown: float = 5.5
var vent_cooldown: float = 0.0
var shield_regen_delay: float = 4.0
var shield_regen_rate: float = 7.0
var collision_grace: float = 0.55

var move_intent := Vector2.ZERO
var aim_direction := Vector2.RIGHT
var aim_active: bool = false
var arena_bounds := Rect2(-1600.0, -900.0, 3200.0, 1800.0)
var is_dead: bool = false

var _shield_delay_left: float = 0.0
var _invulnerable_left: float = 0.0
var _escape_thrust_left: float = 0.0
var _escape_direction := Vector2.ZERO
var _vent_cooldown_reduction: float = 0.0
var _shield_delay_reduction: float = 0.0
var _extra_collision_grace: float = 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	collision.shape = circle
	add_child(collision)
	z_index = 20
	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = velocity.move_toward(Vector2.ZERO, acceleration * delta)
		move_and_slide()
		return

	vent_cooldown = maxf(0.0, vent_cooldown - delta)
	_invulnerable_left = maxf(0.0, _invulnerable_left - delta)
	_shield_delay_left = maxf(0.0, _shield_delay_left - delta)
	_escape_thrust_left = maxf(0.0, _escape_thrust_left - delta)

	var old_heat := heat
	heat = maxf(0.0, heat - heat_cooling_per_second * delta)
	if not is_equal_approx(old_heat, heat):
		heat_changed.emit(heat, max_heat)

	if _shield_delay_left <= 0.0 and shield < max_shield:
		var old_shield := shield
		shield = minf(max_shield, shield + shield_regen_rate * delta)
		if not is_equal_approx(old_shield, shield):
			shield_changed.emit(shield, max_shield)

	var desired_velocity := move_intent.limit_length() * move_speed
	if _escape_thrust_left > 0.0:
		desired_velocity += _escape_direction * move_speed * 0.45
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	move_and_slide()
	global_position = Vector2(
		clampf(global_position.x, arena_bounds.position.x + 24.0, arena_bounds.end.x - 24.0),
		clampf(global_position.y, arena_bounds.position.y + 24.0, arena_bounds.end.y - 24.0)
	)

	if velocity.length_squared() > 16.0:
		rotation = lerp_angle(rotation, velocity.angle(), minf(1.0, delta * 9.0))
	queue_redraw()


func set_move_intent(value: Vector2) -> void:
	move_intent = value.limit_length()


func set_aim_bias(direction: Vector2, active: bool) -> void:
	aim_active = active and direction.length_squared() > 0.01
	if aim_active:
		aim_direction = direction.normalized()


func get_team() -> StringName:
	return &"player"


func receive_projectile_hit(
	projectile: Area2D,
	amount: float,
	_source_id: StringName,
	_hit_position: Vector2
) -> void:
	var source_position := projectile.global_position if is_instance_valid(projectile) else Vector2.INF
	take_damage(amount, source_position)


func refund_vent_cooldown(seconds: float) -> void:
	vent_cooldown = maxf(0.0, vent_cooldown - maxf(0.0, seconds))


func add_heat(amount: float) -> void:
	if is_dead:
		return
	heat = clampf(heat + amount, 0.0, max_heat)
	heat_changed.emit(heat, max_heat)


func get_heat_ratio() -> float:
	return heat / max_heat if max_heat > 0.0 else 0.0


func get_throttle_scale() -> float:
	var ratio := get_heat_ratio()
	if ratio < 0.92:
		return 1.0
	return lerpf(1.0, 0.58, inverse_lerp(0.92, 1.0, ratio))


func try_vent() -> bool:
	if is_dead or vent_cooldown > 0.0:
		return false
	var ratio := get_heat_ratio()
	vent_cooldown = maxf(1.7, vent_base_cooldown - _vent_cooldown_reduction)
	_invulnerable_left = maxf(_invulnerable_left, 0.24)
	heat = 0.0
	heat_changed.emit(heat, max_heat)
	vented.emit(global_position, ratio)
	queue_redraw()
	return true


func take_damage(amount: float, source_position: Vector2 = Vector2.INF) -> bool:
	if is_dead or _invulnerable_left > 0.0 or amount <= 0.0:
		return false
	var remaining := amount
	if shield > 0.0:
		var absorbed := minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		shield_changed.emit(shield, max_shield)
	var hull_damage := minf(hull, remaining)
	if hull_damage > 0.0:
		hull -= hull_damage
		hull_changed.emit(hull, max_hull)
	_invulnerable_left = collision_grace + _extra_collision_grace
	_shield_delay_left = maxf(0.8, shield_regen_delay - _shield_delay_reduction)
	if source_position != Vector2.INF:
		_escape_direction = (global_position - source_position).normalized()
		_escape_thrust_left = 0.35 if _extra_collision_grace > 0.0 else 0.0
	damaged.emit(amount, hull_damage)
	if hull <= 0.0:
		is_dead = true
		died.emit()
	queue_redraw()
	return true


func heal_hull(amount: float) -> void:
	if is_dead:
		return
	hull = minf(max_hull, hull + maxf(0.0, amount))
	hull_changed.emit(hull, max_hull)


func apply_upgrade(upgrade_id: String, rank: int) -> void:
	match upgrade_id:
		"HULL_PLATING":
			max_hull += 18.0
			hull += 18.0
			hull_changed.emit(hull, max_hull)
		"KINETIC_DAMPERS":
			_extra_collision_grace = 0.12 * rank
		"SHIELD_CAPACITOR":
			max_shield += 12.0
			shield += 12.0
			shield_changed.emit(shield, max_shield)
		"SHIELD_REBOOT":
			_shield_delay_reduction = 0.35 * rank
			shield = minf(max_shield, shield + 3.0)
			shield_changed.emit(shield, max_shield)
		"VENT_COOLANT":
			_vent_cooldown_reduction = 0.45 * rank


func get_status() -> Dictionary:
	return {
		"hull": hull,
		"max_hull": max_hull,
		"shield": shield,
		"max_shield": max_shield,
		"heat": heat,
		"max_heat": max_heat,
		"vent_cooldown": vent_cooldown,
		"vent_ready": vent_cooldown <= 0.0,
	}


func _draw() -> void:
	var hull_color := RED if is_dead else CYAN
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.05
	var ship := PackedVector2Array([
		Vector2(19.0, 0.0) * pulse,
		Vector2(-12.0, -12.0),
		Vector2(-7.0, 0.0),
		Vector2(-12.0, 12.0),
	])
	draw_colored_polygon(ship, Color(0.02, 0.10, 0.11, 0.95))
	draw_polyline(ship + PackedVector2Array([ship[0]]), hull_color, 2.2, true)
	draw_circle(Vector2.ZERO, 4.0, AMBER if get_heat_ratio() > 0.75 else CYAN)
	if shield > 0.0 and not is_dead:
		draw_arc(Vector2.ZERO, 24.0, -2.45, 2.45, 32, Color(CYAN_DIM, 0.75), 2.0)
	if _invulnerable_left > 0.0 and not is_dead:
		draw_arc(Vector2.ZERO, 29.0, 0.0, TAU, 30, Color(AMBER, 0.45), 1.5)
	if velocity.length_squared() > 100.0 and not is_dead:
		var flame_length := clampf(velocity.length() / move_speed, 0.2, 1.0) * 14.0
		draw_line(Vector2(-10.0, 0.0), Vector2(-10.0 - flame_length, 0.0), AMBER, 3.0)
