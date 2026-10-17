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
var combo_mode := false
var phase_cooldown := 0.0
var phase_uses := 0
var phase_distance := 0.0
var last_move_direction := Vector2.RIGHT
var unleash_charge_ratio := 0.0
var unleash_loaded := 0
var unleash_firing_flash := 0.0
var unleash_focus := Vector2.ZERO
var run_stats := {
	"hits_taken": 0, "hull_damage": 0.0, "shield_absorbed": 0.0,
	"hull_repaired": 0.0, "shield_restored": 0.0, "distance": 0.0,
	"heat_generated": 0.0, "heat_vented": 0.0, "peak_heat": 0.0,
	"throttled_seconds": 0.0, "vents": 0, "hot_vents": 0,
}

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
	if get_heat_ratio() >= 0.92:
		run_stats["throttled_seconds"] += delta

	vent_cooldown = maxf(0.0, vent_cooldown - delta)
	phase_cooldown = maxf(0.0, phase_cooldown - delta)
	unleash_firing_flash = maxf(0.0, unleash_firing_flash - delta)
	if move_intent.length_squared() > 0.02:
		last_move_direction = move_intent.normalized()
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
		run_stats["shield_restored"] += shield - old_shield
		if not is_equal_approx(old_shield, shield):
			shield_changed.emit(shield, max_shield)

	var desired_velocity := move_intent.limit_length() * move_speed
	if _escape_thrust_left > 0.0:
		desired_velocity += _escape_direction * move_speed * 0.45
	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	var previous_position := global_position
	move_and_slide()
	global_position = Vector2(
		clampf(global_position.x, arena_bounds.position.x + 24.0, arena_bounds.end.x - 24.0),
		clampf(global_position.y, arena_bounds.position.y + 24.0, arena_bounds.end.y - 24.0)
	)
	run_stats["distance"] += global_position.distance_to(previous_position)

	if combo_mode and unleash_loaded > 0:
		rotation = lerp_angle(rotation, (unleash_focus - global_position).angle(), minf(1.0, delta * 15))
	elif velocity.length_squared() > 16.0:
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


func try_phase_skip() -> bool:
	if is_dead or phase_cooldown > 0:
		return false
	var direction := move_intent.normalized() if move_intent.length_squared() > 0.02 else last_move_direction
	var destination := global_position + direction * 210.0
	destination.x = clampf(destination.x, arena_bounds.position.x + 24, arena_bounds.end.x - 24)
	destination.y = clampf(destination.y, arena_bounds.position.y + 24, arena_bounds.end.y - 24)
	# Terrain has its own layer: enemy bodies must not block a phase skip.
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14
	query.shape = shape
	query.transform = Transform2D(0, global_position)
	query.motion = destination - global_position
	query.collision_mask = 16
	var fraction := get_world_2d().direct_space_state.cast_motion(query)
	if not fraction.is_empty():
		destination = global_position + query.motion * fraction[0]
	var traveled := global_position.distance_to(destination)
	if traveled < 2:
		return false
	global_position = destination
	phase_cooldown = 4.2
	_invulnerable_left = maxf(_invulnerable_left, 0.22)
	phase_uses += 1
	phase_distance += traveled
	queue_redraw()
	return true


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
	run_stats["heat_generated"] += maxf(0.0, amount)
	run_stats["peak_heat"] = maxf(float(run_stats["peak_heat"]), heat)
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
	run_stats["vents"] += 1
	run_stats["hot_vents"] += 1 if ratio >= 0.75 else 0
	run_stats["heat_vented"] += heat
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
	var shield_before := shield
	if shield > 0.0:
		var absorbed := minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
		shield_changed.emit(shield, max_shield)
	var hull_damage := minf(hull, remaining)
	run_stats["hits_taken"] += 1
	run_stats["hull_damage"] += hull_damage
	run_stats["shield_absorbed"] += shield_before - shield
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
	var previous_hull := hull
	hull = minf(max_hull, hull + maxf(0.0, amount))
	run_stats["hull_repaired"] += hull - previous_hull
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
			run_stats["shield_restored"] += minf(3.0, max_shield - shield)
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
	if combo_mode:
		var spread := 15.0 + unleash_charge_ratio * 8.0
		for side in [-1.0, 1.0]:
			var rack := Rect2(-12, side * spread - 5, 24, 10)
			draw_rect(rack, Color("152d3b"))
			draw_rect(rack, Color("ac98ff"), false, 1.3)
			for cell in range(3):
				var ready := cell * 2 + (0 if side < 0 else 1) < unleash_loaded
				draw_rect(Rect2(Vector2(-8 + cell * 7, side * spread - 2), Vector2(4, 4)), AMBER if ready else Color("365066"))
			if unleash_firing_flash > 0:
				draw_line(Vector2(12, side * spread), Vector2(27, side * spread), Color("ffe7bc"), 4, true)
		if unleash_loaded > 0:
			draw_arc(Vector2.ZERO, 33, -PI / 2, -PI / 2 + TAU * maxf(0.04, unleash_charge_ratio), 40, Color("c2a8ff"), 2.0, true)
	if shield > 0.0 and not is_dead:
		draw_arc(Vector2.ZERO, 24.0, -2.45, 2.45, 32, Color(CYAN_DIM, 0.75), 2.0)
	if _invulnerable_left > 0.0 and not is_dead:
		draw_arc(Vector2.ZERO, 29.0, 0.0, TAU, 30, Color(AMBER, 0.45), 1.5)
	if velocity.length_squared() > 100.0 and not is_dead:
		var flame_length := clampf(velocity.length() / move_speed, 0.2, 1.0) * 14.0
		draw_line(Vector2(-10.0, 0.0), Vector2(-10.0 - flame_length, 0.0), AMBER, 3.0)
