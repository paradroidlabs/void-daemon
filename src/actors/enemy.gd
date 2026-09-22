class_name Enemy
extends Area2D

## Deterministic fixed-tick enemy actor. It owns movement, collision, health,
## telegraphs, and signals, but delegates projectile spawning and player damage
## to its caller so it remains independent of any Main scene.

signal damaged(
	enemy: Area2D,
	amount: float,
	source_id: StringName,
	hit_position: Vector2
)
signal died(
	enemy: Area2D,
	xp_value: int,
	death_position: Vector2,
	source_id: StringName
)
signal contact_hit(enemy: Area2D, target: Node, damage: float)
signal charge_telegraphed(enemy: Area2D, direction: Vector2, duration: float)
signal charge_started(enemy: Area2D, direction: Vector2)
signal shot_telegraphed(enemy: Area2D, origin: Vector2, direction: Vector2, duration: float)
signal shot_requested(enemy: Area2D, origin: Vector2, direction: Vector2, projectile_stats: Dictionary)

const TYPE_BIT: StringName = &"bit"
const TYPE_VECTOR: StringName = &"vector"
const TYPE_SENTRY: StringName = &"sentry"
const TEAM_ENEMY: StringName = &"enemy"

const STATE_MOVE: StringName = &"move"
const STATE_WINDUP: StringName = &"windup"
const STATE_CHARGE: StringName = &"charge"
const STATE_RECOVER: StringName = &"recover"
const STATE_AIM: StringName = &"aim"

var enemy_type: StringName = TYPE_BIT
var team: StringName = TEAM_ENEMY
var max_health: float = 16.0
var health: float = 16.0
var damage: float = 7.0
var xp_value: int = 1
var speed: float = 72.0
var velocity: Vector2 = Vector2.ZERO
var collision_radius: float = 9.0
var contact_cooldown: float = 0.65
var auto_free_on_death: bool = true
var simulation_enabled: bool = true

# VECTOR tuning. Defaults implement the design's long, readable 0.8 s tell.
var charge_trigger_range: float = 260.0
var charge_windup: float = 0.8
var charge_duration: float = 0.5
var charge_recovery: float = 0.45
var charge_cooldown: float = 2.7
var charge_speed: float = 270.0

# SENTRY tuning. The actor tracks during the tell and asks its owner to fire.
var preferred_range: float = 250.0
var range_tolerance: float = 35.0
var firing_range: float = 440.0
var shot_interval: float = 2.1
var shot_windup: float = 0.65
var projectile_stats: Dictionary = {
	"speed": 270.0,
	"damage": 8.0,
	"lifetime": 2.4,
	"pierce": 0,
	"source_id": &"sentry",
}

var _target: Node2D
var _target_position: Vector2 = Vector2.ZERO
var _has_target_position: bool = false
var _collision_shape: CollisionShape2D
var _configured: bool = false
var _alive: bool = true
var _physics_tick: int = 0
var _age_ticks: int = 0
var _state: StringName = STATE_MOVE
var _state_ticks_remaining: int = 0
var _action_cooldown_ticks: int = 0
var _contact_next_tick: Dictionary = {}
var _locked_direction: Vector2 = Vector2.RIGHT
var _facing: Vector2 = Vector2.DOWN
var _flash_ticks: int = 0
var _visual_color: Color = Color("ff526f")


func configure(
	kind: Variant,
	spawn_position: Vector2,
	stats: Dictionary = {},
	target_node: Node2D = null
) -> Enemy:
	enemy_type = _normalize_type(kind)
	_apply_type_defaults(enemy_type)

	max_health = maxf(1.0, float(stats.get("max_health", stats.get("health", max_health))))
	health = clampf(float(stats.get("health", max_health)), 0.0, max_health)
	damage = maxf(0.0, float(stats.get("damage", stats.get("contact_damage", damage))))
	xp_value = maxi(0, int(stats.get("xp", stats.get("xp_value", xp_value))))
	speed = maxf(0.0, float(stats.get("speed", speed)))
	collision_radius = maxf(3.0, float(stats.get("collision_radius", collision_radius)))
	contact_cooldown = maxf(0.05, float(stats.get("contact_cooldown", contact_cooldown)))
	auto_free_on_death = bool(stats.get("auto_free_on_death", auto_free_on_death))
	simulation_enabled = bool(stats.get("simulation_enabled", simulation_enabled))

	charge_trigger_range = maxf(0.0, float(stats.get("charge_trigger_range", charge_trigger_range)))
	charge_windup = maxf(0.05, float(stats.get("charge_windup", charge_windup)))
	charge_duration = maxf(0.05, float(stats.get("charge_duration", charge_duration)))
	charge_recovery = maxf(0.0, float(stats.get("charge_recovery", charge_recovery)))
	charge_cooldown = maxf(0.05, float(stats.get("charge_cooldown", charge_cooldown)))
	charge_speed = maxf(0.0, float(stats.get("charge_speed", charge_speed)))

	preferred_range = maxf(0.0, float(stats.get("preferred_range", preferred_range)))
	range_tolerance = maxf(0.0, float(stats.get("range_tolerance", range_tolerance)))
	firing_range = maxf(preferred_range, float(stats.get("firing_range", firing_range)))
	shot_interval = maxf(0.05, float(stats.get("shot_interval", shot_interval)))
	shot_windup = maxf(0.05, float(stats.get("shot_windup", shot_windup)))
	if stats.get("projectile_stats", null) is Dictionary:
		projectile_stats.merge(stats["projectile_stats"], true)

	var requested_color: Variant = stats.get("color", null)
	if requested_color is Color:
		_visual_color = requested_color

	global_position = spawn_position
	_target = target_node
	_has_target_position = false
	_alive = health > 0.0
	_physics_tick = 0
	_age_ticks = 0
	_flash_ticks = 0
	_contact_next_tick.clear()
	_state = STATE_MOVE
	_state_ticks_remaining = 0
	var initial_delay := maxf(0.0, float(stats.get("initial_action_delay", 0.6)))
	_action_cooldown_ticks = _seconds_to_ticks(initial_delay) if initial_delay > 0.0 else 0
	_configured = true

	collision_layer = int(stats.get("collision_layer", 2))
	collision_mask = int(stats.get("collision_mask", 1))
	_update_collision_shape()
	_update_identity()
	queue_redraw()
	return self


func _ready() -> void:
	monitoring = true
	monitorable = true
	_ensure_collision_shape()
	if not _configured:
		_apply_type_defaults(enemy_type)
		_action_cooldown_ticks = _seconds_to_ticks(0.6)
		collision_layer = 2
		collision_mask = 1
	_update_identity()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not _alive or not simulation_enabled:
		return

	_physics_tick += 1
	_age_ticks += 1
	if _flash_ticks > 0:
		_flash_ticks -= 1
	if _action_cooldown_ticks > 0:
		_action_cooldown_ticks -= 1

	var has_target := _refresh_target_position()
	match enemy_type:
		TYPE_VECTOR:
			_tick_vector(has_target)
		TYPE_SENTRY:
			_tick_sentry(has_target)
		_:
			_tick_bit(has_target)

	global_position += velocity * delta
	_emit_contact_hits()
	queue_redraw()


func set_target(target_node: Node2D) -> void:
	_target = target_node
	_has_target_position = false


func set_target_position(world_position: Vector2) -> void:
	_target = null
	_target_position = world_position
	_has_target_position = true


func clear_target() -> void:
	_target = null
	_has_target_position = false
	velocity = Vector2.ZERO


func get_team() -> StringName:
	return team


func get_state() -> StringName:
	return _state


func is_alive() -> bool:
	return _alive


func take_damage(
	amount: float,
	source_id: StringName = &"unknown",
	hit_position: Vector2 = Vector2.ZERO
) -> bool:
	if not _alive or amount <= 0.0:
		return false

	health = maxf(0.0, health - amount)
	_flash_ticks = 4
	var resolved_hit_position := hit_position if hit_position != Vector2.ZERO else global_position
	damaged.emit(self, amount, source_id, resolved_hit_position)
	queue_redraw()
	if health <= 0.0:
		_die(source_id)
	return true


func receive_projectile_hit(
	_projectile: Area2D,
	amount: float,
	source_id: StringName,
	hit_position: Vector2
) -> void:
	take_damage(amount, source_id, hit_position)


func kill(source_id: StringName = &"script") -> void:
	if _alive:
		health = 0.0
		_die(source_id)


static func supported_types() -> PackedStringArray:
	return PackedStringArray([TYPE_BIT, TYPE_VECTOR, TYPE_SENTRY])


func _tick_bit(has_target: bool) -> void:
	_state = STATE_MOVE
	if not has_target:
		velocity = Vector2.ZERO
		return
	var direction := global_position.direction_to(_target_position)
	velocity = direction * speed
	if not direction.is_zero_approx():
		_facing = direction


func _tick_vector(has_target: bool) -> void:
	match _state:
		STATE_WINDUP:
			velocity = Vector2.ZERO
			_state_ticks_remaining -= 1
			if _state_ticks_remaining <= 0:
				_state = STATE_CHARGE
				_state_ticks_remaining = _seconds_to_ticks(charge_duration)
				velocity = _locked_direction * charge_speed
				charge_started.emit(self, _locked_direction)
		STATE_CHARGE:
			velocity = _locked_direction * charge_speed
			_state_ticks_remaining -= 1
			if _state_ticks_remaining <= 0:
				_state = STATE_RECOVER
				_state_ticks_remaining = _seconds_to_ticks(charge_recovery)
				velocity = Vector2.ZERO
		STATE_RECOVER:
			velocity = Vector2.ZERO
			_state_ticks_remaining -= 1
			if _state_ticks_remaining <= 0:
				_state = STATE_MOVE
				_action_cooldown_ticks = _seconds_to_ticks(charge_cooldown)
		_:
			_state = STATE_MOVE
			if not has_target:
				velocity = Vector2.ZERO
				return
			var offset := _target_position - global_position
			var direction := offset.normalized() if not offset.is_zero_approx() else _facing
			_facing = direction
			if _action_cooldown_ticks <= 0 and offset.length_squared() <= charge_trigger_range * charge_trigger_range:
				_locked_direction = direction
				_state = STATE_WINDUP
				_state_ticks_remaining = _seconds_to_ticks(charge_windup)
				velocity = Vector2.ZERO
				charge_telegraphed.emit(self, _locked_direction, charge_windup)
			else:
				velocity = direction * speed


func _tick_sentry(has_target: bool) -> void:
	if _state == STATE_AIM:
		velocity = Vector2.ZERO
		if has_target:
			var tracking_direction := global_position.direction_to(_target_position)
			if not tracking_direction.is_zero_approx():
				_facing = tracking_direction
		_state_ticks_remaining -= 1
		if _state_ticks_remaining <= 0:
			_state = STATE_MOVE
			_action_cooldown_ticks = _seconds_to_ticks(shot_interval)
			shot_requested.emit(
				self,
				global_position + _facing * collision_radius,
				_facing,
				projectile_stats.duplicate(true)
			)
		return

	_state = STATE_MOVE
	if not has_target:
		velocity = Vector2.ZERO
		return

	var offset := _target_position - global_position
	var distance := offset.length()
	var direction := offset / distance if distance > 0.001 else _facing
	_facing = direction
	if distance > preferred_range + range_tolerance:
		velocity = direction * speed
	elif distance < preferred_range - range_tolerance:
		velocity = -direction * speed
	else:
		velocity = Vector2.ZERO

	if _action_cooldown_ticks <= 0 and distance <= firing_range:
		_state = STATE_AIM
		_state_ticks_remaining = _seconds_to_ticks(shot_windup)
		velocity = Vector2.ZERO
		shot_telegraphed.emit(
			self,
			global_position + _facing * collision_radius,
			_facing,
			shot_windup
		)


func _refresh_target_position() -> bool:
	if _target != null:
		if is_instance_valid(_target):
			_target_position = _target.global_position
			return true
		_target = null
	return _has_target_position


func _emit_contact_hits() -> void:
	var seen: Dictionary = {}
	for body: Node2D in get_overlapping_bodies():
		_try_contact(body, seen)
	for area: Area2D in get_overlapping_areas():
		_try_contact(area, seen)


func _try_contact(collider: Node, seen: Dictionary) -> void:
	var target := _resolve_contact_target(collider)
	if target == null or not _can_contact(target):
		return
	var target_id := target.get_instance_id()
	if seen.has(target_id):
		return
	seen[target_id] = true
	var next_tick := int(_contact_next_tick.get(target_id, 0))
	if _physics_tick < next_tick:
		return
	_contact_next_tick[target_id] = _physics_tick + _seconds_to_ticks(contact_cooldown)
	contact_hit.emit(self, target, damage)


func _resolve_contact_target(collider: Node) -> Node:
	if collider == self:
		return null
	if collider.has_meta(&"contact_receiver"):
		var receiver: Variant = collider.get_meta(&"contact_receiver")
		if receiver is Node and is_instance_valid(receiver):
			return receiver
	if collider.is_in_group(&"player") or collider.has_method(&"receive_contact_hit"):
		return collider
	var parent := collider.get_parent()
	if parent != null and (
		parent.is_in_group(&"player") or parent.has_method(&"receive_contact_hit")
	):
		return parent
	return null


func _can_contact(target: Node) -> bool:
	if target.is_in_group(&"enemy"):
		return false
	if target.has_method(&"get_team") and StringName(str(target.call(&"get_team"))) == team:
		return false
	if target.has_meta(&"team") and StringName(str(target.get_meta(&"team"))) == team:
		return false
	return target.is_in_group(&"player") or target.has_method(&"receive_contact_hit")


func _die(source_id: StringName) -> void:
	if not _alive:
		return
	_alive = false
	velocity = Vector2.ZERO
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	died.emit(self, xp_value, global_position, source_id)
	if auto_free_on_death:
		queue_free()
	else:
		hide()


func _normalize_type(kind: Variant) -> StringName:
	var normalized := StringName(str(kind).to_lower())
	if normalized == TYPE_VECTOR or normalized == TYPE_SENTRY:
		return normalized
	return TYPE_BIT


func _apply_type_defaults(kind: StringName) -> void:
	match kind:
		TYPE_VECTOR:
			max_health = 26.0
			health = max_health
			damage = 12.0
			xp_value = 3
			speed = 58.0
			collision_radius = 11.0
			_visual_color = Color("ffbd4a")
		TYPE_SENTRY:
			max_health = 34.0
			health = max_health
			damage = 9.0
			xp_value = 4
			speed = 42.0
			collision_radius = 12.0
			_visual_color = Color("ff65df")
		_:
			max_health = 16.0
			health = max_health
			damage = 7.0
			xp_value = 1
			speed = 72.0
			collision_radius = 9.0
			_visual_color = Color("ff526f")


func _ensure_collision_shape() -> void:
	if _collision_shape != null:
		return
	_collision_shape = CollisionShape2D.new()
	_collision_shape.name = "BodyShape"
	var circle := CircleShape2D.new()
	circle.radius = collision_radius
	_collision_shape.shape = circle
	add_child(_collision_shape)


func _update_collision_shape() -> void:
	if _collision_shape == null:
		return
	var circle := _collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = collision_radius


func _update_identity() -> void:
	if not is_inside_tree():
		return
	remove_from_group(&"enemy_bit")
	remove_from_group(&"enemy_vector")
	remove_from_group(&"enemy_sentry")
	add_to_group(&"enemy")
	add_to_group(&"enemies")
	add_to_group(StringName("enemy_%s" % enemy_type))
	set_meta(&"team", team)


func _seconds_to_ticks(seconds: float) -> int:
	return maxi(1, int(ceil(seconds * float(Engine.physics_ticks_per_second))))


func _draw() -> void:
	if not _alive:
		return

	var color := Color.WHITE if _flash_ticks > 0 else _visual_color
	if enemy_type == TYPE_VECTOR and _state == STATE_WINDUP:
		_draw_lane_telegraph(_locked_direction, color)
	elif enemy_type == TYPE_SENTRY and _state == STATE_AIM:
		_draw_lane_telegraph(_facing, color)

	match enemy_type:
		TYPE_VECTOR:
			_draw_vector_glyph(color)
		TYPE_SENTRY:
			_draw_sentry_glyph(color)
		_:
			_draw_bit_glyph(color)
	_draw_health_bar(color)


func _draw_bit_glyph(color: Color) -> void:
	# [.] -- broad brackets remain readable underneath projectile effects.
	draw_line(Vector2(-8.0, -6.0), Vector2(-8.0, 6.0), color, 2.0)
	draw_line(Vector2(-8.0, -6.0), Vector2(-5.0, -6.0), color, 2.0)
	draw_line(Vector2(-8.0, 6.0), Vector2(-5.0, 6.0), color, 2.0)
	draw_line(Vector2(8.0, -6.0), Vector2(8.0, 6.0), color, 2.0)
	draw_line(Vector2(5.0, -6.0), Vector2(8.0, -6.0), color, 2.0)
	draw_line(Vector2(5.0, 6.0), Vector2(8.0, 6.0), color, 2.0)
	draw_rect(Rect2(-2.0, -2.0, 4.0, 4.0), color)


func _draw_vector_glyph(color: Color) -> void:
	# [>] -- the chevron points along the actor's current facing.
	var angle := _facing.angle()
	var points := PackedVector2Array([
		Vector2(-7.0, -7.0).rotated(angle),
		Vector2(7.0, 0.0).rotated(angle),
		Vector2(-7.0, 7.0).rotated(angle),
	])
	draw_polyline(points, color, 3.0)
	draw_line(
		Vector2(-5.0, 0.0).rotated(angle),
		Vector2(5.0, 0.0).rotated(angle),
		color,
		2.0
	)


func _draw_sentry_glyph(color: Color) -> void:
	# [^] -- a square anchor plus a rotating rail caret.
	draw_rect(Rect2(-8.0, -8.0, 16.0, 16.0), color, false, 2.0)
	var angle := _facing.angle() + PI * 0.5
	var left := Vector2(-6.0, 4.0).rotated(angle)
	var tip := Vector2(0.0, -7.0).rotated(angle)
	var right := Vector2(6.0, 4.0).rotated(angle)
	draw_polyline(PackedVector2Array([left, tip, right]), color, 2.5)
	draw_circle(Vector2.ZERO, 2.0, color)


func _draw_lane_telegraph(direction: Vector2, color: Color) -> void:
	var safe_direction := direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	var telegraph_color := Color(color, 0.55)
	var end := safe_direction * 520.0
	draw_line(safe_direction * collision_radius, end, telegraph_color, 2.0)
	draw_dashed_line(safe_direction * collision_radius, end, Color.WHITE, 1.0, 9.0)


func _draw_health_bar(color: Color) -> void:
	if health >= max_health or max_health <= 0.0:
		return
	var width := 20.0
	var ratio := clampf(health / max_health, 0.0, 1.0)
	var top := -collision_radius - 7.0
	draw_rect(Rect2(-width * 0.5, top, width, 3.0), Color("321a28"))
	draw_rect(Rect2(-width * 0.5, top, width * ratio, 3.0), color)
