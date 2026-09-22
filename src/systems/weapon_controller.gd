class_name WeaponController
extends Node

signal projectile_requested(origin: Vector2, direction: Vector2, stats: Dictionary, team: StringName)
signal arc_fired(points: PackedVector2Array, color: Color)
signal heat_generated(amount: float)
signal vent_pulse_requested(position: Vector2, radius: float, damage: float, force: float)
signal combat_log(message: String, color: Color)
signal sfx_requested(cue: StringName)

const CYAN := Color("68f7e5")
const AMBER := Color("ffbd4a")
const ARC_COLOR := Color("9aa7ff")

var upgrades: Dictionary = {}
var enabled: bool = true

var _mass_cooldown: float = 0.18
var _arc_cooldown: float = 0.7
var _marked_enemy: Node


func set_upgrades(value: Dictionary) -> void:
	upgrades = value


func tick(delta: float, player: PlayerShip, enemies: Array[Node]) -> void:
	if not enabled or not is_instance_valid(player) or player.is_dead:
		return
	var cadence := 1.0 + 0.10 * _rank("OVERCLOCK_KERNEL")
	var throttle := player.get_throttle_scale()
	_mass_cooldown -= delta * cadence * throttle
	_arc_cooldown -= delta * cadence * throttle
	if _mass_cooldown <= 0.0:
		_fire_mass_driver(player, enemies)
		_mass_cooldown = 0.72
	if _arc_cooldown <= 0.0:
		_fire_arc(player, enemies)
		_arc_cooldown = 1.18


func on_projectile_hit(projectile: Projectile, target: Node, hit_position: Vector2, enemies: Array[Node]) -> void:
	if not is_instance_valid(projectile) or not is_instance_valid(target):
		return
	if projectile.source_id != &"MASS_DRIVER" or projectile.fork_generation > 0:
		return
	var fork_rank := _rank("FORK_ON_KILL")
	if fork_rank <= 0 or not _will_hit_kill(target, projectile.damage):
		return

	var candidates := _nearest_enemies(hit_position, enemies, [target], 420.0)
	var count := mini(fork_rank, candidates.size())
	for index in range(count):
		var child_target: Node2D = candidates[index]
		var child_stats := projectile.make_child_stats({
			"damage": projectile.damage * 0.45,
			"lifetime": 0.72,
			"pierce": 0,
			"fork_generation": 1,
			"source_id": "MASS_DRIVER_FORK",
			"color": AMBER,
		})
		projectile_requested.emit(hit_position, (child_target.global_position - hit_position).normalized(), child_stats, &"player")
	combat_log.emit("FORK_ON_KILL // %d child process%s" % [count, "" if count == 1 else "es"], AMBER)


func on_projectile_expired(projectile: Projectile, reason: StringName, player_position: Vector2) -> void:
	if not is_instance_valid(projectile):
		return
	var return_rank := _rank("RETURN_VECTOR")
	if return_rank <= 0 or projectile.source_id != &"MASS_DRIVER" or projectile.fork_generation > 0:
		return
	if reason != &"lifetime":
		return
	var direction := player_position - projectile.global_position
	if direction.length_squared() < 64.0:
		return
	var return_speed := maxf(620.0, projectile.speed)
	projectile_requested.emit(projectile.global_position, direction.normalized(), {
		"speed": return_speed,
		"damage": projectile.damage * (0.55 + 0.15 * return_rank),
		"lifetime": direction.length() / return_speed + 0.42,
		"pierce": 1 + return_rank,
		"fork_generation": 1,
		"source_id": "MASS_DRIVER_RETURN",
		"hit_radius": projectile.hit_radius + 1.0,
		"color": AMBER,
	}, &"player")


func on_vent(position: Vector2, heat_ratio: float) -> void:
	sfx_requested.emit(&"vent")
	var amplifier_rank := _rank("VENT_AMPLIFIER")
	var overclock_rank := _rank("OVERCLOCK_KERNEL")
	var radius := 135.0 * (1.0 + 0.16 * amplifier_rank)
	var force := 240.0 * (1.0 + 0.22 * amplifier_rank) * lerpf(0.55, 1.15, heat_ratio)
	var damage := 4.0 + heat_ratio * 10.0
	if overclock_rank > 0 and heat_ratio >= 0.75:
		damage += 18.0 * overclock_rank * heat_ratio
	vent_pulse_requested.emit(position, radius, damage, force)


func _fire_mass_driver(player: PlayerShip, enemies: Array[Node]) -> void:
	var target := _select_mass_target(player, enemies)
	if target == null:
		return
	var direction := (target.global_position - player.global_position).normalized()
	var driver_rank := _rank("DRIVER_RAIL")
	var stats := {
		"speed": 760.0,
		"damage": 24.0,
		"lifetime": 1.05,
		"pierce": 1 + driver_rank,
		"fork_generation": 0,
		"source_id": "MASS_DRIVER",
		"hit_radius": 5.0,
		"color": CYAN,
	}
	projectile_requested.emit(player.global_position + direction * 19.0, direction, stats, &"player")
	sfx_requested.emit(&"mass")
	heat_generated.emit(3.8 * (1.0 + 0.14 * _rank("OVERCLOCK_KERNEL")))


func _fire_arc(player: PlayerShip, enemies: Array[Node]) -> void:
	var first := _select_arc_target(player, enemies)
	if first == null:
		return
	var extra_jumps := _rank("CONDUCTIVE_MARK")
	var branch_count := 1 + _rank("ARC_FANOUT")
	var total_hits := 0
	var full_chains := 0
	var excluded: Array[Node] = []
	for branch in range(branch_count):
		var start_target: Node = first
		if branch > 0:
			var branch_options := _nearest_enemies(first.global_position, enemies, excluded + [first], 210.0)
			if branch_options.is_empty():
				continue
			start_target = branch_options[0]
		var points := PackedVector2Array([player.global_position])
		var current: Node = start_target
		var chain_visited: Array[Node] = []
		var max_hits := 3 + extra_jumps
		for jump in range(max_hits):
			if not is_instance_valid(current) or not _is_enemy_alive(current):
				break
			chain_visited.append(current)
			excluded.append(current)
			points.append(current.global_position)
			var damage := 13.0 * pow(0.9, jump)
			current.call("take_damage", damage, &"ARC_EXE", current.global_position)
			total_hits += 1
			var next_options := _nearest_enemies(current.global_position, enemies, chain_visited, 170.0)
			if next_options.is_empty():
				current = null
				break
			current = next_options[0]
		if points.size() > 1:
			arc_fired.emit(points, ARC_COLOR if branch == 0 else Color(AMBER, 0.88))
		if chain_visited.size() >= max_hits:
			full_chains += 1
		if not chain_visited.is_empty():
			_marked_enemy = chain_visited[-1]

	if total_hits > 0:
		sfx_requested.emit(&"arc")
		var heat_scale := 1.0 + 0.12 * _rank("ARC_FANOUT") + 0.14 * _rank("OVERCLOCK_KERNEL")
		heat_generated.emit(7.5 * heat_scale)
	if full_chains > 0 and _rank("GROUND_LOOP") > 0:
		player.refund_vent_cooldown(0.18 * _rank("GROUND_LOOP") * full_chains)


func _select_mass_target(player: PlayerShip, enemies: Array[Node]) -> Node2D:
	var candidates := _nearest_enemies(player.global_position, enemies, [], 740.0)
	var best: Node2D
	var best_score: float = -INF
	for candidate in candidates.slice(0, mini(28, candidates.size())):
		var candidate_2d := candidate as Node2D
		var direction: Vector2 = (candidate_2d.global_position - player.global_position).normalized()
		var distance: float = candidate_2d.global_position.distance_to(player.global_position)
		if player.aim_active and direction.dot(player.aim_direction) < 0.30:
			continue
		var lined_up := 0
		for other in candidates:
			if other == candidate:
				continue
			var other_2d := other as Node2D
			var relative: Vector2 = other_2d.global_position - player.global_position
			var forward: float = relative.dot(direction)
			if forward > 0.0 and forward < 720.0:
				var lateral := absf(relative.cross(direction))
				if lateral < 34.0:
					lined_up += 1
		var aim_bonus: float = direction.dot(player.aim_direction) * 80.0 if player.aim_active else 0.0
		var score: float = lined_up * 115.0 - distance * 0.08 + aim_bonus
		if score > best_score:
			best_score = score
			best = candidate_2d
	return best


func _select_arc_target(player: PlayerShip, enemies: Array[Node]) -> Node2D:
	if is_instance_valid(_marked_enemy) and _is_enemy_alive(_marked_enemy):
		var marked := _marked_enemy as Node2D
		if marked.global_position.distance_to(player.global_position) <= 430.0:
			return marked
	var candidates := _nearest_enemies(player.global_position, enemies, [], 370.0)
	if not player.aim_active:
		return candidates[0] if not candidates.is_empty() else null
	var best: Node2D
	var best_score: float = -INF
	for candidate in candidates:
		var candidate_2d := candidate as Node2D
		var offset: Vector2 = candidate_2d.global_position - player.global_position
		var dot: float = offset.normalized().dot(player.aim_direction)
		if dot < 0.15:
			continue
		var score: float = dot * 200.0 - offset.length() * 0.15
		if score > best_score:
			best_score = score
			best = candidate_2d
	return best


func _nearest_enemies(origin: Vector2, enemies: Array[Node], excluded: Array, max_range: float) -> Array[Node]:
	var pairs: Array[Dictionary] = []
	var max_distance_squared := max_range * max_range
	for enemy in enemies:
		if not is_instance_valid(enemy) or excluded.has(enemy) or not _is_enemy_alive(enemy):
			continue
		if not enemy is Node2D:
			continue
		var distance_squared := (enemy as Node2D).global_position.distance_squared_to(origin)
		if distance_squared <= max_distance_squared:
			pairs.append({"node": enemy, "distance": distance_squared, "id": enemy.get_instance_id()})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["distance"]), float(b["distance"])):
			return int(a["id"]) < int(b["id"])
		return float(a["distance"]) < float(b["distance"])
	)
	var result: Array[Node] = []
	for pair in pairs:
		result.append(pair["node"])
	return result


func _will_hit_kill(target: Node, damage: float) -> bool:
	if "health" in target:
		return float(target.get("health")) <= damage
	return false


func _is_enemy_alive(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return false
	if enemy.has_method("is_alive"):
		return bool(enemy.call("is_alive"))
	return true


func _rank(upgrade_id: String) -> int:
	var value: Variant = upgrades.get(upgrade_id, 0)
	if value is Dictionary:
		value = value.get("rank", 0)
	return maxi(0, int(value)) if value is int or value is float else 0
