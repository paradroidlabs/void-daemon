class_name AlternateArsenal
extends "res://src/systems/graviton_salvo.gd"

var chassis_id := "bastion"
var _damage_clock := 0.0
var _committed := false
var _beam_end := Vector2.ZERO
var _pulse_flash := 0.0


func setup(ship: PlayerShip) -> void:
	super.setup(ship)
	chassis_id = ship.chassis_id
	gravity_enabled = chassis_id == "scrapper"
	run_stats["damage_ticks"] = 0
	run_stats["contact_seconds"] = 0.0
	run_stats["overheat_stops"] = 0


func begin_charge() -> bool:
	if chassis_id == "scrapper":
		return super.begin_charge()
	if not enabled or is_charging or reload_left > 0 or player.is_dead or player.heat > 88:
		return false
	is_charging = true
	charge_time = 0
	charge_ratio = 0
	loaded_count = 0
	_damage_clock = 0
	_committed = false
	run_stats["charges"] += 1
	_spend_heat(4)
	sfx_requested.emit(&"beam_start" if chassis_id == "bastion" else &"corona_start")
	return true


func _spend_heat(amount: float) -> bool:
	if player.heat + amount > player.max_heat:
		run_stats["overheat_stops"] += 1
		cancel_charge()
		return false
	player.add_heat(amount)
	run_stats["heat_spent"] += amount
	return true


func tick(delta: float, enemies: Array[Node]) -> void:
	if not enabled or player.is_dead:
		return
	reload_left = maxf(0, reload_left - delta)
	_pulse_flash = maxf(0, _pulse_flash - delta)
	for index in range(_rings.size() - 1, -1, -1):
		_rings[index]["age"] += delta
		if _rings[index]["age"] >= 0.32:
			_rings.remove_at(index)
	if is_charging:
		charge_time += delta
		run_stats["charge_seconds"] += delta
		charge_ratio = clampf(charge_time / (1.2 if chassis_id == "scrapper" else 0.18), 0, 1)
		var aim := player.aim_direction if player.aim_active else Vector2.RIGHT.rotated(player.rotation)
		focus = player.global_position + aim * (500 if chassis_id == "bastion" else 210)
		if chassis_id == "scrapper":
			focus = player.global_position + aim * 285
			if not _spend_heat(13 * delta):
				return
			if is_instance_valid(field):
				field.global_position = field.global_position.move_toward(focus, 220 * delta)
				focus = field.global_position
				field.tick(delta, enemies)
				run_stats["grouped"] += field.affected_ids.size() - int(field.get_meta("reported", 0))
				field.set_meta("reported", field.affected_ids.size())
		else:
			var active_delta := minf(delta, maxf(0, charge_time - 0.18))
			_damage_clock += active_delta
			var interval := 0.1 if chassis_id == "bastion" else 0.16
			while is_charging and _damage_clock >= interval:
				_damage_clock -= interval
				var cost := 2.0 if chassis_id == "bastion" else 5.5
				if not _spend_heat(cost):
					break
				_damage_tick(enemies, aim, interval)
	_sync_ship()
	queue_redraw()


func _damage_tick(enemies: Array[Node], aim: Vector2, interval: float) -> void:
	var source := &"SIEGE_LANCE" if chassis_id == "bastion" else &"CORONA_DRIVE"
	if not _committed:
		_committed = true
		run_stats["salvos"] += 1
	attack_fired.emit(source)
	run_stats["damage_ticks"] += 1
	var targets: Array[Node2D] = []
	_beam_end = player.global_position + aim * 610
	for candidate in enemies:
		if not is_instance_valid(candidate) or candidate.is_queued_for_deletion() or not candidate.has_method("is_alive") or not candidate.is_alive():
			continue
		var offset: Vector2 = candidate.global_position - player.global_position
		if chassis_id == "bastion":
			var closest := Geometry2D.get_closest_point_to_segment(candidate.global_position, player.global_position, _beam_end)
			if closest.distance_to(candidate.global_position) <= float(candidate.get("collision_radius")) + 8:
				targets.append(candidate)
		elif offset.length() <= 220 + float(candidate.get("collision_radius")) and offset.normalized().dot(aim) >= 0.82:
			targets.append(candidate)
	targets.sort_custom(func(a: Node2D, b: Node2D): return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	var count := mini(3 if chassis_id == "bastion" else 6, targets.size())
	if count > 0:
		run_stats["contact_seconds"] += interval
	for index in count:
		var damage := 16.0 if chassis_id == "bastion" else 19.0 * (1.0 + player.get_heat_ratio() * 0.65)
		run_stats["hits"] += 1
		targets[index].take_damage(damage, String(source), targets[index].global_position)
		if not enabled:
			return
	_pulse_flash = 0.12
	player.unleash_firing_flash = 0.12
	if chassis_id == "redline":
		sfx_requested.emit(&"corona_pulse")


func release_charge() -> bool:
	if not is_charging:
		return false
	if chassis_id == "scrapper":
		if not _spend_heat(12):
			return false
		var center := field.global_position if is_instance_valid(field) else focus
		var targets := _target_candidates(center, 220)
		attack_fired.emit(&"GRAVITY_COLLAPSE")
		run_stats["salvos"] += 1
		run_stats["full_salvos"] += 1 if charge_ratio >= 1 else 0
		for index in range(mini(12, targets.size())):
			run_stats["hits"] += 1
			targets[index].take_damage(55 + 65 * charge_ratio, "GRAVITY_COLLAPSE", center)
			if not enabled:
				return true
		_rings.append({"position": center, "age": 0.0})
		impact.emit(center, 220)
		sfx_requested.emit(&"collapse")
		_retire_field()
	is_charging = false
	charge_ratio = 0
	loaded_count = 0
	reload_left = 1.6 if chassis_id == "scrapper" else 0.45
	_sync_ship()
	queue_redraw()
	return true


func reset() -> void:
	super.reset()
	_damage_clock = 0
	_committed = false
	_pulse_flash = 0
	gravity_enabled = chassis_id == "scrapper"


func _draw() -> void:
	if not is_instance_valid(player):
		return
	if chassis_id == "scrapper":
		if is_charging:
			draw_line(player.global_position, focus, Color("7bdfaa"), 1, true)
		for ring in _rings:
			var ratio: float = ring["age"] / 0.32
			draw_arc(ring["position"], 220 * (1 - ratio), 0, TAU, 48, Color(0.48, 0.88, 0.67, 1 - ratio), 3, true)
	elif is_charging and charge_time >= 0.18:
		var aim := player.aim_direction if player.aim_active else Vector2.RIGHT.rotated(player.rotation)
		var origin := player.global_position + aim * 24
		if chassis_id == "bastion":
			var endpoint := player.global_position + aim * 610
			draw_line(origin, endpoint, Color(1, 0.8, 0.5, 0.13), 22, true)
			draw_line(origin, endpoint, Color("ffbd4a"), 7, true)
			draw_line(origin, endpoint, Color("fff5d8"), 2, true)
			for i in range(0 if Experience.reduced_effects else 6):
				var mark := origin.lerp(endpoint, fposmod(charge_time * 1.5 + i / 6.0, 1))
				draw_line(mark - aim.orthogonal() * 8, mark + aim.orthogonal() * 8, Color("fff5d8"), 1, true)
		else:
			for i in range(7):
				var p := origin + aim * (i * 25 + (0.0 if Experience.reduced_effects else fposmod(charge_time * 180, 25)))
				var radius := 4 + i * 1.4 + player.get_heat_ratio() * 4
				draw_arc(p, radius, aim.angle() - PI * 0.65, aim.angle() + PI * 0.65, 14, Color("ff7188") if i % 2 == 0 else Color("ffbf72"), 2 if Experience.reduced_effects else 2 + _pulse_flash * 12, true)
