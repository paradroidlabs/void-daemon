class_name GravitonSalvo
extends Node2D

signal attack_fired(source_id: StringName)
signal sfx_requested(cue: StringName)
signal impact(position: Vector2, radius: float)
const FieldScript = preload("res://src/actors/graviton_field.gd")
const MissileScript = preload("res://src/actors/swarm_missile.gd")
var player: PlayerShip
var enabled := true
var gravity_enabled := true
var is_charging := false
var charge_time := 0.0
var charge_ratio := 0.0
var loaded_count := 0
var reload_left := 0.0
var field: GravitonField
var focus := Vector2.ZERO
var run_stats := {"charges": 0, "cancels": 0, "salvos": 0, "full_salvos": 0, "missiles": 0, "hits": 0, "retargets": 0, "charge_seconds": 0.0, "grouped": 0, "heat_spent": 0.0}
var _pending := 0
var _launch_left := 0.0
var _launch_index := 0
var _rings: Array[Dictionary] = []
var _focus_aim := Vector2.RIGHT
var _focus_goal := Vector2.ZERO
var _aim_resolve_left := 0.0


func setup(ship: PlayerShip) -> void:
	player = ship
	z_index = 21


func begin_charge() -> bool:
	if not enabled or is_charging or reload_left > 0 or _pending > 0 or player.is_dead or player.heat > 88:
		return false
	is_charging = true
	charge_time = 0
	charge_ratio = 0
	loaded_count = 1
	run_stats["charges"] += 1
	focus = _choose_focus()
	_focus_aim = player.aim_direction
	_focus_goal = focus
	_aim_resolve_left = 0
	if is_instance_valid(field):
		_retire_field()
	if gravity_enabled:
		field = FieldScript.new()
		field.configure(focus)
		get_parent().add_child(field)
		player.add_heat(8.0)
		run_stats["heat_spent"] += 8.0
	sfx_requested.emit(&"gravity")
	_sync_ship()
	return true


func release_charge() -> bool:
	if not is_charging:
		return false
	var affordable := maxi(0, floori((player.max_heat - player.heat) / 4.0))
	var count := mini(loaded_count, affordable)
	if count == 0:
		cancel_charge()
		return false
	is_charging = false
	_pending = count
	_launch_index = 0
	_launch_left = 0
	reload_left = 1.15 + count * 0.07
	player.add_heat(count * 4.0)
	run_stats["heat_spent"] += count * 4.0
	run_stats["salvos"] += 1
	run_stats["full_salvos"] += 1 if count == 6 else 0
	if is_instance_valid(field):
		field.release_field()
	_sync_ship()
	return true


func cancel_charge() -> void:
	if not is_charging:
		return
	run_stats["cancels"] += 1
	is_charging = false
	loaded_count = 0
	charge_ratio = 0
	reload_left = maxf(reload_left, 0.4)
	_retire_field()
	_sync_ship()
	queue_redraw()


func stop() -> void:
	cancel_charge()
	_pending = 0
	_retire_field()
	enabled = false


func abort_pending() -> void:
	_pending = 0
	_sync_ship()


func reset() -> void:
	stop()
	for key in run_stats:
		run_stats[key] = 0
	reload_left = 0
	_rings.clear()
	enabled = true


func tick(delta: float, enemies: Array[Node]) -> void:
	if not enabled or player.is_dead:
		return
	reload_left = maxf(0, reload_left - delta)
	if is_charging:
		charge_time += delta
		run_stats["charge_seconds"] += delta
		charge_ratio = clampf(charge_time / 0.8, 0, 1)
		var new_count := mini(6, 1 + floori(charge_time / 0.16))
		if new_count > loaded_count:
			sfx_requested.emit(&"rack_load")
		loaded_count = new_count
		# Touch/controller aim can change after the initial press. Move the
		# external focal point at a bounded speed rather than snapping captures.
		_aim_resolve_left -= delta
		if _aim_resolve_left <= 0 and player.aim_active and absf(_focus_aim.angle_to(player.aim_direction)) > 0.15:
			_focus_goal = _choose_focus()
			_focus_aim = player.aim_direction
			_aim_resolve_left = 0.12
		focus = focus.move_toward(_focus_goal, 240.0 * delta)
		if is_instance_valid(field):
			field.global_position = focus
	if is_instance_valid(field):
		field.tick(delta, enemies)
		# Unique contacts accumulate once per field rather than once per frame.
		run_stats["grouped"] = int(run_stats["grouped"]) + field.affected_ids.size() - int(field.get_meta("reported", 0))
		field.set_meta("reported", field.affected_ids.size())
	if _pending > 0:
		_launch_left -= delta
		if _launch_left <= 0:
			_launch_one()
			_pending -= 1
			_launch_left += 0.075
	for index in range(_rings.size() - 1, -1, -1):
		_rings[index]["age"] += delta
		if _rings[index]["age"] >= 0.32:
			_rings.remove_at(index)
	_sync_ship()
	queue_redraw()


func _launch_one() -> void:
	var direction := (focus - player.global_position).normalized()
	var side := direction.orthogonal() * (1.0 if _launch_index % 2 == 0 else -1.0)
	var origin := player.global_position + side * 18 + direction * 7
	var target: Node2D
	var candidates := _target_candidates(focus, 310)
	if not candidates.is_empty():
		target = candidates[_launch_index % candidates.size()]
	var destination := target.global_position if is_instance_valid(target) else focus
	var missile: SwarmMissile = MissileScript.new()
	missile.configure(origin, (direction + side.normalized() * 0.75).normalized(), destination, target)
	missile.detonated.connect(_on_detonation)
	missile.retired.connect(_on_retired)
	get_parent().add_child(missile)
	_launch_index += 1
	run_stats["missiles"] += 1
	player.unleash_firing_flash = 0.14
	attack_fired.emit(&"GRAVITON_SALVO")
	sfx_requested.emit(&"salvo")


func _on_detonation(position: Vector2) -> void:
	_rings.append({"position": position, "age": 0.0})
	impact.emit(position, 76.0)
	sfx_requested.emit(&"impact")


func _on_retired(hit: bool, count: int) -> void:
	run_stats["hits"] += 1 if hit else 0
	run_stats["retargets"] += count


func _retire_field() -> void:
	if is_instance_valid(field):
		field.expired = true
		field.queue_free()
	field = null


func _choose_focus() -> Vector2:
	var aim := player.aim_direction if player.aim_active else player.last_move_direction
	var candidates := _target_candidates(player.global_position, 620)
	var best: Node2D
	var best_score := -INF
	# Sample across the range-sorted list: avoid an all-pairs density search
	# every time aim changes during a late-run hold.
	var stride := maxi(1, ceili(float(candidates.size()) / 32.0))
	for index in range(0, candidates.size(), stride):
		var enemy: Node2D = candidates[index]
		var offset := enemy.global_position - player.global_position
		var alignment := offset.normalized().dot(aim)
		if player.aim_active and alignment < 0.35:
			continue
		var nearby := 0
		for other in candidates:
			if other.global_position.distance_squared_to(enemy.global_position) < 22500:
				nearby += 1
		var score := nearby * 38 + (alignment * 150 if player.aim_active else 0.0) - offset.length() * 0.12
		if score > best_score:
			best_score = score
			best = enemy
	var offset := (best.global_position - player.global_position) if best != null else aim * 360
	return player.global_position + offset.normalized() * clampf(offset.length(), 180, 560)


func _target_candidates(center: Vector2, radius: float) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy is Node2D and enemy.has_method("is_alive") and enemy.is_alive() and enemy.global_position.distance_to(center) < radius:
			result.append(enemy)
	result.sort_custom(func(a: Node2D, b: Node2D): return a.global_position.distance_squared_to(center) < b.global_position.distance_squared_to(center))
	return result


func _sync_ship() -> void:
	player.unleash_charge_ratio = charge_ratio if is_charging else 0.0
	player.unleash_loaded = loaded_count if is_charging else _pending
	player.unleash_focus = focus


func _draw() -> void:
	if is_charging:
		draw_line(player.global_position, focus, Color(0.72, 0.6, 1, 0.25), 1, true)
		for index in loaded_count:
			var angle := float(index) / 6 * TAU - PI / 2
			var p := focus + Vector2.RIGHT.rotated(angle) * 38
			draw_line(p, p + Vector2.RIGHT.rotated(angle) * 8, Color("ffcf89"), 3, true)
	for ring in _rings:
		var ratio := float(ring["age"]) / 0.32
		draw_arc(ring["position"], lerpf(8, 76, ratio), 0, TAU, 36, Color(1, 0.74, 0.38, 1.0 - ratio), 2, true)
