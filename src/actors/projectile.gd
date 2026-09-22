class_name Projectile
extends Area2D

## Lightweight, scene-free projectile used by both player and enemy weapons.
## Pierce is the number of *additional* targets the projectile may cross after
## its first hit: 0 hits one target, 1 hits two targets, and so on.

signal projectile_hit(
	projectile: Area2D,
	target: Node,
	damage_dealt: float,
	hit_position: Vector2
)
signal expired(projectile: Area2D, reason: StringName)

const TEAM_PLAYER: StringName = &"player"
const TEAM_ENEMY: StringName = &"enemy"

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var lifetime: float = 1.5
var pierce: int = 0
var fork_generation: int = 0
var source_id: StringName = &"unknown"
var team: StringName = TEAM_PLAYER
var speed: float = 560.0
var hit_radius: float = 4.0
var auto_apply_damage: bool = true

var _direction: Vector2 = Vector2.RIGHT
var _life_ticks_remaining: int = 1
var _hit_targets: Dictionary = {}
var _collision_shape: CollisionShape2D
var _visual_color: Color = Color("73f7ff")
var _is_expired: bool = false
var _configured: bool = false


func configure(
	owner_pos: Vector2,
	direction: Vector2,
	stats: Dictionary,
	projectile_team: StringName = TEAM_PLAYER
) -> Projectile:
	global_position = owner_pos
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	team = projectile_team

	speed = maxf(0.0, float(stats.get("speed", speed)))
	damage = maxf(0.0, float(stats.get("damage", damage)))
	lifetime = maxf(0.01, float(stats.get("lifetime", lifetime)))
	pierce = maxi(0, int(stats.get("pierce", pierce)))
	fork_generation = maxi(0, int(stats.get("fork_generation", fork_generation)))
	source_id = StringName(str(stats.get("source_id", source_id)))
	hit_radius = maxf(1.0, float(stats.get("hit_radius", stats.get("radius", hit_radius))))
	auto_apply_damage = bool(stats.get("auto_apply_damage", auto_apply_damage))

	var requested_color: Variant = stats.get("color", null)
	if requested_color is Color:
		_visual_color = requested_color
	else:
		_visual_color = Color("73f7ff") if team == TEAM_PLAYER else Color("ff526f")

	velocity = _direction * speed
	rotation = _direction.angle()
	_life_ticks_remaining = _seconds_to_ticks(lifetime)
	_hit_targets.clear()
	_is_expired = false
	_configured = true

	_apply_collision_defaults(stats)
	_update_collision_shape()
	_update_team_group()
	queue_redraw()
	return self


func _ready() -> void:
	monitoring = true
	monitorable = true
	_ensure_collision_shape()
	if not _configured:
		_life_ticks_remaining = _seconds_to_ticks(lifetime)
		velocity = _direction * speed
		_apply_collision_defaults({})
	_update_team_group()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _is_expired:
		return

	global_position += velocity * delta
	_life_ticks_remaining -= 1
	if _life_ticks_remaining <= 0:
		expire(&"lifetime")


func get_team() -> StringName:
	return team


func has_hit(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	return _hit_targets.has(target.get_instance_id())


func get_remaining_lifetime() -> float:
	return float(_life_ticks_remaining) / float(Engine.physics_ticks_per_second)


func make_child_stats(overrides: Dictionary = {}) -> Dictionary:
	var child_stats := {
		"speed": speed,
		"damage": damage,
		"lifetime": get_remaining_lifetime(),
		"pierce": pierce,
		"fork_generation": fork_generation + 1,
		"source_id": source_id,
		"hit_radius": hit_radius,
		"auto_apply_damage": auto_apply_damage,
		"color": _visual_color,
	}
	for key: Variant in overrides:
		child_stats[key] = overrides[key]
	return child_stats


func expire(reason: StringName = &"manual") -> void:
	if _is_expired:
		return
	_is_expired = true
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	set_physics_process(false)
	expired.emit(self, reason)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	_try_hit(area)


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(collider: Node) -> void:
	if _is_expired or not is_instance_valid(collider) or collider == self:
		return

	var target := _resolve_damage_target(collider)
	if target == null or not _can_damage(target):
		return

	var target_id := target.get_instance_id()
	if _hit_targets.has(target_id):
		return
	_hit_targets[target_id] = true

	projectile_hit.emit(self, target, damage, global_position)
	if auto_apply_damage:
		_apply_damage(target)

	if pierce <= 0:
		expire(&"hit")
	else:
		pierce -= 1


func _resolve_damage_target(collider: Node) -> Node:
	if collider.has_meta(&"damage_receiver"):
		var receiver: Variant = collider.get_meta(&"damage_receiver")
		if receiver is Node and is_instance_valid(receiver):
			return receiver
	if collider.has_method(&"receive_projectile_hit") or collider.has_method(&"take_damage"):
		return collider
	var parent := collider.get_parent()
	if parent != null and (
		parent.has_method(&"receive_projectile_hit") or parent.has_method(&"take_damage")
	):
		return parent
	return null


func _can_damage(target: Node) -> bool:
	var target_team := _read_team(target)
	if not target_team.is_empty() and target_team == team:
		return false
	if team == TEAM_PLAYER and target.is_in_group(&"player"):
		return false
	if team == TEAM_ENEMY and target.is_in_group(&"enemy"):
		return false
	return target.has_method(&"receive_projectile_hit") or target.has_method(&"take_damage")


func _apply_damage(target: Node) -> void:
	if target.has_method(&"receive_projectile_hit"):
		target.call(&"receive_projectile_hit", self, damage, source_id, global_position)
	elif target.has_method(&"take_damage"):
		# One argument is the broadest interoperable damage contract. Consumers that
		# need source metadata should implement receive_projectile_hit instead.
		target.call(&"take_damage", damage)


func _read_team(target: Node) -> StringName:
	if target.has_method(&"get_team"):
		return StringName(str(target.call(&"get_team")))
	if target.has_meta(&"team"):
		return StringName(str(target.get_meta(&"team")))
	if target.is_in_group(&"player"):
		return TEAM_PLAYER
	if target.is_in_group(&"enemy"):
		return TEAM_ENEMY
	return &""


func _apply_collision_defaults(stats: Dictionary) -> void:
	var default_layer := 4 if team == TEAM_PLAYER else 8
	var default_mask := 2 if team == TEAM_PLAYER else 1
	collision_layer = int(stats.get("collision_layer", default_layer))
	collision_mask = int(stats.get("collision_mask", default_mask))


func _ensure_collision_shape() -> void:
	if _collision_shape != null:
		return
	_collision_shape = CollisionShape2D.new()
	_collision_shape.name = "HitShape"
	var circle := CircleShape2D.new()
	circle.radius = hit_radius
	_collision_shape.shape = circle
	add_child(_collision_shape)


func _update_collision_shape() -> void:
	if _collision_shape == null:
		return
	var circle := _collision_shape.shape as CircleShape2D
	if circle != null:
		circle.radius = hit_radius


func _update_team_group() -> void:
	if not is_inside_tree():
		return
	remove_from_group(&"projectile_player")
	remove_from_group(&"projectile_enemy")
	add_to_group(&"projectile")
	add_to_group(&"projectile_player" if team == TEAM_PLAYER else &"projectile_enemy")
	set_meta(&"team", team)


func _seconds_to_ticks(seconds: float) -> int:
	return maxi(1, int(ceil(seconds * float(Engine.physics_ticks_per_second))))


func _draw() -> void:
	var glow := Color(_visual_color, 0.22)
	draw_circle(Vector2.ZERO, hit_radius + 2.0, glow)
	draw_line(Vector2(-7.0, 0.0), Vector2(5.0, 0.0), _visual_color, 2.0)
	draw_colored_polygon(
		PackedVector2Array([Vector2(8.0, 0.0), Vector2(2.0, -3.5), Vector2(2.0, 3.5)]),
		_visual_color
	)
